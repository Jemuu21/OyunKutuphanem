import QtQuick
import QtQuick.Controls

// Görünüm seçimi: ızgara, liste, kütüphane (çizilmiş küçük simgeler)
Rectangle {
    id: vs
    objectName: "viewSeg"
    readonly property var modes: ["grid", "list", "library"]
    readonly property var names: ["Izgara görünümü (Ctrl+1)", "Liste görünümü (Ctrl+2)", "Kütüphane görünümü (Ctrl+3)"]
    readonly property int current: Math.max(0, modes.indexOf(backend.viewMode))
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 8
    radius: 8
    color: theme.surface
    border.color: theme.line

    Row {
        id: row
        x: 4; y: 4
        spacing: 2
        Repeater {
            model: 3
            AbstractButton {
                id: b
                required property int index
                readonly property bool on: vs.current === index
                width: 38; height: 30
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: vs.names[index]
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: vs.names[index]
                onClicked: { backend.viewMode = vs.modes[index]; appRoot.focusView() }
                readonly property color ink: on ? theme.text : (hovered ? theme.text : theme.muted)
                background: Rectangle {
                    radius: 6
                    color: b.on ? theme.surfaceHigh : "transparent"
                    border.width: b.on || b.visualFocus ? 1 : 0
                    border.color: b.visualFocus ? theme.accent : theme.line
                }
                contentItem: Item {
                    // ızgara: 2x2 kare
                    Grid {
                        visible: b.index === 0
                        anchors.centerIn: parent
                        columns: 2; spacing: 3
                        Repeater { model: 4; Rectangle { width: 6; height: 6; radius: 1.5; color: b.ink } }
                    }
                    // liste: üç çizgi
                    Column {
                        visible: b.index === 1
                        anchors.centerIn: parent
                        spacing: 3
                        Repeater { model: 3; Rectangle { width: 15; height: 2.5; radius: 1; color: b.ink } }
                    }
                    // kütüphane: solda dar liste, sağda geniş alan
                    Row {
                        visible: b.index === 2
                        anchors.centerIn: parent
                        spacing: 2
                        Column { spacing: 2; Repeater { model: 3; Rectangle { width: 4; height: 3; radius: 1; color: b.ink } } }
                        Rectangle { width: 10; height: 13; radius: 2; color: "transparent"; border.width: 2; border.color: b.ink }
                    }
                }
            }
        }
    }
}
