#include "CaptionHoverTracker.h"

#include <QCoreApplication>

#include <qt_windows.h>
#include <windowsx.h>

CaptionHoverTracker::CaptionHoverTracker(QObject *parent)
    : QObject(parent)
{
    QCoreApplication::instance()->installNativeEventFilter(this);
}

CaptionHoverTracker::~CaptionHoverTracker()
{
    if (QCoreApplication *app = QCoreApplication::instance())
        app->removeNativeEventFilter(this);
}

void CaptionHoverTracker::setWindow(QQuickWindow *window)
{
    if (m_window == window)
        return;
    m_window = window;
    setHovered(false);
    emit windowChanged();
}

bool CaptionHoverTracker::nativeEventFilter(const QByteArray &eventType, void *message, qintptr *)
{
    if (!m_window || !m_window->handle() || eventType != "windows_generic_MSG")
        return false;
    const MSG *msg = static_cast<const MSG *>(message);
    const HWND hwnd = reinterpret_cast<HWND>(m_window->winId());
    if (msg->hwnd != hwnd)
        return false;

    switch (msg->message) {
    case WM_NCMOUSEMOVE: {
        if (!m_hovered) {
            // Windows sends WM_NCMOUSELEAVE only after it has been asked to.
            TRACKMOUSEEVENT track{sizeof(TRACKMOUSEEVENT), TME_LEAVE | TME_NONCLIENT, hwnd, 0};
            TrackMouseEvent(&track);
            setHovered(true);
        }
        const QPoint position(GET_X_LPARAM(msg->lParam), GET_Y_LPARAM(msg->lParam));
        if (position != m_lastPosition) {
            m_lastPosition = position;
            emit moved();
        }
        break;
    }
    case WM_NCMOUSELEAVE:
        m_lastPosition = QPoint(-1, -1);
        setHovered(false);
        break;
    default:
        break;
    }
    // Observe only; QWindowKit and Qt still handle every message.
    return false;
}

void CaptionHoverTracker::setHovered(bool hovered)
{
    if (m_hovered == hovered)
        return;
    m_hovered = hovered;
    emit hoveredChanged();
}
