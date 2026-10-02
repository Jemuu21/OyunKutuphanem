import QtQuick
import "state.js" as S

// Oyun kapağı. Kurulu değilken gri, indirildikçe soldan sağa renklenir.
Item {
    id: art
    property var game
    property bool highlighted: false
    readonly property bool active: !!game && (game.state === "downloading" || game.state === "steam_dl")
    readonly property bool paused: !!game && game.state === "paused"
    property real shown: S.colorFill(game)

    Behavior on shown {
        enabled: appRoot.motion
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    clip: true

    Rectangle { anchors.fill: parent; color: theme.coverEmpty }

    Text {
        anchors.fill: parent
        anchors.margins: 10
        visible: grayImg.status !== Image.Ready
        text: art.game ? art.game.title : ""
        color: theme.muted
        font.family: theme.displayFont
        font.pixelSize: Math.max(13, art.height / 7)
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Image {
        id: grayImg
        anchors.fill: parent
        source: art.game ? art.game.coverGray : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 460
        opacity: theme.dark ? 0.5 : 0.62
    }

    Item {
        id: colorPart
        width: Math.round(art.width * art.shown)
        height: art.height
        clip: true
        Image {
            width: art.width
            height: art.height
            source: art.game && art.shown > 0 ? art.game.cover : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 460
        }
    }

    // İndirmenin ucu: renkli ile gri kısmın birleştiği çizgi
    Rectangle {
        visible: (art.active || art.paused) && art.shown < 1
        x: Math.max(0, colorPart.width - 1)
        width: 2
        height: art.height
        color: art.paused ? theme.muted : theme.accent
    }

    Rectangle {   // vurgulu (fare üstünde ya da klavyeyle seçili)
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: theme.accent
        visible: art.highlighted
    }
}
