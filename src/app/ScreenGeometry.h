#pragma once

#include <QList>
#include <QObject>
#include <QQmlEngine>
#include <QRect>

namespace toyfoxx {

// Moves and, if needed, shrinks rect so it lies inside one of the available screen areas: the
// one it overlaps most, or the primary area when it overlaps none (a monitor was unplugged).
QRect fitRectToScreens(const QRect &rect, const QList<QRect> &availableAreas, const QRect &primaryArea);

} // namespace toyfoxx

class ScreenGeometry : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // fitRectToScreens against the current screens' available geometry (taskbar excluded).
    Q_INVOKABLE QRect fitToAvailableScreens(const QRect &rect) const;
};
