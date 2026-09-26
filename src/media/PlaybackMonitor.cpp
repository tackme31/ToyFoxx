#include "PlaybackMonitor.h"

#include <QMutexLocker>

#include <algorithm>

using namespace std::chrono_literals;

PlaybackMonitor::PlaybackMonitor(QObject *parent)
    : QObject(parent)
{
    m_clock.start();
    m_publishTimer.setInterval(500ms);
    connect(&m_publishTimer, &QTimer::timeout, this, &PlaybackMonitor::publish);
}

PlaybackMonitor::~PlaybackMonitor()
{
    disconnect(m_sinkConnection);
    disconnect(m_swapConnection);
}

void PlaybackMonitor::setVideoSink(QVideoSink *sink)
{
    if (m_videoSink == sink)
        return;
    m_videoSink = sink;
    reconnect();
    emit videoSinkChanged();
}

void PlaybackMonitor::setWindow(QQuickWindow *window)
{
    if (m_window == window)
        return;
    m_window = window;
    reconnect();
    emit windowChanged();
}

void PlaybackMonitor::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    reconnect();
    emit activeChanged();
}

void PlaybackMonitor::setExpectedFps(double fps)
{
    if (qFuzzyCompare(m_expectedFps, fps))
        return;
    m_expectedFps = fps;
    {
        QMutexLocker lock(&m_mutex);
        // A frame arriving more than 1.5 intervals after the previous one means at least one
        // frame slot was missed.
        m_lateThresholdNs = fps > 0 ? qint64(1.5e9 / fps) : 0;
    }
    emit expectedFpsChanged();
}

void PlaybackMonitor::setPlaying(bool playing)
{
    if (m_playing == playing)
        return;
    m_playing = playing;
    {
        QMutexLocker lock(&m_mutex);
        m_measureGaps = playing;
        m_current.lastSinkNs = -1;
    }
    emit playingChanged();
}

void PlaybackMonitor::reset()
{
    {
        QMutexLocker lock(&m_mutex);
        m_current = {};
    }
    m_windowClock.restart();
    m_totalLateFrames = 0;
    m_worstSinkGapMs = 0;
    m_sinkFps = m_swapFps = m_maxSinkGapMs = 0;
    m_recentLateFrames = 0;
    emit statsChanged();
}

void PlaybackMonitor::reconnect()
{
    disconnect(m_sinkConnection);
    disconnect(m_swapConnection);
    m_publishTimer.stop();
    if (!m_active)
        return;

    // Direct connections: the slots run on the emitting thread, so no per-frame event is queued
    // to the GUI thread.
    if (m_videoSink)
        m_sinkConnection = connect(m_videoSink, &QVideoSink::videoFrameChanged, this,
                                   &PlaybackMonitor::onSinkFrame, Qt::DirectConnection);
    if (m_window)
        m_swapConnection = connect(m_window, &QQuickWindow::frameSwapped, this,
                                   &PlaybackMonitor::onFrameSwapped, Qt::DirectConnection);
    reset();
    m_publishTimer.start();
}

void PlaybackMonitor::onSinkFrame()
{
    const qint64 now = m_clock.nsecsElapsed();
    QMutexLocker lock(&m_mutex);
    ++m_current.sinkFrames;
    if (m_measureGaps && m_current.lastSinkNs >= 0) {
        const qint64 gap = now - m_current.lastSinkNs;
        m_current.maxGapNs = std::max(m_current.maxGapNs, gap);
        if (m_lateThresholdNs > 0 && gap > m_lateThresholdNs)
            ++m_current.lateFrames;
    }
    m_current.lastSinkNs = now;
}

void PlaybackMonitor::onFrameSwapped()
{
    QMutexLocker lock(&m_mutex);
    ++m_current.swaps;
}

void PlaybackMonitor::publish()
{
    Window snapshot;
    {
        QMutexLocker lock(&m_mutex);
        snapshot = m_current;
        m_current = {};
        // Keep the last timestamp so the gap across the window boundary still counts.
        m_current.lastSinkNs = snapshot.lastSinkNs;
    }
    const double seconds = std::max(m_windowClock.restart(), qint64(1)) / 1000.0;

    m_sinkFps = snapshot.sinkFrames / seconds;
    m_swapFps = snapshot.swaps / seconds;
    m_maxSinkGapMs = snapshot.maxGapNs / 1e6;
    m_recentLateFrames = snapshot.lateFrames;
    m_totalLateFrames += snapshot.lateFrames;
    m_worstSinkGapMs = std::max(m_worstSinkGapMs, m_maxSinkGapMs);
    emit statsChanged();
}
