import QtQuick
import "state.js" as S

// Oyun kapağı. Kurulu değilken gri, indirildikçe soldan sağa renklenir.
// tall = dikey kutu kapağı (yoksa yatay kapak ortada gösterilir, dikey kapak arka planda istenir)
Item {
    id: art
    property var game
    property bool highlighted: false
    property bool tall: false
    readonly property bool usePortrait: tall && !!game && game.portrait !== ""
    readonly property bool fitWide: tall && !usePortrait          // dikey yer, yatay görsel
    readonly property bool active: !!game && (game.state === "downloading" || game.state === "steam_dl")
    readonly property bool paused: !!game && game.state === "paused"
    property real shown: S.colorFill(game)
    readonly property string colorSrc: !game ? "" : (usePortrait ? game.portrait : game.cover)
    readonly property string graySrc: !game ? "" : (usePortrait ? game.portraitGray : game.coverGray)

    function askPortrait() { if (tall && !!game && game.portrait === "") backend.wantPortrait(game.key) }
    onTallChanged: askPortrait()
    onGameChanged: askPortrait()
    Component.onCompleted: askPortrait()

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
        font.pixelSize: Math.max(13, Math.min(art.height, art.width * 0.6) / 7)
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // dikey yerde yatay görsel: arkada soluk dolgu
    Image {
        anchors.fill: parent
        visible: art.fitWide && status === Image.Ready
        source: art.fitWide && art.game ? (art.shown > 0 ? art.game.cover : art.game.coverGray) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 200
        opacity: 0.25
    }

    Image {
        id: grayImg
        anchors.fill: parent
        source: art.graySrc
        fillMode: art.fitWide ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: art.usePortrait ? 300 : 460
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
            source: art.shown > 0 ? art.colorSrc : ""
            fillMode: art.fitWide ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: art.usePortrait ? 300 : 460
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
