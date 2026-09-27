#include "SegmentExporter.h"

#include "FileNames.h"
#include "SegmentTranscoder.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QPointer>
#include <QStandardPaths>
#include <QThreadPool>

namespace {

// Runs f on the GUI thread if the exporter still exists by then. Posted via the application, not
// via the exporter: turning the QPointer into a context on the worker thread would race with the
// exporter's destruction on the GUI thread. instance() is already null while ~QCoreApplication
// drains the global pool, and the application object is not freed until that drain returns.
template<typename F>
void postToExporter(const QPointer<SegmentExporter> &exporter, F f)
{
    if (QCoreApplication *app = QCoreApplication::instance()) {
        QMetaObject::invokeMethod(
            app, [exporter, f = std::move(f)] {
                if (exporter)
                    f(exporter.data());
            },
            Qt::QueuedConnection);
    }
}

} // namespace

SegmentExporter::~SegmentExporter()
{
    cancel();
}

bool SegmentExporter::isAvailable() const
{
    return toyfoxx::isSegmentTranscoderAvailable();
}

void SegmentExporter::start(const QUrl &source, qint64 startMs, qint64 endMs, const QString &title)
{
    if (m_busy)
        return;
    if (!isAvailable()) {
        emit failed(tr("The FFmpeg libraries of Qt's media backend could not be loaded."));
        return;
    }
    if (!source.isLocalFile()) {
        emit failed(tr("Only local files can be exported."));
        return;
    }
    if (startMs < 0 || endMs <= startMs) {
        emit failed(tr("The segment is empty."));
        return;
    }

    const QString directory = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    toyfoxx::SegmentRequest request;
    request.inputPath = QDir::toNativeSeparators(source.toLocalFile());
    request.outputPath = QDir::toNativeSeparators(QDir(directory).filePath(toyfoxx::timestampedFileName(
        title, QDateTime::currentDateTime(), QStringLiteral("segment"), QStringLiteral(".mp4"))));
    request.startMs = startMs;
    request.endMs = endMs;

    m_cancel = std::make_shared<std::atomic_bool>(false);
    m_busy = true;
    emit busyChanged();
    setProgress(0);

    QThreadPool::globalInstance()->start([self = QPointer(this), cancel = m_cancel, request, directory] {
        if (!QDir().mkpath(directory)) {
            const QString error = tr("Could not create %1.").arg(QDir::toNativeSeparators(directory));
            postToExporter(self, [error](SegmentExporter *e) { e->finish({}, false, error); });
            return;
        }
        int reportedPercent = 0;
        const auto progress = [&](double fraction) {
            // Posted once per percent, not per frame.
            const int percent = int(fraction * 100);
            if (percent != reportedPercent) {
                reportedPercent = percent;
                postToExporter(self, [fraction](SegmentExporter *e) { e->setProgress(fraction); });
            }
            return !cancel->load();
        };
        const toyfoxx::SegmentResult result = toyfoxx::transcodeSegment(request, progress);
        postToExporter(self, [result, path = request.outputPath](SegmentExporter *e) {
            e->finish(path, result.canceled, result.error);
        });
    });
}

void SegmentExporter::cancel()
{
    if (m_cancel)
        m_cancel->store(true);
}

void SegmentExporter::setProgress(double progress)
{
    if (!m_busy || m_progress == progress)
        return;
    m_progress = progress;
    emit progressChanged();
}

void SegmentExporter::finish(const QString &filePath, bool canceled, const QString &error)
{
    m_cancel.reset();
    m_busy = false;
    emit busyChanged();
    if (canceled)
        emit this->canceled();
    else if (!error.isEmpty())
        emit failed(error);
    else
        emit finished(filePath);
}
