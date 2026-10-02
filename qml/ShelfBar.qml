import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Raflar: Tümü, Favoriler, kendi rafların. Bir oyunu sürükleyip bir rafa bırakınca o rafa eklenir.
Flickable {
    id: bar
    implicitHeight: 40
    contentWidth: row.implicitWidth
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentWidth > width

    component Chip: AbstractButton {
        id: chip
        property string sid: ""
        property int count: -1
        property bool custom: false
        readonly property bool selected: backend.currentShelf === sid
        readonly property bool dropOk: appRoot.dragGame !== null && sid !== ""
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        implicitHeight: 34
        implicitWidth: label.implicitWidth + 28
        onClicked: backend.currentShelf = sid
        Accessible.name: text

        background: Rectangle {
            radius: 17
            color: drop.containsDrag ? theme.accent
                 : chip.selected ? theme.surfaceHigh
                 : chip.hovered ? theme.surface : "transparent"
            border.width: chip.dropOk || chip.selected || chip.visualFocus ? (chip.dropOk && !drop.containsDrag ? 1.5 : 1) : 1
            border.color: chip.dropOk ? theme.accent : chip.selected || chip.visualFocus ? theme.accent : theme.line
        }
        contentItem: Text {
            id: label
            text: chip.text + (chip.count >= 0 ? "  " + chip.count : "")
            color: drop.containsDrag ? theme.onAccent : chip.selected ? theme.text : theme.muted
            font.family: theme.bodyFont
            font.pixelSize: 13
            font.weight: chip.selected ? Font.Bold : Font.Normal
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["game"]
            enabled: chip.sid !== ""
            onDropped: if (appRoot.dragGame) backend.addToShelf(chip.sid, appRoot.dragGame.key)
        }
        MouseArea {   // kendi raflarında sağ tık: yeniden adlandır / sil
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            enabled: chip.custom
            onClicked: (m) => { shelfMenu.sid = chip.sid; shelfMenu.name = chip.text; shelfMenu.popup(chip, m.x, m.y) }
        }
    }

    Row {
        id: row
        spacing: 8
        height: bar.height
        Chip { text: "Tümü"; sid: ""; anchors.verticalCenter: parent.verticalCenter }
        Chip { text: "★ Favoriler"; sid: "fav"; anchors.verticalCenter: parent.verticalCenter }
        Repeater {
            model: backend.shelves
            Chip {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                sid: modelData.id
                count: modelData.count
                custom: true
            }
        }
        AbstractButton {
            id: addBtn
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 34
            implicitWidth: addLabel.implicitWidth + 28
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            onClicked: nameDialog.ask("Yeni raf", "", "Oluştur", function(n) { backend.currentShelf = backend.addShelf(n, "") })
            background: Rectangle {
                radius: 17
                color: addDrop.containsDrag ? theme.accent : addBtn.hovered ? theme.surface : "transparent"
                border.width: 1
                border.color: appRoot.dragGame ? theme.accent : theme.line
            }
            contentItem: Text {
                id: addLabel
                text: appRoot.dragGame ? "+ Yeni rafa bırak" : "+ Yeni raf"
                color: addDrop.containsDrag ? theme.onAccent : theme.muted
                font.family: theme.bodyFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            DropArea {
                id: addDrop
                anchors.fill: parent
                keys: ["game"]
                onDropped: {
                    var key = appRoot.dragGame ? appRoot.dragGame.key : ""
                    if (key) nameDialog.ask("Yeni raf", "", "Oluştur", function(n) { backend.addShelf(n, key) })
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: backend.shelves.length === 0 && !appRoot.dragGame
            leftPadding: 6
            text: "İpucu: bir oyunu tutup buradaki bir rafa sürükleyebilirsin."
            color: theme.faint
            font.pixelSize: 12
        }
    }

    AppMenu {
        id: shelfMenu
        property string sid: ""
        property string name: ""
        AppMenuItem { text: "Yeniden adlandır…"; onTriggered: nameDialog.ask("Rafı yeniden adlandır", shelfMenu.name, "Kaydet", function(n) { backend.renameShelf(shelfMenu.sid, n) }) }
        AppMenuItem {
            text: "Rafı sil"
            danger: true
            onTriggered: dialog.ask("'" + shelfMenu.name + "' rafı silinsin mi?", "Sadece raf silinir, içindeki oyunlar kütüphanende kalır.",
                                    "Rafı sil", "Vazgeç", true, function() { backend.deleteShelf(shelfMenu.sid) })
        }
    }
}
