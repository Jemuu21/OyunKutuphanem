import QtQuick
import QtQuick.Layouts
import "state.js" as S

// Kütüphane görünümünde soldaki listede bir oyun
Item {
    id: row
    required property var game
    required property int index
    readonly property ListView view: ListView.view
    readonly property bool selected: !!view && view.currentIndex === index
    readonly property bool installed: game.state !== "not_installed"
    readonly property bool moving: game.state === "downloading" || game.state === "paused" || game.state === "steam_dl"
    width: view ? view.width : 300
    height: 36
    opacity: appRoot.dragGame === game ? 0.35 : (game.hidden ? 0.5 : 1)

    Rectangle {   // seçili satır
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        radius: 6
        color: row.selected || mouse.containsMouse ? theme.surfaceHigh : "transparent"
        opacity: row.selected ? 1 : 0.6
        border.width: row.selected && row.view.activeFocus ? 1 : 0
        border.color: theme.accent
        Rectangle {
            visible: row.selected
            x: 0; width: 3; height: parent.height - 12; radius: 1.5
            anchors.verticalCenter: parent.verticalCenter
            color: theme.accent
        }
    }

    DragHandler {
        target: null
        dragThreshold: 14
        onActiveChanged: active ? appRoot.startDrag(row.game, centroid.scenePosition) : appRoot.endDrag()
        onCentroidChanged: if (active) appRoot.moveDrag(centroid.scenePosition)
    }
    DropArea {
        id: reorder
        anchors.fill: parent
        keys: ["game"]
        enabled: backend.currentShelfIsCustom && backend.sortMode === 4
        onDropped: if (appRoot.dragGame && appRoot.dragGame !== row.game)
                       backend.moveInShelf(backend.currentShelf, appRoot.dragGame.key, row.game.key)
    }
    Rectangle {
        visible: reorder.containsDrag && appRoot.dragGame !== row.game
        x: 10; width: parent.width - 20; height: 2; radius: 1
        color: theme.accent
        z: 5
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => {
            row.view.currentIndex = row.index
            row.view.forceActiveFocus()
            if (m.button === Qt.RightButton)
                appRoot.showGameMenu(row.game, row, m.x, m.y)
        }
        onDoubleClicked: appRoot.enterOn(row.game)     // kuruluysa oyna
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 10

        CoverArt {   // küçük kapak; indirilirken soldan sağa renklenir
            Layout.preferredWidth: 46
            Layout.preferredHeight: 22
            game: row.game
            Rectangle { anchors.fill: parent; color: "transparent"; border.color: theme.line; border.width: 1 }
        }
        Text {
            Layout.fillWidth: true
            text: row.game.title
            color: row.installed || row.selected ? theme.text : theme.muted
            font.pixelSize: 13
            font.weight: row.installed ? Font.Bold : Font.Normal
            elide: Text.ElideRight
        }
        Star { visible: S.isFav(row.game); implicitWidth: 10; implicitHeight: 10 }
        Text {   // sadece bir şey oluyorsa kısa durum
            visible: text !== ""
            text: row.moving ? (row.game.progress >= 0 ? "%" + Math.floor(row.game.progress) : "…")
                : row.game.state === "queued" ? "sırada"
                : row.game.state === "playing" ? "oyunda"
                : (row.game.state === "installed" && row.game.update && row.game.platform === "epic") ? "güncelle"
                : ""
            color: row.game.state === "playing" ? theme.ok
                 : row.game.state === "paused" ? theme.muted
                 : row.game.state === "queued" ? theme.queued : theme.accent
            font.pixelSize: 11
            font.weight: Font.Bold
        }
    }
    Rectangle {   // altta ince ilerleme çizgisi
        visible: row.moving
        x: 16; y: parent.height - 4
        width: parent.width - 32; height: 2; radius: 1
        color: theme.shelf
        Rectangle {
            width: parent.width * Math.max(0, row.game.progress) / 100
            height: parent.height; radius: 1
            color: row.game.state === "paused" ? theme.muted : theme.accent
        }
    }
}
