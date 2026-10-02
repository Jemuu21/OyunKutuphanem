import QtQuick
import QtQuick.Controls

AppField {
    id: s
    placeholderText: "Rafta ara  (Ctrl+F)"
    leftPadding: 36
    rightPadding: clear.visible ? 34 : 12

    // Qt iç içe türetilmiş metin kutularında arka planı kaybediyor, burada yeniden veriyoruz
    background: Rectangle {
        radius: 7
        color: theme.surfaceHigh
        border.width: s.activeFocus ? 2 : 1
        border.color: s.activeFocus ? theme.accent : theme.line
    }

    // büyüteç
    Item {
        x: 12; anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16
        Rectangle { width: 11; height: 11; radius: 6; color: "transparent"; border.width: 2; border.color: theme.muted }
        Rectangle { x: 9; y: 10; width: 6; height: 2; radius: 1; rotation: 45; color: theme.muted }
    }
    AbstractButton {
        id: clear
        visible: s.text.length > 0
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24
        Accessible.name: "Aramayı temizle"
        onClicked: { s.text = ""; s.forceActiveFocus() }
        background: Rectangle { radius: 12; color: clear.hovered ? theme.shelf : "transparent" }
        contentItem: Item {
            Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; rotation: 45; color: theme.muted }
            Rectangle { anchors.centerIn: parent; width: 12; height: 2; radius: 1; rotation: -45; color: theme.muted }
        }
    }
}
