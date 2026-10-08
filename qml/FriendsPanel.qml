import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sağda açılıp kapanan Steam arkadaş listesi: oyunda olanlar, çevrim içi olanlar, çevrim dışı olanlar
Rectangle {
    id: panel
    color: theme.surface
    property bool showOffline: false
    readonly property string q: search.text.trim().toLocaleLowerCase(Qt.locale("tr_TR"))
    function pick(group) {
        return backend.friendsAll.filter(f => f.group === group
                                         && (panel.q === "" || f.name.toLocaleLowerCase(Qt.locale("tr_TR")).indexOf(panel.q) >= 0))
    }
    readonly property var playing: pick("game")
    readonly property var online: pick("online")
    readonly property var offline: pick("offline")

    Rectangle { width: 1; height: parent.height; color: theme.line }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        anchors.topMargin: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Arkadaşlar"
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            Text {
                visible: backend.friendsAll.length > 0
                text: backend.friendsOnline + " çevrim içi"
                color: theme.ok
                font.pixelSize: 12
                font.weight: Font.Bold
            }
            AppButton { kind: "ghost"; compact: true; text: "✕"; onClicked: backend.friendsPanel = false; Accessible.name: "Arkadaş listesini kapat" }
        }
        AppField { id: search; Layout.fillWidth: true; placeholderText: "Arkadaş ara" }

        Text {
            Layout.fillWidth: true
            visible: backend.friendsError !== ""
            text: backend.friendsError
            color: theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        AppButton {
            visible: backend.friendsError !== "" && !backend.steamLoggedIn
            kind: "primary"
            text: "Steam ile giriş yap"
            onClicked: backend.loginSteam()
        }
        Text {
            visible: backend.friendsError === "" && backend.friendsAll.length === 0
            text: "Yükleniyor…"
            color: theme.muted
            font.pixelSize: 13
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: col.implicitHeight + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar {}

            Column {
                id: col
                width: flick.width - 8
                spacing: 2

                component Header: Text {
                    topPadding: 10
                    bottomPadding: 4
                    leftPadding: 4
                    color: theme.faint
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.1
                }

                component FriendRow: AbstractButton {
                    id: fr
                    required property var modelData
                    readonly property var f: modelData
                    width: col.width
                    height: 48
                    hoverEnabled: true
                    Accessible.name: f.name + ", " + f.status
                    onClicked: { friendMenu.f = fr.f; friendMenu.popup(fr, 0, fr.height) }
                    onDoubleClicked: backend.messageFriend(fr.f.steamid)
                    background: Rectangle { radius: 8; color: fr.hovered || friendMenu.f === fr.f && friendMenu.visible ? theme.surfaceHigh : "transparent" }
                    contentItem: RowLayout {
                        spacing: 10
                        Item {
                            Layout.leftMargin: 4
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: theme.shelf
                                clip: true
                                opacity: fr.f.online ? 1 : 0.5
                                Image { anchors.fill: parent; source: fr.f.avatar; asynchronous: true; sourceSize.width: 68; fillMode: Image.PreserveAspectCrop }
                            }
                            Rectangle {   // durum noktası
                                visible: fr.f.online
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                anchors.rightMargin: -2; anchors.bottomMargin: -2
                                width: 11; height: 11; radius: 6
                                color: fr.f.game !== "" ? theme.ok : (fr.f.state === 3 || fr.f.state === 4 ? theme.accent : theme.queued)
                                border.color: theme.surface; border.width: 2
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: fr.f.name
                                color: fr.f.online ? theme.text : theme.muted
                                font.pixelSize: 14
                                font.weight: fr.f.online ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: fr.f.status
                                color: fr.f.game !== "" ? theme.ok : theme.faint
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        AppButton {
                            visible: fr.f.lobby !== ""
                            compact: true
                            kind: "primary"
                            text: "Katıl"
                            onClicked: backend.joinFriend(fr.f.steamid)
                        }
                    }
                }

                Header { visible: panel.playing.length > 0; text: "OYUNDA (" + panel.playing.length + ")" }
                Repeater { model: panel.playing; FriendRow {} }
                Header { visible: panel.online.length > 0; text: "ÇEVRİM İÇİ (" + panel.online.length + ")" }
                Repeater { model: panel.online; FriendRow {} }
                AbstractButton {   // çevrim dışı olanlar varsayılan olarak kapalı
                    visible: panel.offline.length > 0
                    width: col.width
                    height: 34
                    hoverEnabled: true
                    onClicked: panel.showOffline = !panel.showOffline
                    background: Item {}
                    contentItem: Text {
                        leftPadding: 4
                        verticalAlignment: Text.AlignVCenter
                        text: "ÇEVRİM DIŞI (" + panel.offline.length + ")  " + (panel.showOffline || panel.q !== "" ? "▴" : "▾")
                        color: parent.hovered ? theme.muted : theme.faint
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.1
                    }
                }
                Repeater { model: panel.showOffline || panel.q !== "" ? panel.offline : []; FriendRow {} }
            }
        }
    }

    AppMenu {
        id: friendMenu
        property var f: null
        AppMenuItem { text: "Mesaj at"; onTriggered: backend.messageFriend(friendMenu.f.steamid) }
        AppMenuItem {
            text: "Oyununa katıl"
            visible: !!friendMenu.f && friendMenu.f.lobby !== ""
            onTriggered: backend.joinFriend(friendMenu.f.steamid)
        }
        AppMenuItem {
            text: !!friendMenu.f && friendMenu.f.owned ? friendMenu.f.game + " sayfası" : "Oynadığı oyun (mağazada)"
            visible: !!friendMenu.f && friendMenu.f.appid !== ""
            onTriggered: backend.openFriendGame(friendMenu.f.appid)
        }
        AppMenuItem { text: "Ortak oyunlarımız"; onTriggered: commonGames.openFor(friendMenu.f.steamid, friendMenu.f.name) }
        AppMenuItem {
            text: "Steam profili"
            visible: !!friendMenu.f && friendMenu.f.profile !== ""
            onTriggered: backend.openLink(friendMenu.f.profile)
        }
    }
}
