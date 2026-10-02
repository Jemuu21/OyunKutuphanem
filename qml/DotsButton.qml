import QtQuick
import QtQuick.Controls

// Üç noktalı "daha fazla" butonu
AbstractButton {
    id: d
    property bool compact: true
    implicitWidth: compact ? 30 : 36
    implicitHeight: compact ? 30 : 36
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Daha fazla"

    background: Rectangle {
        radius: 7
        color: d.hovered || d.down ? theme.shelf : theme.surfaceHigh
        border.width: 1
        border.color: theme.line
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: 9
            color: "transparent"; border.width: 2; border.color: theme.accent
            visible: d.visualFocus
        }
    }
    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: 3
                Rectangle { width: 4; height: 4; radius: 2; color: theme.text }
            }
        }
    }
}
