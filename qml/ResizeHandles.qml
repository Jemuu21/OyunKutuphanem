import QtQuick
import QtQuick.Window

// Çerçevesiz pencerede kenarlardan ve köşelerden boyutlandırma
Item {
    id: rh
    property var win
    property int grip: 6
    anchors.fill: parent
    visible: win && win.visibility === Window.Windowed

    component Edge: MouseArea {
        property int edges
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: rh.win.startSystemResize(edges)
    }
    Edge { edges: Qt.LeftEdge; x: 0; y: rh.grip; width: rh.grip; height: rh.height - 2 * rh.grip; cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.RightEdge; x: rh.width - rh.grip; y: rh.grip; width: rh.grip; height: rh.height - 2 * rh.grip; cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.TopEdge; x: rh.grip; y: 0; width: rh.width - 2 * rh.grip; height: rh.grip; cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.BottomEdge; x: rh.grip; y: rh.height - rh.grip; width: rh.width - 2 * rh.grip; height: rh.grip; cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.TopEdge | Qt.LeftEdge; x: 0; y: 0; width: rh.grip * 2; height: rh.grip * 2; cursorShape: Qt.SizeFDiagCursor }
    Edge { edges: Qt.TopEdge | Qt.RightEdge; x: rh.width - rh.grip * 2; y: 0; width: rh.grip * 2; height: rh.grip * 2; cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.BottomEdge | Qt.LeftEdge; x: 0; y: rh.height - rh.grip * 2; width: rh.grip * 2; height: rh.grip * 2; cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.BottomEdge | Qt.RightEdge; x: rh.width - rh.grip * 2; y: rh.height - rh.grip * 2; width: rh.grip * 2; height: rh.grip * 2; cursorShape: Qt.SizeFDiagCursor }
}
