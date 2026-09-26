#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>

namespace toyfoxx {

// Turns user input (a path or a URL) into a playable source, or an empty QUrl when the
// input names neither an existing local file nor a non-file absolute URI.
QUrl resolveMediaSource(const QString &input);

// Human-readable name of a source: the file name without its extension, or the host when a
// URL has no file name. Truncated to 64 characters plus "..."; empty for an empty source.
QString mediaDisplayTitle(const QUrl &source);

} // namespace toyfoxx

class MediaSource : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    Q_INVOKABLE QUrl resolve(const QString &input) const;
    // For URLs handed over by QML (DropArea, FileDialog), which arrive as file: URLs.
    Q_INVOKABLE QUrl resolveUrl(const QUrl &url) const;
    Q_INVOKABLE QString displayTitle(const QUrl &source) const;
};
