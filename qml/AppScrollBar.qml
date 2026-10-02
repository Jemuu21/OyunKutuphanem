import QtQuick
import QtQuick.Controls

ScrollBar {
    id: sb
    implicitWidth: 10
    contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: sb.pressed ? theme.muted : theme.shelfEdge
        opacity: sb.policy === ScrollBar.AlwaysOn || sb.active || sb.hovered ? 1 : 0.6
    }
}
