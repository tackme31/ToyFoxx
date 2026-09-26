#include "ShellIntegration.h"

#include <QDir>
#include <QProcess>

void ShellIntegration::revealInExplorer(const QString &filePath) const
{
    // "/select," and the path as separate arguments: Explorer parses its command line itself,
    // and this split keeps paths with spaces intact once QProcess quotes them.
    QProcess::startDetached(QStringLiteral("explorer.exe"),
                            {QStringLiteral("/select,"), QDir::toNativeSeparators(filePath)});
}
