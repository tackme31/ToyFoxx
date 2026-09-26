#pragma once

#include <QObject>
#include <QQmlEngine>

// Keeps the display (and so the system) from idling off while active, via
// SetThreadExecutionState. The state belongs to the calling thread, so this is used from the GUI
// thread only.
class DisplayKeepAwake : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)

public:
    using QObject::QObject;
    ~DisplayKeepAwake() override;

    bool isActive() const { return m_active; }
    void setActive(bool active);

signals:
    void activeChanged();

private:
    bool m_active = false;
};
