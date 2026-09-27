import QtQuick
import QtMultimedia

// Exporting the A-B segment to the Videos folder (T), with its outcome announced in the toast.
Item {
    id: segmentExport

    required property MediaPlayer player
    required property SegmentLoop segmentLoop
    required property Toast toast
    readonly property alias exporter: exporter

    function start() {
        if (exporter.busy)
            return;
        if (!segmentLoop.active) {
            toast.show(qsTr("No A-B segment to export"), qsTr("Set both ends of an A-B loop, then press T."), null);
            return;
        }
        exporter.start(player.source, segmentLoop.startMs, segmentLoop.endMs, MediaSource.displayTitle(player.source));
    }

    SegmentExporter {
        id: exporter

        onFinished: filePath => segmentExport.toast.show(qsTr("Segment exported"), filePath, () => ShellIntegration.revealInExplorer(filePath))
        onFailed: message => segmentExport.toast.show(qsTr("Export failed"), message, null)
        onCanceled: segmentExport.toast.show(qsTr("Export canceled"), "", null)
    }
}
