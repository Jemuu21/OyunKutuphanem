import QtQuick
import QtQuick.Layouts
import "state.js" as S

// Rafta duran bir oyun: kapak rafın üstünde, adı ve butonları rafın etiketinde
Item {
    id: tile
    required property var game
    required property int index
    readonly property GridView view: GridView.view
    readonly property bool isCurrent: GridView.isCurrentItem && view && view.activeFocus
    readonly property int cols: view ? Math.max(1, Math.floor(view.width / view.cellWidth)) : 1

    width: view ? view.cellWidth : 262
    height: view ? view.cellHeight : 290

    Item {
        id: body
        width: tile.width
        height: tile.height
        opacity: tile.game.hidden ? 0.5 : 1
        transform: Translate { id: shift }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (m) => {
                tile.view.currentIndex = tile.index
                if (m.button === Qt.RightButton)
                    appRoot.showGameMenu(tile.game, body, m.x, m.y)
            }
            onDoubleClicked: appRoot.openDetail(tile.game)
        }

        CoverArt {
            id: cover
            x: 14
            y: 16
            width: tile.width - 28
            height: Math.round(width * 215 / 460)
            game: tile.game
            highlighted: hover.containsMouse || coverMouse.containsMouse || tile.isCurrent

            MouseArea {
                id: coverMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    tile.view.currentIndex = tile.index
                    if (m.button === Qt.RightButton)
                        appRoot.showGameMenu(tile.game, cover, m.x, m.y)
                    else
                        appRoot.openDetail(tile.game)
                }
            }
        }

        Shelf {
            y: cover.y + cover.height
            width: tile.width
        }

        Column {
            x: 14
            y: cover.y + cover.height + 26
            width: tile.width - 28
            spacing: 3

            RowLayout {
                width: parent.width
                spacing: 6
                Text {
                    text: S.platformLabel(tile.game)
                    color: theme.muted
                    font.pixelSize: 12
                }
                Star {
                    visible: tile.game.favorite
                    implicitWidth: 11
                    implicitHeight: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: S.statusText(tile.game)
                    color: appRoot.kindColor(S.statusKind(tile.game))
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
            Text {
                width: parent.width
                text: tile.game.title
                color: theme.text
                font.pixelSize: 15
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 1.05
            }
            Text {
                width: parent.width
                text: S.sizeOrPlay(tile.game)
                color: theme.muted
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        GameActions {
            x: 14
            width: tile.width - 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            game: tile.game
        }
    }

    // Açılışta raflar sırayla dolar (en fazla ~0,7 saniye)
    SequentialAnimation {
        id: intro
        PropertyAction { target: body; property: "opacity"; value: 0 }
        PropertyAction { target: shift; property: "y"; value: 12 }
        PauseAnimation {
            duration: Math.max(0, Math.min(Math.floor(tile.index / tile.cols), 5) * 80 + (tile.index % tile.cols) * 30)
        }
        ParallelAnimation {
            NumberAnimation { target: body; property: "opacity"; to: tile.game.hidden ? 0.5 : 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }
    Component.onCompleted: if (backend.introActive && appRoot.motion) intro.start()
}
