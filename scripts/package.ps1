<#
.SYNOPSIS
    Build ToyFoxx in Release, zip it, and check the zip works on its own.

.DESCRIPTION
    Release build in build-release/ -> CPack's ZIP (the install rules deploy Qt
    through windeployqt and add the MSVC runtime) -> check the archive holds
    what a machine without Qt needs and nothing GPL-only -> unpack it and
    launch the exe from there, with Qt's directories stripped from PATH, until
    a window appears.

    Every failure this guards against -- a missing Qt DLL, plugin or QML
    module, a missing licence file -- builds and packages cleanly and then dies
    on someone else's desktop.

    Qt is found through $env:QTDIR, or else qtpaths.exe on PATH. CMake and
    Ninja are the ones in that Qt installation's Tools directory. The MSVC
    environment is loaded from Visual Studio's vcvars64.bat via vswhere.

.PARAMETER SkipBuild
    Package whatever is already built. Fails if the binary is missing.

.EXAMPLE
    ./scripts/package.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildDir = Join-Path $RepoRoot 'build-release'
$exePath = Join-Path $buildDir 'ToyFoxx.exe'

# ------------------------------------------------------------------ toolchain
$qtDir = $env:QTDIR
if (-not $qtDir) {
    $qtpaths = Get-Command qtpaths.exe -ErrorAction SilentlyContinue
    if (-not $qtpaths) { throw 'Qt not found: set $env:QTDIR or put Qt''s bin directory on PATH' }
    $qtDir = Split-Path (Split-Path $qtpaths.Source)
}
# <Qt>/6.x.y/msvc2022_64 -> <Qt>/Tools
$qtTools = Join-Path (Split-Path (Split-Path $qtDir)) 'Tools'
# The cmake/ninja earlier on PATH may be MinGW's or Strawberry Perl's; always Qt's own.
$CMake = Join-Path $qtTools 'CMake_64/bin/cmake.exe'
$CPack = Join-Path $qtTools 'CMake_64/bin/cpack.exe'
$ninjaDir = Join-Path $qtTools 'Ninja'
foreach ($tool in @($CMake, $CPack, (Join-Path $ninjaDir 'ninja.exe'))) {
    if (-not (Test-Path $tool)) { throw "$tool not found" }
}

function Import-MsvcEnvironment {
    if ($env:VCINSTALLDIR) { return }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (-not (Test-Path $vswhere)) { throw 'vswhere.exe not found; is Visual Studio 2022 installed?' }
    $vs = & $vswhere -latest -version '[17.0,18.0)' -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'no Visual Studio 2022 with the x64 C++ tools found' }
    $vcvars = Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
    $lines = & cmd.exe /c "`"$vcvars`" >nul && set"
    if ($LASTEXITCODE -ne 0) { throw "vcvars64.bat failed ($LASTEXITCODE)" }
    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
    }
}

# ---------------------------------------------------------------------- build
if (-not $SkipBuild) {
    Import-MsvcEnvironment
    $env:PATH = "$ninjaDir;$env:PATH"
    if (-not (Test-Path (Join-Path $buildDir 'CMakeCache.txt'))) {
        & $CMake -S $RepoRoot -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_PREFIX_PATH=$qtDir"
        if ($LASTEXITCODE -ne 0) { throw "configure failed ($LASTEXITCODE)" }
    }
    & $CMake --build $buildDir
    if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }
    & $CMake --build $buildDir --target all_qmllint
    if ($LASTEXITCODE -ne 0) { throw "qmllint failed ($LASTEXITCODE)" }
}
if (-not (Test-Path $exePath)) { throw "$exePath not found -- build first" }

# -------------------------------------------------------------------- package
$outDir = Join-Path $buildDir 'package'
# CPack only ever adds to this directory; an older version's zip left in it
# would be the one picked below if this run produced a differently named one.
Remove-Item -Path (Join-Path $outDir '*.zip') -Force -ErrorAction SilentlyContinue
& $CPack --config (Join-Path $buildDir 'CPackConfig.cmake') -B $outDir
if ($LASTEXITCODE -ne 0) { throw "cpack failed ($LASTEXITCODE)" }

$zip = Get-ChildItem -LiteralPath $outDir -Filter '*.zip' | Select-Object -First 1
if (-not $zip) { throw "no zip produced in $outDir" }

# ------------------------------------------------------------------- contents
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName })
} finally {
    $archive.Dispose()
}

# One entry per thing that can go missing on its own: Qt's libraries, the
# platform and multimedia plugins with Qt's FFmpeg, the QML modules and the
# Controls style (windeployqt), the MSVC runtime (InstallRequiredSystemLibraries),
# and the two text files a binary distribution is obliged to carry.
$required = @(
    '/ToyFoxx.exe',
    '/qt.conf',
    '/Qt6Core.dll',
    '/Qt6Quick.dll',
    '/Qt6Multimedia.dll',
    '/platforms/qwindows.dll',
    '/multimedia/ffmpegmediaplugin.dll',
    '/imageformats/qsvg.dll',
    '/qml/QtMultimedia/qmldir',
    '/qml/QtQuick/Controls/FluentWinUI3/qmldir',
    '/VCRUNTIME140.dll',
    '/MSVCP140.dll',
    '/LICENSE',
    '/THIRD-PARTY-NOTICES.txt'
)
# OrdinalIgnoreCase: the redist ships its DLLs lower-cased, Qt its own capitalised.
$missing = $required | Where-Object {
    $suffix = $_
    -not ($entries | Where-Object { $_.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase) })
}
if ($missing) { throw "zip is missing: $($missing -join ', ')" }
if (-not ($entries | Where-Object { $_ -match '/avcodec-\d+\.dll$' })) { throw 'zip is missing FFmpeg (avcodec-*.dll)' }

# Qt Quick 3D and Qt Quick Timeline are GPLv3-only; the MIT + LGPL distribution
# described in THIRD-PARTY-NOTICES.txt must not carry them.
$gplOnly = $entries | Where-Object { $_ -match '(Quick3D|Timeline)[^/]*\.dll$|/qmltooling/' }
if ($gplOnly) { throw "zip carries GPL-only or debug-only files: $($gplOnly -join ', ')" }

# --------------------------------------------------------------- launch check
$dest = Join-Path ([IO.Path]::GetTempPath()) 'ToyFoxx-package-check'
Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $zip.FullName -DestinationPath $dest
$exe = Get-ChildItem -Recurse -Filter ToyFoxx.exe $dest | Select-Object -First 1

# With Qt on PATH a missing DLL would be found there, and the check would pass
# on exactly the machine it is meant to stand in for.
$savedPath = $env:PATH
$env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and $_ -notmatch '[\\/]Qt[\\/]' }) -join ';'
try {
    # No arguments: the empty player window.
    $p = Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -PassThru
} finally {
    $env:PATH = $savedPath
}
$deadline = (Get-Date).AddSeconds(20)
do {
    Start-Sleep -Milliseconds 500
    $p.Refresh()
} until ($p.HasExited -or $p.MainWindowTitle -or (Get-Date) -gt $deadline)
if ($p.HasExited) { throw "the unpacked exe exited with $($p.ExitCode)" }
$title = $p.MainWindowTitle
if (-not $title) {
    $p | Stop-Process -Force
    throw 'the unpacked exe showed no window within 20s'
}
$p.CloseMainWindow() | Out-Null
if (-not $p.WaitForExit(10000)) {
    $p | Stop-Process -Force
    throw 'the unpacked exe did not close within 10s'
}
Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue

$sizeMb = [math]::Round($zip.Length / 1MB, 1)
Write-Host ("{0} ({1} MB, {2} entries; launched as '{3}')" -f $zip.FullName, $sizeMb, $entries.Count, $title) -ForegroundColor Green
