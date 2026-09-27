#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>

#include <atomic>
#include <memory>

// Exports a segment of the open media to an MP4 in the Videos folder, cut exactly at its ends
// (see toyfoxx::transcodeSegment). One export at a time, on the thread pool.
class SegmentExporter : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // False when the FFmpeg DLLs of Qt's media backend cannot be loaded, e.g. after a Qt upgrade
    // changed their major version; start() then only reports a failure.
    Q_PROPERTY(bool available READ isAvailable CONSTANT)
    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)
    // 0..1, by video time written.
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)

public:
    using QObject::QObject;
    // Cancels a running export, which then removes its partial file.
    ~SegmentExporter() override;

    bool isAvailable() const;
    bool isBusy() const { return m_busy; }
    double progress() const { return m_progress; }

    // startMs and endMs are MediaPlayer positions. Ignored while an export is running.
    Q_INVOKABLE void start(const QUrl &source, qint64 startMs, qint64 endMs, const QString &title);
    Q_INVOKABLE void cancel();

signals:
    void busyChanged();
    void progressChanged();
    void finished(const QString &filePath);
    void failed(const QString &message);
    void canceled();

private:
    void setProgress(double progress);
    void finish(const QString &filePath, bool canceled, const QString &error);

    bool m_busy = false;
    double m_progress = 0;
    std::shared_ptr<std::atomic_bool> m_cancel;
};
