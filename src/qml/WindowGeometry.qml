import QtCore
import QtQuick

// Persists the window's normal geometry whenever it changes (last write wins across instances)
// and restores it, fitted to the current screens, before the window is first shown.
QtObject {
    id: keeper

    required property Window window
    property bool restored: false

    // Plain integers rather than a rect, which QSettings would store as an opaque @Variant blob
    // in the INI file.
    property Settings settings: Settings {
        id: store

        property int x
        property int y
        property int width
        property int height

        category: "Window"
    }

    // Deferred so the check sees the settled state: maximizing can report the new geometry
    // before the visibility change. Only the windowed geometry is kept, like ToyBoxx's
    // RestoreBounds.
    property Timer saveTimer: Timer {
        interval: 300
        onTriggered: {
            const w = keeper.window;
            if (w.visibility !== Window.Windowed)
                return;
            store.x = w.x;
            store.y = w.y;
            store.width = w.width;
            store.height = w.height;
        }
    }

    property Connections windowWatcher: Connections {
        target: keeper.window

        function onXChanged() {
            keeper.scheduleSave();
        }

        function onYChanged() {
            keeper.scheduleSave();
        }

        function onWidthChanged() {
            keeper.scheduleSave();
        }

        function onHeightChanged() {
            keeper.scheduleSave();
        }
    }

    function restore() {
        if (store.width > 0 && store.height > 0) {
            const fitted = ScreenGeometry.fitToAvailableScreens(Qt.rect(store.x, store.y, store.width, store.height));
            window.x = fitted.x;
            window.y = fitted.y;
            window.width = fitted.width;
            window.height = fitted.height;
        }
        restored = true;
    }

    function scheduleSave() {
        if (restored)
            saveTimer.restart();
    }
}
