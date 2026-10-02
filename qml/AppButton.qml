import QtQuick
import QtQuick.Controls

// Programdaki bütün butonlar. kind: primary, secondary, ghost, danger
Button {
    id: b
    property string kind: "secondary"
    property bool compact: false

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: theme.bodyFont
    font.pixelSize: compact ? 13 : 14
    font.weight: Font.Bold
    implicitHeight: compact ? 30 : 36
    leftPadding: compact ? 10 : 16
    rightPadding: compact ? 10 : 16

    contentItem: Text {
        text: b.text
        font: b.font
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: !b.enabled ? theme.faint
             : b.kind === "primary" ? theme.onAccent
             : b.kind === "danger" ? theme.danger
             : theme.text
    }

    background: Rectangle {
        radius: 7
        color: {
            if (b.kind === "primary")
                return b.enabled ? (b.hovered || b.down ? theme.accentHover : theme.accent) : theme.shelf
            if (b.kind === "ghost")
                return b.hovered ? theme.shelf : "transparent"
            return b.hovered || b.down ? theme.shelf : theme.surfaceHigh
        }
        border.width: (b.kind === "secondary" || b.kind === "danger") ? 1 : 0
        border.color: theme.line

        Rectangle {   // klavye odağı
            anchors.fill: parent
            anchors.margins: -3
            radius: 9
            color: "transparent"
            border.width: 2
            border.color: theme.accent
            visible: b.visualFocus
        }
    }
}
