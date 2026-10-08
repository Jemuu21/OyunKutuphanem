import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "state.js" as S

// Arkadaşınla ortak oyunlar: solda Steam arkadaşların, sağda ikinizde de olan oyunlar
Popup {
    id: dlg
    property var friends: []
    property string friendsError: ""
    property bool friendsLoading: false
    property string friendId: ""
    property string friendName: ""
    property var items: []
    property string error: ""
    property bool loading: false
    property bool onlyMulti: true
    readonly property var shown: onlyMulti ? items.filter(i => i.multi || !i.known) : items
    readonly property var filteredFriends: {
        var q = search.text.trim().toLocaleLowerCase(Qt.locale("tr_TR"))
        return q === "" ? friends : friends.filter(f => f.name.toLocaleLowerCase(Qt.locale("tr_TR")).indexOf(q) >= 0)
    }

    function openFor(id, name) {
        open()
        if (friends.length === 0 && !friendsLoading) loadFriends()
        if (id) pick(id, name)
    }
    function loadFriends() { friendsLoading = true; friendsError = ""; backend.loadFriendList() }
    function pick(id, name) {
        friendId = id; friendName = name; items = []; error = ""; loading = true
        backend.loadCommonGames(id, name)
    }
    function hours(m) {
        if (!m) return "hiç"
        if (m < 60) return m + " dk"
        return Math.round(m / 60) + " sa"
    }

    Connections {
        target: backend
        function onFriendListLoaded(list, err) { dlg.friends = list; dlg.friendsError = err; dlg.friendsLoading = false }
        function onCommonGamesLoaded(id, data) {
            if (id !== dlg.friendId) return
            dlg.items = data.items; dlg.error = data.error; dlg.loading = false
        }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(1060, parent ? parent.width - 60 : 1060)
    height: Math.min(720, parent ? parent.height - 60 : 720)
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }
    enter: Transition { enabled: appRoot.motion; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }

    contentItem: RowLayout {
        spacing: 0

        // ---- sol: arkadaşlar
        ColumnLayout {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            Layout.margins: 18
            spacing: 10
            Text {
                text: "Arkadaşların"
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 20
                font.weight: Font.Bold
            }
            AppField { id: search; Layout.fillWidth: true; placeholderText: "Arkadaş ara" }
            Text {
                visible: dlg.friendsLoading
                text: "Yükleniyor…"
                color: theme.muted
                font.pixelSize: 13
            }
            Text {
                visible: dlg.friendsError !== ""
                Layout.fillWidth: true
                text: dlg.friendsError
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            ListView {
                id: friendList
                objectName: "friendList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: AppScrollBar {}
                model: dlg.filteredFriends
                delegate: AbstractButton {
                    id: fr
                    required property var modelData
                    width: friendList.width
                    height: 50
                    hoverEnabled: true
                    Accessible.name: modelData.name
                    onClicked: dlg.pick(modelData.steamid, modelData.name)
                    background: Rectangle {
                        radius: 8
                        color: dlg.friendId === fr.modelData.steamid ? theme.surfaceHigh : (fr.hovered ? theme.bg : "transparent")
                        border.width: dlg.friendId === fr.modelData.steamid ? 1 : 0
                        border.color: theme.accent
                    }
                    contentItem: RowLayout {
                        spacing: 10
                        Rectangle {
                            Layout.leftMargin: 6
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 6
                            color: theme.shelf
                            clip: true
                            Image { anchors.fill: parent; source: fr.modelData.avatar; asynchronous: true; sourceSize.width: 68; fillMode: Image.PreserveAspectCrop }
                            Rectangle {   // çevrim içi noktası
                                visible: fr.modelData.online
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                width: 10; height: 10; radius: 5
                                color: fr.modelData.game !== "" ? theme.ok : theme.queued
                                border.color: theme.surface; border.width: 2
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { Layout.fillWidth: true; text: fr.modelData.name; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold; elide: Text.ElideRight }
                            Text {
                                Layout.fillWidth: true
                                text: fr.modelData.game !== "" ? fr.modelData.game + " oynuyor" : (fr.modelData.online ? "Çevrim içi" : "Çevrim dışı")
                                color: fr.modelData.game !== "" ? theme.ok : theme.muted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: theme.line }

        // ---- sağ: ortak oyunlar
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 18
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: dlg.friendId === "" ? "Ortak oyunlar"
                        : dlg.loading ? dlg.friendName + " ile ortak oyunlar"
                        : dlg.friendName + " ile " + dlg.shown.length + " ortak oyununuz var"
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                ToggleChip {
                    objectName: "onlyMultiChip"
                    text: "Sadece birlikte oynanabilenler"
                    checked: dlg.onlyMulti
                    onToggled: dlg.onlyMulti = checked
                }
                AppButton { kind: "ghost"; text: "Kapat"; onClicked: dlg.close() }
            }
            Text {
                Layout.fillWidth: true
                visible: dlg.friendId === ""
                text: "Soldan bir arkadaşını seç. İkinizin de kütüphanesinde olan oyunlar burada görünür. "
                      + "Senin Epic'teki oyunların da sayılır, arkadaşının ise sadece Steam oyunlarına bakılabilir."
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Text { visible: dlg.loading; text: "Arkadaşının kütüphanesine bakılıyor…"; color: theme.muted; font.pixelSize: 13 }
            Text {
                Layout.fillWidth: true
                visible: dlg.error !== ""
                text: dlg.error
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: dlg.friendId !== "" && !dlg.loading && dlg.error === "" && dlg.shown.length === 0
                text: dlg.items.length > 0 ? "Birlikte oynanabilen ortak oyununuz yok. Hepsini görmek için yukarıdaki seçeneği kapat."
                                           : "Ortak oyununuz yok."
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            ListView {
                id: gameList
                objectName: "commonList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: AppScrollBar {}
                model: dlg.shown
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property var g: modelData.game
                    readonly property var p: S.primary(g)
                    width: gameList.width
                    height: 72
                    radius: 8
                    color: rowMouse.containsMouse ? theme.bg : "transparent"
                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onDoubleClicked: { dlg.close(); appRoot.openDetail(row.g) } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        spacing: 14
                        CoverArt { Layout.preferredWidth: 120; Layout.preferredHeight: 56; game: row.g }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1      // kalan yeri alsın; sağdaki sütunlar her satırda aynı hizada
                            spacing: 2
                            Text { Layout.fillWidth: true; text: row.g.title; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.modes !== "" ? row.modelData.modes : "Oyun türü bilinmiyor"
                                ToolTip.visible: modesMouse.containsMouse && truncated
                                ToolTip.text: text
                                MouseArea { id: modesMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                color: row.modelData.multi ? theme.accent : theme.muted
                                font.pixelSize: 12
                                font.weight: row.modelData.multi ? Font.Bold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Sen: " + dlg.hours(row.modelData.myMinutes) + "  ·  " + dlg.friendName + ": " + dlg.hours(row.modelData.theirMinutes)
                                color: theme.faint
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        ColumnLayout {   // sende durumu
                            Layout.preferredWidth: 130
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: S.statusText(row.g)
                                color: appRoot.kindColor(S.statusKind(row.g))
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Sende: " + S.platformLabel(row.g)
                                color: theme.faint
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        AppButton {
                            Layout.preferredWidth: 104
                            kind: row.p.strong ? "primary" : "secondary"
                            text: row.p.text
                            enabled: row.p.enabled
                            onClicked: appRoot.runAction(row.g, row.p.action)
                        }
                        AppButton {
                            kind: "ghost"
                            compact: true
                            text: "Ayrıntılar"
                            onClicked: { dlg.close(); appRoot.openDetail(row.g) }
                        }
                    }
                }
            }
        }
    }
}
