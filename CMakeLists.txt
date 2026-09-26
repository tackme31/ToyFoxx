cmake_minimum_required(VERSION 3.21)

project(ToyFoxx
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Gui: QWindowKit links Qt's Core/Gui/Quick private modules.
find_package(Qt6 6.11 REQUIRED COMPONENTS Gui Quick QuickControls2 Multimedia)

qt_standard_project_setup(REQUIRES 6.11)

# QWindowKit (submodule, pinned to a release tag): removes the native caption while keeping the
# real Win32 frame behaviour -- Snap Layout flyout, DWM animations, shadow, rounded corners.
# Static, so no extra DLL has to be deployed.
set(QWINDOWKIT_BUILD_QUICK   ON  CACHE BOOL "" FORCE)
set(QWINDOWKIT_BUILD_WIDGETS OFF CACHE BOOL "" FORCE)
set(QWINDOWKIT_BUILD_STATIC  ON  CACHE BOOL "" FORCE)
set(QWINDOWKIT_INSTALL       OFF CACHE BOOL "" FORCE)
add_subdirectory(third_party/qwindowkit)

qt_add_executable(toyfoxx
    src/main.cpp
)

set_target_properties(toyfoxx PROPERTIES
    OUTPUT_NAME ToyFoxx
    # GUI subsystem: no console window. Qt logging still reaches a parent terminal
    # when QT_ASSUME_STDERR_HAS_CONSOLE=1 is set.
    WIN32_EXECUTABLE ON
)

qt_add_qml_module(toyfoxx
    URI ToyFoxx
    DEPENDENCIES
        QtMultimedia
    SOURCES
        src/app/MediaSource.cpp
        src/app/MediaSource.h
        src/app/ScreenGeometry.cpp
        src/app/ScreenGeometry.h
        src/media/PlaybackMonitor.cpp
        src/media/PlaybackMonitor.h
        src/media/ScreenshotSaver.cpp
        src/media/ScreenshotSaver.h
        src/platform/CaptionHoverTracker.cpp
        src/platform/CaptionHoverTracker.h
        src/platform/ShellIntegration.cpp
        src/platform/DisplayKeepAwake.cpp
        src/platform/DisplayKeepAwake.h
        src/platform/FramelessWindow.cpp
        src/platform/FramelessWindow.h
        src/platform/ShellIntegration.h
    QML_FILES
        src/qml/Main.qml
        src/qml/CaptionBar.qml
        src/qml/ControllerPanel.qml
        src/qml/KeyboardShortcuts.qml
        src/qml/IconButton.qml
        src/qml/SeekBar.qml
        src/qml/SeekBarPreview.qml
        src/qml/SegmentLoop.qml
        src/qml/TimeFormat.js
        src/qml/Toast.qml
        src/qml/SpeedButton.qml
        src/qml/VolumeControl.qml
        src/qml/VideoSurface.qml
        src/qml/WindowGeometry.qml
        src/qml/WindowChrome.qml
        src/qml/PlaybackDiagnostics.qml
)

target_include_directories(toyfoxx
    PRIVATE
        src/app
        src/media
        src/platform
)

target_compile_definitions(toyfoxx
    PRIVATE
        TOYFOXX_VERSION="${PROJECT_VERSION}"
)

target_link_libraries(toyfoxx
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Multimedia
        QWindowKit::Quick
        shell32
)
