#pragma once

#include <QString>

#include <functional>

namespace toyfoxx {

struct SegmentRequest
{
    QString inputPath;
    QString outputPath;
    // Media positions as MediaPlayer reports them: from the start of the media, in ms.
    qint64 startMs = 0;
    qint64 endMs = 0;
};

struct SegmentResult
{
    bool canceled = false;
    // Empty on success and on cancel.
    QString error;
};

// Whether the FFmpeg DLLs that Qt's media backend ships, and this build was linked against
// (delay-loaded), can be loaded. Nothing else here may be called when this is false.
bool isSegmentTranscoderAvailable();

// Writes [startMs, endMs) of the input to an MP4 cut at exactly those points: the video is
// decoded and re-encoded (H.264, or HEVC past H.264's frame size limit, through Media
// Foundation), since a stream copy could only start on a key frame. The audio track the
// player would pick is copied packet by packet when MP4 can hold it, else re-encoded to AAC.
// Other streams are dropped. Blocking; run it off the GUI thread. progress receives 0..1 and
// returns false to cancel. The output file is removed on failure or cancel.
SegmentResult transcodeSegment(const SegmentRequest &request, const std::function<bool(double)> &progress);

} // namespace toyfoxx
