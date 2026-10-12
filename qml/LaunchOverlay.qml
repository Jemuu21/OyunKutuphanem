import QtQuick
import QtQuick.Controls

// "Oyna"ya basınca: oyunun büyük görseli ve logosu ekranı kısa bir an kaplar, "Başlatılıyor…" yazar,
// sonra (ayar açıksa) program simge durumuna küçülür.
Rectangle {
    id: ov
    property var game: null
    property string hero: ""
    property string logo: ""
    color: "#05080B"
    visible: opacity > 0
    opacity: 0

    function start(g) {
        game = g; hero = ""; logo = ""
        backend.heroFor(g.key)
        seq.stop()
        if (!appRoot.motion) { quick.restart(); return }
        seq.start()
    }
    Connections {
        target: backend
        function onHeroReady(key, h, l) { if (ov.game && key === ov.game.key) { ov.hero = h; ov.logo = l } }
    }
    function finish() {
        if (backend.minimizeOnPlay) appRoot.showMinimized()
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: { seq.stop(); quick.stop(); ov.opacity = 0 } }

    CoverArt {   // büyük görsel yoksa kapak
        anchors.fill: parent
        visible: heroImg.status !== Image.Ready
        game: ov.game
        opacity: 0.6
    }
    Image {
        id: heroImg
        anchors.fill: parent
        source: ov.hero
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        scale: 1.0
        NumberAnimation on scale { id: zoom; running: false; from: 1.0; to: 1.06; duration: 2600; easing.type: Easing.OutCubic }
    }
    Rectangle {   // alttan karartma
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#33000000" }
            GradientStop { position: 0.6; color: "#88000000" }
            GradientStop { position: 1.0; color: "#EE000000" }
        }
    }
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 64
        anchors.bottomMargin: 70
        spacing: 16
        Image {
            id: logoImg
            source: ov.logo
            visible: status === Image.Ready
            width: Math.min(sourceSize.width, ov.width * 0.4)
            height: Math.min(ov.height * 0.25, width * (sourceSize.height / Math.max(1, sourceSize.width)))
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
        }
        Text {
            visible: !logoImg.visible
            text: ov.game ? ov.game.title : ""
            color: "#FFFFFF"
            font.family: theme.displayFont
            font.pixelSize: 54
            font.weight: Font.Bold
            width: ov.width * 0.6
            wrapMode: Text.WordWrap
        }
        Row {
            spacing: 12
            Repeater {   // üç nokta, sırayla parlar
                model: 3
                Rectangle {
                    id: dot
                    required property int index
                    width: 10; height: 10; radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: theme.accent
                    opacity: 0.3
                    SequentialAnimation on opacity {
                        running: ov.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: dot.index * 160 }
                        NumberAnimation { to: 1; duration: 260 }
                        NumberAnimation { to: 0.3; duration: 260 }
                        PauseAnimation { duration: (2 - dot.index) * 160 }
                    }
                }
            }
            Text {
                text: "Başlatılıyor…"
                color: "#E9EDF0"
                font.pixelSize: 20
                font.weight: Font.Bold
            }
        }
    }

    SequentialAnimation {
        id: seq
        ScriptAction { script: zoom.restart() }
        NumberAnimation { target: ov; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 1900 }
        ScriptAction { script: ov.finish() }
        NumberAnimation { target: ov; property: "opacity"; to: 0; duration: 300 }
    }
    SequentialAnimation {   // animasyonlar kapalıyken: kısa ve sade
        id: quick
        PropertyAction { target: ov; property: "opacity"; value: 1 }
        PauseAnimation { duration: 1200 }
        ScriptAction { script: ov.finish() }
        PropertyAction { target: ov; property: "opacity"; value: 0 }
    }
}
