cmake_minimum_required(VERSION 3.21)

project(ToyFoxx
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.11 REQUIRED COMPONENTS Quick QuickControls2 Multimedia)

qt_standard_project_setup(REQUIRES 6.11)

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
        src/media/PlaybackMonitor.cpp
        src/media/PlaybackMonitor.h
        src/media/ScreenshotSaver.cpp
        src/media/ScreenshotSaver.h
        src/platform/ShellIntegration.cpp
        src/platform/ShellIntegration.h
    QML_FILES
        src/qml/Main.qml
        src/qml/ControllerPanel.qml
        src/qml/KeyboardShortcuts.qml
        src/qml/SeekBar.qml
        src/qml/SegmentLoop.qml
        src/qml/Toast.qml
        src/qml/SpeedButton.qml
        src/qml/VolumeControl.qml
        src/qml/VideoSurface.qml
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
)
