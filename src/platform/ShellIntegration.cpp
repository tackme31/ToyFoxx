#include "ShellIntegration.h"

#include <QDir>

#include <qt_windows.h>
#include <shlobj.h>

void ShellIntegration::revealInExplorer(const QString &filePath) const
{
    // Reuses an Explorer window already showing the folder, and takes the path as an ID list
    // rather than a command line, so commas and quotes in file names need no escaping.
    // COM is already initialized on the GUI thread by the Qt Windows platform plugin.
    const QString nativePath = QDir::toNativeSeparators(filePath);
    PIDLIST_ABSOLUTE item = ILCreateFromPathW(reinterpret_cast<PCWSTR>(nativePath.utf16()));
    if (!item)
        return;
    SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
    ILFree(item);
}
