#pragma once

#include <QObject>
#include <QQmlEngine>

class ShellIntegration : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // Opens an Explorer window with the file selected.
    Q_INVOKABLE void revealInExplorer(const QString &filePath) const;
};
