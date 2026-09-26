#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>

namespace QWK {
class QuickWindowAgent;
}

// Hands the window's caption to QML via QWindowKit while keeping the native frame behaviour
// (Snap Layout flyout, DWM animations, shadow, rounded corners). Wrapped rather than exposed
// directly: QWindowKit exports no metatypes, so QML tooling could not see its agent, and one
// call here also fixes the required order (setup before any registration).
class FramelessWindow : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    using QObject::QObject;

    // Call once, before the window is first shown.
    Q_INVOKABLE void attach(QQuickWindow *window, QQuickItem *titleBar, QQuickItem *minimizeButton,
                            QQuickItem *maximizeButton, QQuickItem *closeButton);

private:
    QWK::QuickWindowAgent *m_agent = nullptr;
};
