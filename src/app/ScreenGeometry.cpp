#include "ScreenGeometry.h"

#include <QGuiApplication>
#include <QScreen>

#include <algorithm>

namespace toyfoxx {

QRect fitRectToScreens(const QRect &rect, const QList<QRect> &availableAreas, const QRect &primaryArea)
{
    QRect area = primaryArea;
    qint64 bestOverlap = 0;
    for (const QRect &candidate : availableAreas) {
        const QRect overlap = candidate.intersected(rect);
        const qint64 size = qint64(overlap.width()) * overlap.height();
        if (size > bestOverlap) {
            bestOverlap = size;
            area = candidate;
        }
    }
    if (area.isEmpty())
        return rect;

    QRect fitted(rect.topLeft(), rect.size().boundedTo(area.size()));
    fitted.moveLeft(std::clamp(fitted.left(), area.left(), area.right() - fitted.width() + 1));
    fitted.moveTop(std::clamp(fitted.top(), area.top(), area.bottom() - fitted.height() + 1));
    return fitted;
}

} // namespace toyfoxx

QRect ScreenGeometry::fitToAvailableScreens(const QRect &rect) const
{
    QList<QRect> areas;
    for (const QScreen *screen : QGuiApplication::screens())
        areas.append(screen->availableGeometry());
    const QScreen *primary = QGuiApplication::primaryScreen();
    return toyfoxx::fitRectToScreens(rect, areas, primary ? primary->availableGeometry() : QRect());
}
