import QtQuick
import QtQuick.Controls

MenuItem {
    id: mi
    property bool danger: false
    height: visible ? implicitHeight : 0
    implicitHeight: 34
    font.family: theme.bodyFont
    font.pixelSize: 14

    indicator: Rectangle {
        visible: mi.checkable
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 4
        color: mi.checked ? theme.accent : "transparent"
        border.color: mi.checked ? theme.accent : theme.muted
        border.width: 1.5
    }
    contentItem: Text {
        leftPadding: mi.checkable ? 30 : 8
        text: mi.text
        font: mi.font
        color: mi.danger ? theme.danger : (mi.enabled ? theme.text : theme.faint)
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: 6
        color: mi.highlighted ? theme.shelf : "transparent"
    }
}
