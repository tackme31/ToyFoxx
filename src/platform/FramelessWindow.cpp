#include "FramelessWindow.h"

#include <QWKQuick/quickwindowagent.h>

void FramelessWindow::attach(QQuickWindow *window, QQuickItem *titleBar, QQuickItem *minimizeButton,
                             QQuickItem *maximizeButton, QQuickItem *closeButton)
{
    if (m_agent || !window)
        return;
    m_agent = new QWK::QuickWindowAgent(this);
    // setup() creates the context that every registration below dereferences unguarded.
    m_agent->setup(window);
    m_agent->setTitleBar(titleBar);
    // Registering the buttons, not merely drawing them, is what makes Windows 11 show the Snap
    // Layout flyout on the maximize button.
    m_agent->setSystemButton(QWK::WindowAgentBase::Minimize, minimizeButton);
    m_agent->setSystemButton(QWK::WindowAgentBase::Maximize, maximizeButton);
    m_agent->setSystemButton(QWK::WindowAgentBase::Close, closeButton);
}
