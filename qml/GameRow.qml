import QtQuick
import QtQuick.Layouts
import "state.js" as S

// Liste görünümünde bir satır
Item {
    id: row
    required property var game
    required property int index
    readonly property ListView view: ListView.view
    readonly property bool isCurrent: ListView.isCurrentItem && view && view.activeFocus
    width: view ? view.width : 800
    height: 76
    opacity: game.hidden ? 0.5 : 1

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: 8
        color: mouse.containsMouse || row.isCurrent ? theme.surface : "transparent"
        border.width: row.isCurrent ? 2 : 0
        border.color: theme.accent
    }
    Rectangle {
        anchors.bottom: parent.bottom
        x: 20
        width: parent.width - 40
        height: 1
        color: theme.line
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => {
            row.view.currentIndex = row.index
            if (m.button === Qt.RightButton)
                appRoot.showGameMenu(row.game, row, m.x, m.y)
        }
        onDoubleClicked: appRoot.openDetail(row.game)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 18

        CoverArt {
            Layout.preferredWidth: 120
            Layout.preferredHeight: 56
            game: row.game
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: appRoot.openDetail(row.game)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 160
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: row.game.title
                color: theme.text
                font.pixelSize: 15
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 6
                Text { text: S.platformLabel(row.game); color: theme.muted; font.pixelSize: 12 }
                Star { visible: row.game.favorite; implicitWidth: 11; implicitHeight: 11 }
            }
        }
        ColumnLayout {
            Layout.preferredWidth: 170
            spacing: 4
            Text {
                text: S.statusText(row.game)
                color: appRoot.kindColor(S.statusKind(row.game))
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Rectangle {   // küçük ilerleme çizgisi
                visible: row.game.state === "downloading" || row.game.state === "paused" || row.game.state === "steam_dl"
                Layout.preferredWidth: 150
                height: 4
                radius: 2
                color: theme.shelf
                Rectangle {
                    width: parent.width * Math.max(0, row.game.progress) / 100
                    height: parent.height
                    radius: 2
                    color: row.game.state === "paused" ? theme.muted : theme.accent
                }
            }
        }
        Text {
            Layout.preferredWidth: 150
            text: S.sizeOrPlay(row.game)
            color: theme.muted
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Text {
            Layout.preferredWidth: 100
            text: row.game.lastPlayedText
            color: theme.muted
            font.pixelSize: 13
        }
        GameActions {
            Layout.fillWidth: false
            Layout.preferredWidth: 270
            Layout.maximumWidth: 270
            game: row.game
        }
    }
}
