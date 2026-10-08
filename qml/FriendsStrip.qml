import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Durum çubuğunun üstünde: Steam arkadaşlarından şu an oyunda olanlar
Rectangle {
    id: fs
    implicitHeight: 44
    color: theme.bg
    Rectangle { width: parent.width; height: 1; color: theme.line }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 12
        Rectangle { width: 8; height: 8; radius: 4; color: theme.ok }
        Text { text: "Oyunda"; color: theme.muted; font.pixelSize: 12 }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: backend.friendsPlaying
            delegate: AbstractButton {
                id: chip
                required property var modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                height: 32
                width: chipRow.implicitWidth + 20
                hoverEnabled: true
                Accessible.name: modelData.name + ", " + modelData.game
                onClicked: { friendMenu.f = chip.modelData; friendMenu.popup(chip, 0, chip.height + 4) }
                ToolTip.visible: hovered
                ToolTip.delay: 400
                ToolTip.text: modelData.name + " şu an " + modelData.game + " oynuyor" + (modelData.lobby ? ". Lobisine katılabilirsin." : "")
                background: Rectangle {
                    radius: 16
                    color: chip.hovered ? theme.surfaceHigh : theme.surface
                    border.color: theme.line
                }
                contentItem: Item {
                    Row {
                        id: chipRow
                        anchors.verticalCenter: parent.verticalCenter
                        x: 4
                        spacing: 8
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: theme.shelf
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter
                            Image { anchors.fill: parent; source: chip.modelData.avatar; asynchronous: true; sourceSize.width: 48; fillMode: Image.PreserveAspectCrop }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.name
                            color: theme.text
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.game
                            color: theme.muted
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    AppMenu {
        id: friendMenu
        property var f: null
        AppMenuItem {
            text: "Oyununa katıl"
            visible: friendMenu.f && friendMenu.f.lobby !== ""
            onTriggered: backend.joinFriend(friendMenu.f.steamid)
        }
        AppMenuItem {
            text: friendMenu.f && friendMenu.f.owned ? "Oyunun sayfası" : "Oyunu Steam mağazasında aç"
            onTriggered: backend.openFriendGame(friendMenu.f.appid)
        }
        AppMenuItem {
            text: "Ortak oyunlarımız"
            onTriggered: commonGames.openFor(friendMenu.f.steamid, friendMenu.f.name)
        }
        AppMenuItem {
            text: "Steam profili"
            visible: friendMenu.f && friendMenu.f.profile !== ""
            onTriggered: backend.openLink(friendMenu.f.profile)
        }
    }
}
