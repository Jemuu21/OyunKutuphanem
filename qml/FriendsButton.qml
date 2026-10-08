import QtQuick
import QtQuick.Controls

// Üst çubukta arkadaş listesi butonu: iki kişi simgesi ve çevrim içi sayısı
AbstractButton {
    id: b
    objectName: "friendsButton"
    readonly property bool on: backend.friendsPanel
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 22
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Arkadaşlar"
    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: on ? "Arkadaş listesini kapat" : "Arkadaş listesi"
    onClicked: {
        backend.friendsPanel = !backend.friendsPanel
        if (backend.friendsPanel) backend.checkFriends(true)
    }
    background: Rectangle {
        radius: 8
        color: b.on ? theme.surfaceHigh : (b.hovered ? theme.surfaceHigh : theme.surface)
        border.width: b.on || b.visualFocus ? 2 : 1
        border.color: b.on || b.visualFocus ? theme.accent : theme.line
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Item {   // iki kişi
                width: 22; height: 18
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { x: 11; y: 1; width: 7; height: 7; radius: 4; color: b.on ? theme.text : theme.muted }
                Rectangle { x: 8; y: 9; width: 13; height: 8; radius: 4; color: b.on ? theme.text : theme.muted }
                Rectangle { x: 3; y: 2; width: 8; height: 8; radius: 4; color: theme.text; border.color: theme.surface; border.width: 1.5 }
                Rectangle { x: 0; y: 10; width: 14; height: 8; radius: 4; color: theme.text; border.color: theme.surface; border.width: 1.5 }
            }
            Text {
                visible: backend.friendsOnline > 0
                anchors.verticalCenter: parent.verticalCenter
                text: backend.friendsOnline
                color: theme.ok
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
    }
}
