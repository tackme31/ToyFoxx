#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QUrl>

namespace toyfoxx {

// Turns user input (a path or a URL) into a playable source, or an empty QUrl when the
// input names neither an existing local file nor a non-file absolute URI.
QUrl resolveMediaSource(const QString &input);

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
};
