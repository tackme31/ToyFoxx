#pragma once

#include <QAbstractNativeEventFilter>
#include <QObject>
#include <QPoint>
#include <QPointer>
#include <QQmlEngine>
#include <QQuickWindow>

// Reports the cursor over the window's non-client area: the caption QWindowKit hands to Windows
// (HTCAPTION) and its system buttons. Qt Quick sees no hover there, only a leave, so without this
// the auto-hide logic would take the cursor on the caption for a cursor outside the window.
class CaptionHoverTracker : public QObject, public QAbstractNativeEventFilter
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickWindow *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(bool hovered READ isHovered NOTIFY hoveredChanged)

public:
    explicit CaptionHoverTracker(QObject *parent = nullptr);
    ~CaptionHoverTracker() override;

    QQuickWindow *window() const { return m_window; }
    void setWindow(QQuickWindow *window);
    bool isHovered() const { return m_hovered; }

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override;

signals:
    void windowChanged();
    void hoveredChanged();
    // The cursor moved to a new position over the non-client area.
    void moved();

private:
    void setHovered(bool hovered);

    QPointer<QQuickWindow> m_window;
    bool m_hovered = false;
    QPoint m_lastPosition{-1, -1};
};
