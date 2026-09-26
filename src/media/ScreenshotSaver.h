#pragma once

#include <QObject>
#include <QQmlEngine>

class QVideoSink;

namespace toyfoxx {

// "<title>_<yyyyMMddHHmmsszzz>.png" with characters Windows forbids in file names removed.
QString screenshotFileName(const QString &title, const QDateTime &time);

} // namespace toyfoxx

// Saves the frame currently held by a video sink as a PNG in the Pictures folder, at source
// resolution and without the view's zoom or rotation.
class ScreenshotSaver : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)

public:
    using QObject::QObject;

    bool isBusy() const { return m_busy; }

    // Reads the frame back once, on the calling (GUI) thread; encoding and writing run on the
    // thread pool. Ignored while a previous save is still running.
    Q_INVOKABLE void save(QVideoSink *sink, const QString &title);

signals:
    void busyChanged();
    void saved(const QString &filePath);
    void failed(const QString &message);

private:
    void finish(const QString &filePath, const QString &error);

    bool m_busy = false;
};
