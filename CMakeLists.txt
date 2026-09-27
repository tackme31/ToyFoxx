cmake_minimum_required(VERSION 3.21)

project(ToyFoxx
    VERSION 0.1.0
    LANGUAGES CXX
)

# The distribution is a zip you unpack and double-click: the exe, the DLLs and the notices all at
# its root. The Qt deploy script reads this through QT_DEPLOY_BIN_DIR, so it flattens Qt's half
# too. Must precede qt_standard_project_setup(), whose GNUInstallDirs only fills in defaults, and
# must not be a cache variable, which an earlier configure's "bin" would beat.
if(WIN32)
    set(CMAKE_INSTALL_BINDIR ".")
endif()

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

include(cmake/FFmpeg.cmake)

# The .rc embeds resources/icons/toyfoxx.ico as IDI_ICON1, which Qt also uses as the window and
# taskbar icon. The .ico is rendered from resources/icons/toyfoxx.svg; regenerate it when the SVG changes.
qt_add_executable(toyfoxx
    src/main.cpp
    resources/toyfoxx.rc
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
        src/app/FileNames.cpp
        src/app/FileNames.h
        src/app/MediaSource.cpp
        src/app/MediaSource.h
        src/app/ScreenGeometry.cpp
        src/app/ScreenGeometry.h
        src/media/PlaybackMonitor.cpp
        src/media/PlaybackMonitor.h
        src/media/ScreenshotSaver.cpp
        src/media/ScreenshotSaver.h
        src/media/SegmentExporter.cpp
        src/media/SegmentExporter.h
        src/media/SegmentTranscoder.cpp
        src/media/SegmentTranscoder.h
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
        src/qml/SegmentExport.qml
        src/qml/ExportProgress.qml
        src/qml/TimeFormat.js
        src/qml/Toast.qml
        src/qml/SpeedButton.qml
        src/qml/VolumeControl.qml
        src/qml/VideoSurface.qml
        src/qml/WindowGeometry.qml
        src/qml/WindowChrome.qml
        src/qml/PlaybackDiagnostics.qml
    RESOURCES
        resources/icons/toyfoxx.svg
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
        toyfoxx_ffmpeg
        shell32
)

# ---------------------------------------------------------------- package
# scripts/package.ps1 drives this; a plain `cmake --build` runs none of it.
install(TARGETS toyfoxx
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES LICENSE THIRD-PARTY-NOTICES.txt DESTINATION ${CMAKE_INSTALL_BINDIR})

# qmltooling holds the QML debugger plugins, which a release has no use for; one of them pulls in
# Qt6Quick3DUtils.dll, which is GPLv3-only and would not fit an MIT distribution under the LGPL.
# Of the image formats only SVG is read (the caption icon; screenshots are PNG, built into QtGui).
# Loading the first image loads every deployed format plugin, and qpdf drags in Qt6Pdf.dll.
qt_generate_deploy_qml_app_script(
    TARGET toyfoxx
    OUTPUT_SCRIPT TOYFOXX_DEPLOY_SCRIPT
    NO_TRANSLATIONS
    NO_COMPILER_RUNTIME
    EXCLUDE_PLUGIN_TYPES qmltooling
    EXCLUDE_PLUGINS qgif qicns qico qjpeg qpdf qtga qtiff qwbmp qwebp)
install(SCRIPT ${TOYFOXX_DEPLOY_SCRIPT})

# windeployqt finds the MSVC redistributable only through %VCINSTALLDIR%, which an ordinary shell
# does not set, and would then ship none; this module uses the toolchain CMake configured with.
set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ${CMAKE_INSTALL_BINDIR})
include(InstallRequiredSystemLibraries)

# CPack captures its variables at include() time, so this stays last.
set(CPACK_GENERATOR ZIP)
set(CPACK_PACKAGE_NAME ToyFoxx)
set(CPACK_PACKAGE_VENDOR "Takumi Yamada")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A tiny media player")
set(CPACK_PACKAGE_FILE_NAME "ToyFoxx-${PROJECT_VERSION}-win64")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/package")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(CPACK_VERBATIM_VARIABLES ON)
include(CPack)
