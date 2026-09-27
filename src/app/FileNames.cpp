#include "FileNames.h"

#include <QDateTime>

namespace toyfoxx {

QString timestampedFileName(const QString &title, const QDateTime &time, const QString &fallback,
                            const QString &extension)
{
    QString name;
    name.reserve(title.size());
    for (const QChar c : title) {
        if (c.unicode() >= 0x20 && !QStringView(u"\\/:*?\"<>|").contains(c))
            name.append(c);
    }
    name = name.trimmed();
    if (name.isEmpty())
        name = fallback;
    return name + u'_' + time.toString(QStringLiteral("yyyyMMddHHmmsszzz")) + extension;
}

} // namespace toyfoxx
