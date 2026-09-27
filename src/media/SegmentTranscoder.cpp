#include "SegmentTranscoder.h"

#include <QCoreApplication>
#include <QFile>
#include <QThread>

#include <algorithm>
#include <exception>
#include <memory>

#include <qt_windows.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/audio_fifo.h>
#include <libavutil/channel_layout.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}

namespace {

using toyfoxx::SegmentRequest;

QString tr(const char *text)
{
    return QCoreApplication::translate("SegmentTranscoder", text);
}

struct Failure
{
    QString message;
};

struct Canceled
{
};

[[noreturn]] void fail(const QString &message)
{
    throw Failure{message};
}

// Returns error unchanged when it is not negative.
int check(int error, const QString &what)
{
    if (error >= 0)
        return error;
    char text[AV_ERROR_MAX_STRING_SIZE] = {};
    av_strerror(error, text, sizeof text);
    fail(what + QStringLiteral(" (") + QString::fromUtf8(text) + u')');
}

struct InputDeleter
{
    void operator()(AVFormatContext *context) const { avformat_close_input(&context); }
};
struct OutputDeleter
{
    void operator()(AVFormatContext *context) const
    {
        avio_closep(&context->pb);
        avformat_free_context(context);
    }
};
struct CodecDeleter
{
    void operator()(AVCodecContext *context) const { avcodec_free_context(&context); }
};
struct FrameDeleter
{
    void operator()(AVFrame *frame) const { av_frame_free(&frame); }
};
struct PacketDeleter
{
    void operator()(AVPacket *packet) const { av_packet_free(&packet); }
};
struct SwsDeleter
{
    void operator()(SwsContext *context) const { sws_freeContext(context); }
};
struct SwrDeleter
{
    void operator()(SwrContext *context) const { swr_free(&context); }
};
struct FifoDeleter
{
    void operator()(AVAudioFifo *fifo) const { av_audio_fifo_free(fifo); }
};

using CodecPtr = std::unique_ptr<AVCodecContext, CodecDeleter>;
using FramePtr = std::unique_ptr<AVFrame, FrameDeleter>;

constexpr AVRational microseconds{1, AV_TIME_BASE};
// The largest frame, in 16x16 macroblocks, that H.264 allows (level 5.1 and up; 4096x2304).
constexpr qint64 maxH264Macroblocks = 36864;

FramePtr allocFrame()
{
    FramePtr frame(av_frame_alloc());
    if (!frame)
        fail(tr("Out of memory."));
    return frame;
}

class SegmentJob
{
public:
    SegmentJob(const SegmentRequest &request, const std::function<bool(double)> &progress)
        : m_request(request), m_progress(progress)
    {
    }

    void run();
    // Closes everything; the output file is complete only if run() returned normally.
    void close();
    bool createdOutput() const { return m_createdOutput; }

private:
    void openInput();
    void seekToStart();
    int64_t firstVideoTimestamp();
    void setUpVideo();
    void setUpAudio();
    void setUpAudioEncoder(const AVCodecParameters *parameters);
    void decodeVideo(const AVPacket *packet);
    void encodeVideoFrame(const AVFrame *frame, int64_t timestamp);
    void encodePendingVideoFrame();
    void copyAudio(AVPacket *packet);
    void decodeAudio(const AVPacket *packet);
    void queueAudio(const AVFrame *frame, int64_t timestamp);
    void encodeQueuedAudio(bool flush);
    void encode(AVCodecContext *encoder, const AVFrame *frame, AVStream *stream);
    void reportProgress();

    SegmentRequest m_request;
    std::function<bool(double)> m_progress;

    std::unique_ptr<AVFormatContext, InputDeleter> m_input;
    std::unique_ptr<AVFormatContext, OutputDeleter> m_output;
    std::unique_ptr<AVPacket, PacketDeleter> m_packet; // read from the input
    std::unique_ptr<AVPacket, PacketDeleter> m_encodedPacket;
    bool m_createdOutput = false;
    int64_t m_originUs = 0;
    int64_t m_startUs = 0;
    int64_t m_endUs = 0;

    AVStream *m_videoIn = nullptr;
    AVStream *m_videoOut = nullptr;
    CodecPtr m_videoDecoder;
    CodecPtr m_videoEncoder;
    std::unique_ptr<SwsContext, SwsDeleter> m_scaler;
    FramePtr m_decoded;
    FramePtr m_scaled;
    // The last frame at or before the start, which is the one on screen at the start; encoded
    // at time zero once a later frame shows up.
    FramePtr m_pendingFirst;
    bool m_hasPendingFirst = false;
    int64_t m_videoStart = 0; // in m_videoIn's time base
    int64_t m_videoEnd = 0;
    int64_t m_videoEncodedFrames = 0;
    double m_fraction = 0;
    bool m_videoDone = false;

    AVStream *m_audioIn = nullptr;
    AVStream *m_audioOut = nullptr;
    int64_t m_audioStart = 0; // in m_audioIn's time base
    int64_t m_audioEnd = 0;
    bool m_audioDone = true;
    // Only when the audio is re-encoded rather than copied.
    CodecPtr m_audioDecoder;
    CodecPtr m_audioEncoder;
    std::unique_ptr<SwrContext, SwrDeleter> m_resampler;
    std::unique_ptr<AVAudioFifo, FifoDeleter> m_audioFifo;
    FramePtr m_resampled;
    FramePtr m_audioFrame;
    int64_t m_audioTargetSamples = 0;
    int64_t m_audioQueuedSamples = 0;
    int64_t m_audioEncodedSamples = 0;
    int64_t m_audioFirstSample = -1; // where the first queued sample lies in the output
};

void SegmentJob::run()
{
    m_packet.reset(av_packet_alloc());
    m_encodedPacket.reset(av_packet_alloc());
    m_decoded = allocFrame();
    if (!m_packet || !m_encodedPacket)
        fail(tr("Out of memory."));

    openInput();

    const QByteArray outputPath = m_request.outputPath.toUtf8();
    AVFormatContext *output = nullptr;
    check(avformat_alloc_output_context2(&output, nullptr, "mp4", outputPath.constData()),
          tr("Could not set up the MP4 writer"));
    m_output.reset(output);

    setUpVideo();
    setUpAudio();

    check(avio_open(&output->pb, outputPath.constData(), AVIO_FLAG_WRITE),
          tr("Could not create %1").arg(m_request.outputPath));
    m_createdOutput = true;
    AVDictionary *options = nullptr;
    // The index goes to the front once the file is complete, so it plays while still downloading
    // or copying.
    av_dict_set(&options, "movflags", "+faststart", 0);
    const int headerResult = avformat_write_header(output, &options);
    av_dict_free(&options);
    check(headerResult, tr("Could not write the file header"));

    seekToStart();

    AVPacket *packet = m_packet.get();
    while (!m_videoDone || !m_audioDone) {
        reportProgress();
        const int result = av_read_frame(m_input.get(), packet);
        if (result == AVERROR_EOF)
            break;
        check(result, tr("Could not read the media"));
        if (packet->stream_index == m_videoIn->index && !m_videoDone)
            decodeVideo(packet);
        else if (m_audioIn && packet->stream_index == m_audioIn->index && !m_audioDone)
            m_audioDecoder ? decodeAudio(packet) : copyAudio(packet);
        av_packet_unref(packet);
    }

    if (!m_videoDone)
        decodeVideo(nullptr);
    encodePendingVideoFrame();
    encode(m_videoEncoder.get(), nullptr, m_videoOut);
    if (m_audioEncoder) {
        if (!m_audioDone)
            decodeAudio(nullptr);
        encodeQueuedAudio(true);
    }
    if (m_videoEncodedFrames == 0)
        fail(tr("The segment holds no video frames."));

    check(av_write_trailer(output), tr("Could not finish the file"));
    m_output.reset();
}

void SegmentJob::close()
{
    m_output.reset();
    m_input.reset();
}

void SegmentJob::openInput()
{
    AVFormatContext *input = nullptr;
    check(avformat_open_input(&input, m_request.inputPath.toUtf8().constData(), nullptr, nullptr),
          tr("Could not open %1").arg(m_request.inputPath));
    m_input.reset(input);
    check(avformat_find_stream_info(input, nullptr), tr("Could not read the media's streams"));

    const int videoIndex = av_find_best_stream(input, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (videoIndex < 0)
        fail(tr("The media has no video stream."));
    m_videoIn = input->streams[videoIndex];
    const int audioIndex = av_find_best_stream(input, AVMEDIA_TYPE_AUDIO, -1, videoIndex, nullptr, 0);
    m_audioIn = audioIndex >= 0 ? input->streams[audioIndex] : nullptr;
    for (unsigned i = 0; i < input->nb_streams; ++i) {
        if (input->streams[i] != m_videoIn && input->streams[i] != m_audioIn)
            input->streams[i]->discard = AVDISCARD_ALL;
    }

    // MediaPlayer counts positions from the start of the media, not from timestamp zero; the two
    // differ in MPEG-TS, for one.
    m_originUs = input->start_time != AV_NOPTS_VALUE ? input->start_time : 0;
    m_startUs = m_originUs + m_request.startMs * 1000;
    m_endUs = m_originUs + m_request.endMs * 1000;
}

// Decoding has to begin on a key frame at or before the start; decoding from there up to the
// start is what makes the cut exact. A backward seek lands there in most containers, but some
// (MPEG-TS) seek by time alone, and the decoder then drops frames up to the next key frame,
// which may lie past the start. So probe: seek, decode one frame, and back off until it is not
// late. Nothing is written yet, and failing to seek only costs time.
void SegmentJob::seekToStart()
{
    int64_t target = m_startUs;
    int64_t backoff = AV_TIME_BASE;
    for (;;) {
        av_seek_frame(m_input.get(), -1, target, AVSEEK_FLAG_BACKWARD);
        avcodec_flush_buffers(m_videoDecoder.get());
        const int64_t first = firstVideoTimestamp();
        if (first == AV_NOPTS_VALUE || first <= m_videoStart || target <= m_originUs)
            break;
        target = std::max(m_originUs, target - backoff);
        backoff *= 2;
    }
    av_seek_frame(m_input.get(), -1, target, AVSEEK_FLAG_BACKWARD);
    avcodec_flush_buffers(m_videoDecoder.get());
}

// The timestamp of the next video frame decoded, or AV_NOPTS_VALUE at the end of the input.
int64_t SegmentJob::firstVideoTimestamp()
{
    AVPacket *packet = m_packet.get();
    AVFrame *frame = m_decoded.get();
    for (;;) {
        reportProgress();
        const int result = av_read_frame(m_input.get(), packet);
        if (result < 0)
            return AV_NOPTS_VALUE;
        if (packet->stream_index == m_videoIn->index) {
            avcodec_send_packet(m_videoDecoder.get(), packet);
            while (avcodec_receive_frame(m_videoDecoder.get(), frame) >= 0) {
                const int64_t timestamp = frame->best_effort_timestamp;
                av_frame_unref(frame);
                if (timestamp != AV_NOPTS_VALUE) {
                    av_packet_unref(packet);
                    return timestamp;
                }
            }
        }
        av_packet_unref(packet);
    }
}

void SegmentJob::setUpVideo()
{
    const AVCodecParameters *parameters = m_videoIn->codecpar;
    const AVCodec *decoder = avcodec_find_decoder(parameters->codec_id);
    if (!decoder)
        fail(tr("There is no decoder for the video codec."));
    m_videoDecoder.reset(avcodec_alloc_context3(decoder));
    AVCodecContext *decoderContext = m_videoDecoder.get();
    check(avcodec_parameters_to_context(decoderContext, parameters), tr("Could not set up the video decoder"));
    decoderContext->pkt_timebase = m_videoIn->time_base;
    // Half the cores, so playback in the same process keeps the rest.
    decoderContext->thread_count = std::max(1, QThread::idealThreadCount() / 2);
    check(avcodec_open2(decoderContext, decoder, nullptr), tr("Could not open the video decoder"));

    // Media Foundation's encoders take 8-bit 4:2:0 only (Microsoft's HEVC encoder does Main
    // only), so 10-bit sources come out as 8-bit.
    const int width = decoderContext->width & ~1;
    const int height = decoderContext->height & ~1;
    const qint64 macroblocks = qint64((width + 15) / 16) * ((height + 15) / 16);
    const bool hevc = macroblocks > maxH264Macroblocks;
    const AVCodec *encoder = avcodec_find_encoder_by_name(hevc ? "hevc_mf" : "h264_mf");
    if (!encoder)
        fail(tr("The Media Foundation video encoder is not available."));

    AVRational frameRate = av_guess_frame_rate(m_input.get(), m_videoIn, nullptr);
    if (frameRate.num <= 0 || frameRate.den <= 0)
        frameRate = AVRational{30, 1};
    const double fps = av_q2d(frameRate);
    // A quarter over the source, since the source may use a more efficient codec, but never
    // below about 0.08 bits per pixel (5 Mbps at 1080p30, 40 Mbps at 2160p60).
    int64_t sourceBitRate = parameters->bit_rate > 0 ? parameters->bit_rate : m_input->bit_rate;
    const int64_t bitRate = std::clamp<int64_t>(std::max<int64_t>(sourceBitRate + sourceBitRate / 4,
                                                                  int64_t(width * double(height) * fps * 0.08)),
                                                2'000'000, 200'000'000);
    const AVPixelFormat sourceFormat = decoderContext->pix_fmt;
    const AVPixFmtDescriptor *descriptor = av_pix_fmt_desc_get(sourceFormat);
    const bool jpegRange = descriptor && QByteArrayView(descriptor->name).startsWith("yuvj");

    const auto open = [&](bool hardware) {
        m_videoEncoder.reset(avcodec_alloc_context3(encoder));
        AVCodecContext *context = m_videoEncoder.get();
        context->width = width;
        context->height = height;
        context->pix_fmt = AV_PIX_FMT_NV12;
        context->time_base = m_videoIn->time_base;
        context->framerate = frameRate;
        context->sample_aspect_ratio = av_guess_sample_aspect_ratio(m_input.get(), m_videoIn, nullptr);
        context->bit_rate = bitRate;
        context->gop_size = std::max(1, int(fps * 2 + 0.5));
        if (!hevc)
            context->profile = AV_PROFILE_H264_HIGH;
        context->color_primaries = decoderContext->color_primaries;
        context->color_trc = decoderContext->color_trc;
        context->colorspace = decoderContext->colorspace;
        // swscale expands the yuvj formats' full range to the limited range of NV12.
        context->color_range = jpegRange ? AVCOL_RANGE_MPEG : decoderContext->color_range;
        if (m_output->oformat->flags & AVFMT_GLOBALHEADER)
            context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        AVDictionary *options = nullptr;
        av_dict_set(&options, "hw_encoding", hardware ? "1" : "0", 0);
        av_dict_set(&options, "rate_control", "u_vbr", 0);
        const int result = avcodec_open2(context, encoder, &options);
        av_dict_free(&options);
        return result;
    };
    // The GPU vendor's encoder when there is one, else Microsoft's software encoder.
    if (open(true) < 0)
        check(open(false), tr("Could not open the video encoder"));

    m_videoOut = avformat_new_stream(m_output.get(), nullptr);
    if (!m_videoOut)
        fail(tr("Out of memory."));
    check(avcodec_parameters_from_context(m_videoOut->codecpar, m_videoEncoder.get()),
          tr("Could not set up the video stream"));
    m_videoOut->time_base = m_videoEncoder->time_base;
    m_videoOut->sample_aspect_ratio = m_videoEncoder->sample_aspect_ratio;
    m_videoOut->avg_frame_rate = frameRate;
    // Rotation is metadata in the source; keep it rather than rotating the pixels.
    if (const AVPacketSideData *matrix = av_packet_side_data_get(
            parameters->coded_side_data, parameters->nb_coded_side_data, AV_PKT_DATA_DISPLAYMATRIX)) {
        AVCodecParameters *out = m_videoOut->codecpar;
        if (AVPacketSideData *copy = av_packet_side_data_new(&out->coded_side_data, &out->nb_coded_side_data,
                                                             AV_PKT_DATA_DISPLAYMATRIX, matrix->size, 0))
            std::copy_n(matrix->data, matrix->size, copy->data);
    }

    m_pendingFirst = allocFrame();
    m_scaled = allocFrame();
    m_scaled->format = AV_PIX_FMT_NV12;
    m_scaled->width = width;
    m_scaled->height = height;
    check(av_frame_get_buffer(m_scaled.get(), 0), tr("Out of memory."));

    m_videoStart = av_rescale_q(m_startUs, microseconds, m_videoIn->time_base);
    m_videoEnd = av_rescale_q(m_endUs, microseconds, m_videoIn->time_base);
}

void SegmentJob::setUpAudio()
{
    if (!m_audioIn)
        return;
    const AVCodecParameters *parameters = m_audioIn->codecpar;
    m_audioStart = av_rescale_q(m_startUs, microseconds, m_audioIn->time_base);
    m_audioEnd = av_rescale_q(m_endUs, microseconds, m_audioIn->time_base);
    m_audioDone = false;

    m_audioOut = avformat_new_stream(m_output.get(), nullptr);
    if (!m_audioOut)
        fail(tr("Out of memory."));
    // Copied only when common players take it in MP4; MP4 can hold more (Vorbis, MP2, DTS),
    // but Windows' own players, for one, cannot play those from it.
    constexpr AVCodecID copyable[] = {AV_CODEC_ID_AAC,  AV_CODEC_ID_MP3,  AV_CODEC_ID_AC3, AV_CODEC_ID_EAC3,
                                      AV_CODEC_ID_OPUS, AV_CODEC_ID_FLAC, AV_CODEC_ID_ALAC};
    if (std::ranges::find(copyable, parameters->codec_id) != std::end(copyable)
        && avformat_query_codec(m_output->oformat, parameters->codec_id, FF_COMPLIANCE_NORMAL) == 1) {
        check(avcodec_parameters_copy(m_audioOut->codecpar, parameters), tr("Could not set up the audio stream"));
        m_audioOut->codecpar->codec_tag = 0;
        m_audioOut->time_base = m_audioIn->time_base;
        return;
    }
    setUpAudioEncoder(parameters);
}

void SegmentJob::setUpAudioEncoder(const AVCodecParameters *parameters)
{
    const AVCodec *decoder = avcodec_find_decoder(parameters->codec_id);
    if (!decoder)
        fail(tr("There is no decoder for the audio codec."));
    m_audioDecoder.reset(avcodec_alloc_context3(decoder));
    AVCodecContext *decoderContext = m_audioDecoder.get();
    check(avcodec_parameters_to_context(decoderContext, parameters), tr("Could not set up the audio decoder"));
    decoderContext->pkt_timebase = m_audioIn->time_base;
    check(avcodec_open2(decoderContext, decoder, nullptr), tr("Could not open the audio decoder"));
    if (decoderContext->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC) {
        const int channels = decoderContext->ch_layout.nb_channels;
        av_channel_layout_uninit(&decoderContext->ch_layout);
        av_channel_layout_default(&decoderContext->ch_layout, channels);
    }

    const AVCodec *encoder = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!encoder)
        fail(tr("The AAC encoder is not available."));
    m_audioEncoder.reset(avcodec_alloc_context3(encoder));
    AVCodecContext *context = m_audioEncoder.get();
    constexpr int aacRates[] = {96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000};
    const int sourceRate = decoderContext->sample_rate;
    context->sample_rate = std::ranges::find(aacRates, sourceRate) != std::end(aacRates) ? sourceRate : 48000;
    // Mono and stereo as they are; anything wider becomes 5.1 or, below six channels, stereo.
    const int sourceChannels = decoderContext->ch_layout.nb_channels;
    const int channels = sourceChannels <= 2 ? sourceChannels : sourceChannels >= 6 ? 6 : 2;
    av_channel_layout_default(&context->ch_layout, channels);
    context->sample_fmt = AV_SAMPLE_FMT_FLTP;
    context->bit_rate = 64000 * channels;
    context->time_base = AVRational{1, context->sample_rate};
    if (m_output->oformat->flags & AVFMT_GLOBALHEADER)
        context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    check(avcodec_open2(context, encoder, nullptr), tr("Could not open the audio encoder"));
    check(avcodec_parameters_from_context(m_audioOut->codecpar, context), tr("Could not set up the audio stream"));
    m_audioOut->time_base = context->time_base;

    SwrContext *resampler = nullptr;
    check(swr_alloc_set_opts2(&resampler, &context->ch_layout, context->sample_fmt, context->sample_rate,
                              &decoderContext->ch_layout, decoderContext->sample_fmt, decoderContext->sample_rate, 0,
                              nullptr),
          tr("Could not set up the audio resampler"));
    m_resampler.reset(resampler);
    check(swr_init(resampler), tr("Could not set up the audio resampler"));
    m_audioFifo.reset(av_audio_fifo_alloc(context->sample_fmt, channels, context->frame_size));
    if (!m_audioFifo)
        fail(tr("Out of memory."));
    m_resampled = allocFrame();
    m_audioFrame = allocFrame();
    m_audioFrame->format = context->sample_fmt;
    m_audioFrame->sample_rate = context->sample_rate;
    m_audioFrame->nb_samples = context->frame_size;
    check(av_channel_layout_copy(&m_audioFrame->ch_layout, &context->ch_layout), tr("Out of memory."));
    check(av_frame_get_buffer(m_audioFrame.get(), 0), tr("Out of memory."));
    m_audioTargetSamples = av_rescale(m_endUs - m_startUs, context->sample_rate, AV_TIME_BASE);
}

// packet == nullptr drains the decoder.
void SegmentJob::decodeVideo(const AVPacket *packet)
{
    AVCodecContext *decoder = m_videoDecoder.get();
    // Corrupt packets are skipped, as a player would; hard errors surface in receive_frame.
    avcodec_send_packet(decoder, packet);
    AVFrame *frame = m_decoded.get();
    for (;;) {
        const int result = avcodec_receive_frame(decoder, frame);
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF)
            return;
        check(result, tr("Could not decode the video"));
        const int64_t timestamp = frame->best_effort_timestamp;
        if (timestamp != AV_NOPTS_VALUE && timestamp >= m_videoEnd) {
            m_videoDone = true;
            av_frame_unref(frame);
            return;
        }
        if (timestamp != AV_NOPTS_VALUE && timestamp <= m_videoStart) {
            av_frame_unref(m_pendingFirst.get());
            av_frame_move_ref(m_pendingFirst.get(), frame);
            m_hasPendingFirst = true;
        } else if (timestamp != AV_NOPTS_VALUE) {
            encodePendingVideoFrame();
            encodeVideoFrame(frame, timestamp);
        }
        av_frame_unref(frame);
    }
}

void SegmentJob::encodePendingVideoFrame()
{
    if (!m_hasPendingFirst)
        return;
    m_hasPendingFirst = false;
    // Starts a little before the cut; shown from zero, cut short by the difference.
    encodeVideoFrame(m_pendingFirst.get(), m_videoStart);
    av_frame_unref(m_pendingFirst.get());
}

void SegmentJob::encodeVideoFrame(const AVFrame *frame, int64_t timestamp)
{
    AVFrame *scaled = m_scaled.get();
    SwsContext *scaler = sws_getCachedContext(m_scaler.release(), frame->width, frame->height,
                                              AVPixelFormat(frame->format), scaled->width, scaled->height,
                                              AV_PIX_FMT_NV12, SWS_BICUBIC, nullptr, nullptr, nullptr);
    m_scaler.reset(scaler);
    if (!scaler)
        fail(tr("Could not convert the video frames."));
    check(av_frame_make_writable(scaled), tr("Out of memory."));
    sws_scale(scaler, frame->data, frame->linesize, 0, frame->height, scaled->data, scaled->linesize);
    scaled->pts = timestamp - m_videoStart;
    scaled->duration = frame->duration;
    encode(m_videoEncoder.get(), scaled, m_videoOut);
    ++m_videoEncodedFrames;
    m_fraction = double(timestamp - m_videoStart) / double(std::max<int64_t>(1, m_videoEnd - m_videoStart));
}

void SegmentJob::copyAudio(AVPacket *packet)
{
    const int64_t timestamp = packet->pts != AV_NOPTS_VALUE ? packet->pts : packet->dts;
    if (timestamp == AV_NOPTS_VALUE)
        return;
    if (timestamp >= m_audioEnd) {
        m_audioDone = true;
        return;
    }
    if (timestamp + packet->duration <= m_audioStart)
        return;
    // The first packet may start a little before the cut; MP4 records the negative start in an
    // edit list, so players still begin at the cut.
    if (packet->pts != AV_NOPTS_VALUE)
        packet->pts -= m_audioStart;
    if (packet->dts != AV_NOPTS_VALUE)
        packet->dts -= m_audioStart;
    packet->pos = -1;
    packet->stream_index = m_audioOut->index;
    av_packet_rescale_ts(packet, m_audioIn->time_base, m_audioOut->time_base);
    check(av_interleaved_write_frame(m_output.get(), packet), tr("Could not write the audio"));
}

// packet == nullptr drains the decoder.
void SegmentJob::decodeAudio(const AVPacket *packet)
{
    AVCodecContext *decoder = m_audioDecoder.get();
    avcodec_send_packet(decoder, packet);
    AVFrame *frame = m_decoded.get();
    for (;;) {
        const int result = avcodec_receive_frame(decoder, frame);
        if (result == AVERROR(EAGAIN) || result == AVERROR_EOF)
            break;
        check(result, tr("Could not decode the audio"));
        if (frame->best_effort_timestamp != AV_NOPTS_VALUE && !m_audioDone)
            queueAudio(frame, frame->best_effort_timestamp);
        av_frame_unref(frame);
    }
    encodeQueuedAudio(false);
}

void SegmentJob::queueAudio(const AVFrame *frame, int64_t timestamp)
{
    AVCodecContext *encoder = m_audioEncoder.get();
    AVFrame *resampled = m_resampled.get();
    av_frame_unref(resampled);
    resampled->format = encoder->sample_fmt;
    resampled->sample_rate = encoder->sample_rate;
    check(av_channel_layout_copy(&resampled->ch_layout, &encoder->ch_layout), tr("Out of memory."));
    check(swr_convert_frame(m_resampler.get(), resampled, frame), tr("Could not resample the audio"));

    // Where this frame starts relative to the cut, in output samples; the resampler's few
    // samples of delay are ignored.
    const int64_t start = av_rescale_q(timestamp - m_audioStart, m_audioIn->time_base, encoder->time_base);
    if (start >= m_audioTargetSamples) {
        m_audioDone = true;
        return;
    }
    const int64_t skip = std::clamp<int64_t>(-start, 0, resampled->nb_samples);
    const int64_t count = std::min<int64_t>(resampled->nb_samples - skip, m_audioTargetSamples - m_audioQueuedSamples);
    if (count > 0) {
        if (m_audioFirstSample < 0)
            m_audioFirstSample = std::max<int64_t>(0, start);
        void *planes[AV_NUM_DATA_POINTERS] = {};
        const int bytesPerSample = av_get_bytes_per_sample(encoder->sample_fmt);
        for (int i = 0; i < encoder->ch_layout.nb_channels && i < AV_NUM_DATA_POINTERS; ++i)
            planes[i] = resampled->extended_data[i] + skip * bytesPerSample;
        check(av_audio_fifo_write(m_audioFifo.get(), planes, int(count)), tr("Out of memory."));
        m_audioQueuedSamples += count;
    }
    if (m_audioQueuedSamples >= m_audioTargetSamples)
        m_audioDone = true;
}

void SegmentJob::encodeQueuedAudio(bool flush)
{
    AVCodecContext *encoder = m_audioEncoder.get();
    AVAudioFifo *fifo = m_audioFifo.get();
    AVFrame *frame = m_audioFrame.get();
    while (av_audio_fifo_size(fifo) >= encoder->frame_size || (flush && av_audio_fifo_size(fifo) > 0)) {
        check(av_frame_make_writable(frame), tr("Out of memory."));
        frame->nb_samples = std::min(av_audio_fifo_size(fifo), encoder->frame_size);
        av_audio_fifo_read(fifo, reinterpret_cast<void **>(frame->data), frame->nb_samples);
        frame->pts = m_audioFirstSample + m_audioEncodedSamples;
        m_audioEncodedSamples += frame->nb_samples;
        encode(encoder, frame, m_audioOut);
    }
    if (flush)
        encode(encoder, nullptr, m_audioOut);
}

// frame == nullptr drains the encoder.
void SegmentJob::encode(AVCodecContext *encoder, const AVFrame *frame, AVStream *stream)
{
    AVPacket *packet = m_encodedPacket.get();
    for (;;) {
        // Media Foundation encoders may refuse input until their output has been taken.
        const int sent = avcodec_send_frame(encoder, frame);
        for (;;) {
            const int received = avcodec_receive_packet(encoder, packet);
            if (received == AVERROR(EAGAIN) || received == AVERROR_EOF)
                break;
            check(received, tr("Could not encode the segment"));
            packet->stream_index = stream->index;
            av_packet_rescale_ts(packet, encoder->time_base, stream->time_base);
            check(av_interleaved_write_frame(m_output.get(), packet), tr("Could not write the segment"));
        }
        if (sent != AVERROR(EAGAIN)) {
            if (sent != AVERROR_EOF)
                check(sent, tr("Could not encode the segment"));
            return;
        }
    }
}

void SegmentJob::reportProgress()
{
    if (!m_progress(std::clamp(m_fraction, 0.0, 1.0)))
        throw Canceled{};
}

} // namespace

namespace toyfoxx {

bool isSegmentTranscoderAvailable()
{
    static const bool available = [] {
        const QString names[] = {
            QStringLiteral("avformat-%1.dll").arg(LIBAVFORMAT_VERSION_MAJOR),
            QStringLiteral("avcodec-%1.dll").arg(LIBAVCODEC_VERSION_MAJOR),
            QStringLiteral("avutil-%1.dll").arg(LIBAVUTIL_VERSION_MAJOR),
            QStringLiteral("swscale-%1.dll").arg(LIBSWSCALE_VERSION_MAJOR),
            QStringLiteral("swresample-%1.dll").arg(LIBSWRESAMPLE_VERSION_MAJOR),
        };
        // The same search the delay-load helper does. The modules stay loaded; Qt's media
        // backend has them loaded anyway.
        return std::ranges::all_of(names, [](const QString &name) {
            return LoadLibraryW(reinterpret_cast<LPCWSTR>(name.utf16())) != nullptr;
        });
    }();
    return available;
}

SegmentResult transcodeSegment(const SegmentRequest &request, const std::function<bool(double)> &progress)
{
    SegmentResult result;
    SegmentJob job(request, progress);
    try {
        job.run();
        return result;
    } catch (const Canceled &) {
        result.canceled = true;
    } catch (const Failure &failure) {
        result.error = failure.message;
    } catch (const std::exception &exception) {
        result.error = QString::fromLocal8Bit(exception.what());
    }
    job.close();
    if (job.createdOutput())
        QFile::remove(request.outputPath);
    return result;
}

} // namespace toyfoxx
