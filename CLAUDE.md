# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ToyFoxx is a lightweight Windows media player built with **Qt 6 / Qt Quick (QML) and C++20**.

It is a **full rewrite** of *ToyBoxx*, a WPF + FFME (.NET 9) player: <https://github.com/tackme31/ToyBoxx>.
ToyFoxx is not a port — the .NET code is a feature reference only, and nothing is shared at the source level.
`docs/features.md` is the derived spec: what has to be built, how ToyBoxx behaves, and where ToyFoxx
deliberately differs. Read it before implementing a feature.

The rewrite exists for one reason: **4K playback performance**, especially stutter in fullscreen. In ToyBoxx,
FFME hardware-decodes on the GPU, then pulls every frame back to RAM (`av_hwframe_transfer_data`), converts
NV12 to BGRA on a single CPU thread (`sws_scale`), copies it into a WPF back buffer, and lets WPF re-upload it
to the GPU — roughly 45 MB of CPU-side traffic per frame at 3840x2160, on top of WPF's D3D9
redirection-surface compositing, which cannot use a flip-model swapchain. The full analysis is in the
predecessor repository at `docs/playback-performance.md`; read it before touching the playback path.

Qt Quick removes the round trip: the FFmpeg media backend keeps decoded frames as GPU textures, Qt RHI
composites them through a D3D11 flip-model swapchain, and the UI lives in the *same* window as the video, so
there is no airspace problem and no second native window — the main drawback of the Flyleaf / libmpv / LibVLC
options that were considered for WPF.

## Requirements

- **Qt 6.11 or newer**, MSVC 2022 x64 build, with modules: Core, Gui, Quick, QuickControls2, Multimedia,
  ShaderTools, Svg.
- **MSVC 2022 x64** toolchain. The Qt binaries are MSVC-built, so the toolchain must match. A MinGW `g++`,
  `ninja`, or an old `cmake` may appear earlier on `PATH` — do not use them. Prefer the CMake and Ninja shipped
  with the Qt installation (`Tools/CMake_64`, `Tools/Ninja`), or `qt-cmake`, which pins the correct toolchain
  automatically.
- **FFmpeg is not a build dependency and must not be vendored.** Qt's FFmpeg media backend ships with Qt
  (`plugins/multimedia/ffmpegmediaplugin.dll` plus the `av*` DLLs) and `windeployqt` deploys it. There is no
  equivalent of ToyBoxx's `requirements.ps1`.

Do not hardcode absolute Qt or FFmpeg paths anywhere in the repository. Use `CMAKE_PREFIX_PATH`, `qt-cmake`, or
CMake presets and let each developer point at their own Qt installation.

## Build & Run

With the Ninja generator, CMake does not set up the MSVC environment itself. Run these from an
**x64 Native Tools Command Prompt for VS 2022** (or a shell where `vcvars64.bat` has been sourced),
with Qt's `Tools/Ninja` on `PATH`.

```powershell
# Configure (qt-cmake, from the Qt bin directory, selects the matching toolchain)
qt-cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo

# Or with plain cmake, pointing CMAKE_PREFIX_PATH at a Qt installation
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_PREFIX_PATH="$env:QTDIR"

cmake --build build
./build/ToyFoxx.exe

# Deployable output
windeployqt --qmldir ./src/qml ./build/ToyFoxx.exe
```

**Always measure performance in a Release or RelWithDebInfo build.** Debug builds of Qt Quick and the QML
engine are not representative.

### QML tooling

```powershell
cmake --build build --target all_qmllint   # run before committing QML
qmlformat -i ./src/qml/Main.qml            # canonical QML formatting
qmlprofiler ./build/ToyFoxx.exe            # binding / frame-time hotspots
```

Use the `all_qmllint` target rather than calling `qmllint` by hand: `qt_add_qml_module` generates the
response file with the right import paths, which a bare invocation does not have.

## Architecture

**Thin C++ core, QML UI.** Rule of thumb: layout, state presentation, input mapping, and animation belong in
QML; anything that needs a Qt C++ API with no QML equivalent belongs in C++ and is exposed as a QML type.

### Planned layout

```
CMakeLists.txt
src/
  main.cpp             # QGuiApplication, QQuickStyle, engine bootstrap
  app/                 # settings, app-level services
  media/               # frame capture, thumbnail extraction, metadata helpers
  platform/            # Windows specifics (screen-timeout suppression, reveal in Explorer)
  qml/                 # the ToyFoxx QML module
    Main.qml
    VideoSurface.qml   # VideoOutput plus transform state
    ControllerPanel.qml
    SeekBar.qml
resources/             # icons, fonts
docs/
tests/                 # Qt Quick Test
```

- One QML module, URI `ToyFoxx`, declared with `qt_add_qml_module`. C++ types are registered in that same module
  via `QML_ELEMENT` / `QML_SINGLETON` — not with `qmlRegisterType` calls scattered through `main.cpp`.
- Qt Quick Controls style: **FluentWinUI3** (closest to ToyBoxx's WPF-UI look), with Basic as the fallback. Set
  it once via `QQuickStyle::setStyle` or `qtquickcontrols2.conf`, never per control.
- Playback is `MediaPlayer` + `AudioOutput` + `VideoOutput` from `QtMultimedia`. Do not wrap `QMediaPlayer` in a
  hand-written C++ facade unless a concrete need appears — the QML type's properties are already bindable.
- Persisted preferences: `Settings` from `import QtCore` for UI-owned values, `QSettings` in C++ for the rest.
  ToyBoxx stored the loop mode as an `int`; ToyFoxx starts clean, with no migration of the old
  `Properties/Settings` values.

## Feature parity target

Carried over from ToyBoxx. This is the summary; **`docs/features.md` holds the full per-feature spec** (IDs
F-01 to F-24, priorities, ToyBoxx behaviour, and intentional differences). Keep both in sync as features land.

| Feature | ToyFoxx approach |
|---|---|
| Open file (dialog, drag & drop, CLI argument) | `FileDialog`, `DropArea`, `QCommandLineParser` |
| Play / pause / stop / seek | `MediaPlayer.play/pause/stop`, `position` in ms (settable while `seekable`) |
| Jump 5 s back / forward (`Left` / `Right`) | `position` delta |
| Zoom (`Ctrl`+Wheel), pan (drag), rotate 90 degrees (`R`), original size (`F`), reset (middle click) | Scene-graph transforms on the video item — see Performance rules |
| Fullscreen (double click) | `Window.visibility = Window.FullScreen` |
| Playback speed | `playbackRate`, with `pitchCompensation` (Qt 6.10+) replacing ToyBoxx's SoundTouch dependency |
| Step forward one frame | No `QMediaPlayer` API for this. Pause, then advance `position` by `1000 / VideoFrameRate` taken from `metaData`. Accuracy is bounded by seek granularity — document that caveat rather than hiding it |
| A-B segment loop | Watch `onPositionChanged` and seek back at the endpoint. Resolution is bounded by the position notify rate; do not busy-poll |
| Screenshot (`S`) | Read `videoOutput.videoSink.videoFrame` and call `QVideoFrame::toImage()` **on keypress only** — one readback at source resolution. Never a per-frame grab, and not `grabToImage`, which captures the composited and transformed item instead |
| Seek-bar thumbnail preview | A second, hidden `QMediaPlayer` with a bare `QVideoSink` and no `VideoOutput`, seeking and grabbing single frames. ToyBoxx used a full second `MediaElement`; do not repeat that |
| Themes (Dark / Light / High Contrast) | Controls style plus a QML theme singleton |
| Toast after saving a screenshot | QML overlay in the same window |
| Auto-hide the controller panel after 3 s idle | `Timer` plus an `opacity` animation |
| Suppress screen timeout while fullscreen | C++ `SetThreadExecutionState` in `platform/` |

## Performance rules

These are the reason the project exists. Treat them as non-negotiable, and call it out in review when a change
violates one.

1. **Never move decoded frames through the CPU.** Let the FFmpeg backend hardware-decode and keep frames as GPU
   textures. No per-frame `videoFrame()`, `toImage()`, `map()`, or custom `QVideoSink` in the playback path.
2. **Zoom, pan, and rotate are scene-graph transforms** applied to the video item (`scale`, `rotation`, `x`/`y`,
   or a `transform:` list). Never rescale the frame itself, and never buy performance with a
   `VideoFilter`-style downscale the way FFME had to.
3. **No `layer.enabled: true`** on the video item or any of its ancestors, and no `ShaderEffect` or
   `MultiEffect` wrapping it. Each one forces a full-resolution offscreen render target every frame.
4. **One window.** All UI — controller panel, toasts, dialogs, thumbnails — renders in the same `QQuickWindow`
   as the video. Never introduce a second native window, or a `QQuickWidget` for video.
5. **Keep the JS engine out of the per-frame path.** Bind instead of polling, throttle `position` to seek-bar
   updates, and keep allocation and string formatting out of `onPositionChanged`.
6. **Animate only composited properties** (`opacity`, `scale`, `rotation`, `x`, `y`). Do not animate `width`,
   `height`, or anchors on anything the size of the video surface.
7. **Fullscreen is the benchmark case.** A change that is smooth in a window and stutters at fullscreen 4K60 is
   a regression.

### Baseline to record before and after any playback change

Same clip, same machine, windowed *and* fullscreen: total CPU and hottest core, GPU 3D and Video Decode
utilization, frame times (PresentMon), and which hardware decoder was actually selected.

### Diagnostics

The executable is built for the GUI subsystem (`WIN32_EXECUTABLE`), so it has no console of its own.
Set `QT_ASSUME_STDERR_HAS_CONSOLE=1` to get Qt's logging on stderr when launching from a terminal.

```powershell
$env:QSG_INFO = 1                                      # RHI backend, swapchain, GPU in use
$env:QSG_RENDER_TIMING = 1                             # per-frame scene-graph timings
$env:QT_LOGGING_RULES = "qt.multimedia.ffmpeg*=true"   # backend and HW decoder selection
$env:QT_FFMPEG_DEBUG = 1                               # FFmpeg library logs and codec dump
$env:QT_FFMPEG_DECODING_HW_DEVICE_TYPES = "d3d11va"    # force one HW backend (or "," to disable all)
$env:QT_DISABLE_HW_TEXTURES_CONVERSION = 1             # diagnostic only: isolates GPU-conversion bugs
$env:QT_MEDIA_BACKEND = "ffmpeg"                       # default on Windows; "windows" (WMF) is deprecated
```

`QT_FFMPEG_*` and `QT_DISABLE_HW_TEXTURES_CONVERSION` are private Qt API. Use them to diagnose, never to ship a
workaround baked into the app.

## Conventions

- C++20 and Qt 6 idioms: new-style `connect`, `Q_PROPERTY` with `NOTIFY` (and `BINDABLE` where it helps),
  `QStringLiteral` for literals. Parent-owned `QObject`s; `std::unique_ptr` only where there is no parent.
- QML file order: `id` first, then properties, then functions, then signal handlers, then children. No
  unqualified access to outer-scope ids from delegates; `required property` in delegates; `pragma
  ComponentBehavior: Bound` in any file with delegates. `qmllint` must be clean.
- Keep QML files under roughly 200 lines — split into components in `src/qml/` instead.
- Tests use **Qt Quick Test** under `tests/`, wired to CTest. There is no suite yet; add one alongside the first
  non-trivial component rather than retrofitting later.
- Commit messages and code comments in English. Design documents under `docs/` may be Japanese.

## Out of scope

Playlists, library management, subtitle authoring, network streaming UI, non-Windows platforms (Windows x64
only), and reviving anything from the FFME or SoundTouch stack.
