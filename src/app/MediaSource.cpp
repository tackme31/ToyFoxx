#include "MediaSource.h"

#include <QFileInfo>

namespace toyfoxx {

QUrl resolveMediaSource(const QString &input)
{
    qsizetype begin = 0;
    qsizetype end = input.size();
    const auto isTrimmed = [](QChar c) { return c.isSpace() || c == u'"'; };
    while (begin < end && isTrimmed(input.at(begin)))
        ++begin;
    while (end > begin && isTrimmed(input.at(end - 1)))
        --end;
    const QString text = input.sliced(begin, end - begin);
    if (text.isEmpty())
        return {};

    const QFileInfo file(text);
    if (file.isFile())
        return QUrl::fromLocalFile(file.absoluteFilePath());

    // Hand the string over unchanged so signed URLs keep their exact query. A one-letter
    // scheme is a Windows drive letter of a path that does not exist, not a URI.
    const QUrl url(text);
    if (url.isValid() && !url.isRelative() && url.scheme().size() > 1 && !url.isLocalFile())
        return url;

    return {};
}

} // namespace toyfoxx

QUrl MediaSource::resolve(const QString &input) const
{
    return toyfoxx::resolveMediaSource(input);
}

QUrl MediaSource::resolveUrl(const QUrl &url) const
{
    return toyfoxx::resolveMediaSource(url.isLocalFile() ? url.toLocalFile() : url.toString());
}
