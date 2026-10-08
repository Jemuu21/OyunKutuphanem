import QtQuick
import QtQuick.Controls
import "state.js" as S

// Favori yıldızı butonu: doluysa favoride
AbstractButton {
    id: fav
    property var game: null
    property bool compact: false
    readonly property bool on: S.isFav(game)
    implicitWidth: compact ? 30 : 36
    implicitHeight: compact ? 30 : 36
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: on ? "Favorilerden çıkar" : "Favorilere ekle"
    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: Accessible.name
    onClicked: if (game) backend.toggleFavorite(game.key)
    background: Rectangle {
        radius: 7
        color: fav.hovered || fav.down ? theme.shelf : theme.surfaceHigh
        border.width: fav.visualFocus ? 2 : 1
        border.color: fav.visualFocus ? theme.accent : theme.line
    }
    contentItem: Item {
        Star {
            anchors.centerIn: parent
            width: 16; height: 16
            color: fav.on ? theme.accent : (fav.hovered ? theme.muted : theme.faint)
        }
    }
}
