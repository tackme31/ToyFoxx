#pragma once

#include <QString>

class QDateTime;

namespace toyfoxx {

// "<title>_<yyyyMMddHHmmsszzz><extension>" with characters Windows forbids in file names removed
// from the title, and fallback in its place when nothing is left.
QString timestampedFileName(const QString &title, const QDateTime &time, const QString &fallback,
                            const QString &extension);

} // namespace toyfoxx
