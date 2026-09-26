#include "ScreenshotSaver.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QImage>
#include <QPointer>
#include <QStandardPaths>
#include <QThreadPool>
#include <QVideoFrame>
#include <QVideoSink>

namespace toyfoxx {

QString screenshotFileName(const QString &title, const QDateTime &time)
{
    QString name;
    name.reserve(title.size());
    for (const QChar c : title) {
        if (c.unicode() >= 0x20 && !QStringView(u"\\/:*?\"<>|").contains(c))
            name.append(c);
    }
    name = name.trimmed();
    if (name.isEmpty())
        name = QStringLiteral("screenshot");
    return name + u'_' + time.toString(QStringLiteral("yyyyMMddHHmmsszzz")) + QStringLiteral(".png");
}

} // namespace toyfoxx

void ScreenshotSaver::save(QVideoSink *sink, const QString &title)
{
    if (m_busy)
        return;
    const QVideoFrame frame = sink ? sink->videoFrame() : QVideoFrame();
    if (!frame.isValid()) {
        emit failed(tr("There is no video frame to capture."));
        return;
    }
    // The single GPU-to-CPU readback of this feature, done only because the user asked for it.
    QImage image = frame.toImage();
    if (image.isNull()) {
        emit failed(tr("The video frame could not be converted to an image."));
        return;
    }

    const QString directory = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    const QString filePath =
        QDir(directory).filePath(toyfoxx::screenshotFileName(title, QDateTime::currentDateTime()));

    m_busy = true;
    emit busyChanged();

    QThreadPool::globalInstance()->start([self = QPointer(this), image = std::move(image), directory, filePath] {
        QString error;
        if (!QDir().mkpath(directory))
            error = tr("Could not create %1.").arg(QDir::toNativeSeparators(directory));
        else if (!image.save(filePath, "PNG"))
            error = tr("Could not write %1.").arg(QDir::toNativeSeparators(filePath));
        // Posted via the application, not via the saver: turning the QPointer into a context here
        // would race with the saver's destruction on the GUI thread. The QPointer is checked on
        // the GUI thread instead. instance() is already null while ~QCoreApplication drains the
        // global pool, and the application object is not freed until that drain returns.
        if (QCoreApplication *app = QCoreApplication::instance()) {
            QMetaObject::invokeMethod(
                app, [self, filePath, error] {
                    if (self)
                        self->finish(filePath, error);
                },
                Qt::QueuedConnection);
        }
    });
}

void ScreenshotSaver::finish(const QString &filePath, const QString &error)
{
    m_busy = false;
    emit busyChanged();
    if (error.isEmpty())
        emit saved(filePath);
    else
        emit failed(error);
}
