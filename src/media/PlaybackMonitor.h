#pragma once

#include <QElapsedTimer>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QTimer>
#include <QVideoSink>

// Diagnostic only: measures how evenly frames reach the video sink and how often the scene graph
// presents, without touching frame contents. Per-frame work is a timestamp under an uncontended
// lock on the emitting thread; QML only sees a snapshot every update interval.
class PlaybackMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVideoSink *videoSink READ videoSink WRITE setVideoSink NOTIFY videoSinkChanged)
    Q_PROPERTY(QQuickWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(double expectedFps READ expectedFps WRITE setExpectedFps NOTIFY expectedFpsChanged)
    // Gaps are only measured while playing, so a pause is not reported as a late frame.
    Q_PROPERTY(bool playing READ isPlaying WRITE setPlaying NOTIFY playingChanged)

    Q_PROPERTY(double sinkFps READ sinkFps NOTIFY statsChanged)
    Q_PROPERTY(double swapFps READ swapFps NOTIFY statsChanged)
    Q_PROPERTY(double maxSinkGapMs READ maxSinkGapMs NOTIFY statsChanged)
    Q_PROPERTY(int recentLateFrames READ recentLateFrames NOTIFY statsChanged)
    Q_PROPERTY(int totalLateFrames READ totalLateFrames NOTIFY statsChanged)
    Q_PROPERTY(double worstSinkGapMs READ worstSinkGapMs NOTIFY statsChanged)

public:
    explicit PlaybackMonitor(QObject *parent = nullptr);
    ~PlaybackMonitor() override;

    QVideoSink *videoSink() const { return m_videoSink; }
    void setVideoSink(QVideoSink *sink);
    QQuickWindow *window() const { return m_window; }
    void setWindow(QQuickWindow *window);
    bool isActive() const { return m_active; }
    void setActive(bool active);
    double expectedFps() const { return m_expectedFps; }
    void setExpectedFps(double fps);
    bool isPlaying() const { return m_playing; }
    void setPlaying(bool playing);

    double sinkFps() const { return m_sinkFps; }
    double swapFps() const { return m_swapFps; }
    double maxSinkGapMs() const { return m_maxSinkGapMs; }
    int recentLateFrames() const { return m_recentLateFrames; }
    int totalLateFrames() const { return m_totalLateFrames; }
    double worstSinkGapMs() const { return m_worstSinkGapMs; }

    Q_INVOKABLE void reset();

signals:
    void videoSinkChanged();
    void windowChanged();
    void activeChanged();
    void expectedFpsChanged();
    void playingChanged();
    void statsChanged();

private:
    struct Window
    {
        int sinkFrames = 0;
        int swaps = 0;
        int lateFrames = 0;
        qint64 maxGapNs = 0;
        qint64 lastSinkNs = -1;
    };

    void reconnect();
    void onSinkFrame();
    void onFrameSwapped();
    void publish();

    QPointer<QVideoSink> m_videoSink;
    QPointer<QQuickWindow> m_window;
    QMetaObject::Connection m_sinkConnection;
    QMetaObject::Connection m_swapConnection;
    bool m_active = false;
    double m_expectedFps = 0;
    bool m_playing = false;

    QTimer m_publishTimer;
    QElapsedTimer m_clock;
    QElapsedTimer m_windowClock;

    // Guarded by m_mutex: written from the decoder/render threads, read on the GUI thread.
    QMutex m_mutex;
    Window m_current;
    qint64 m_lateThresholdNs = 0;
    bool m_measureGaps = false;

    double m_sinkFps = 0;
    double m_swapFps = 0;
    double m_maxSinkGapMs = 0;
    int m_recentLateFrames = 0;
    int m_totalLateFrames = 0;
    double m_worstSinkGapMs = 0;
};
