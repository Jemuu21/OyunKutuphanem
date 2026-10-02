import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "state.js" as S

// Gökyüzü modu: her oyun bir yıldız. Tam ekran, isteğe bağlı.
Rectangle {
    id: sky
    property real zoom: 1.0
    property real panX: 0
    property real panY: 0
    property var hoverGame: null
    signal closeRequested()

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#070B16" }
        GradientStop { position: 1.0; color: "#121C33" }
    }

    onVisibleChanged: if (visible) { zoom = 1; panX = 0; panY = 0; hoverGame = null }

    // uzak toz: sabit küçük noktalar
    Repeater {
        model: 140
        Rectangle {
            required property int index
            readonly property real r1: ((index * 9301 + 49297) % 233280) / 233280
            readonly property real r2: ((index * 4271 + 1013) % 104729) / 104729
            x: r1 * sky.width
            y: r2 * sky.height
            width: index % 7 === 0 ? 2 : 1
            height: width
            color: "#9FB3D9"
            opacity: 0.15 + (index % 5) * 0.06
        }
    }

    // sürükleyerek gez, tekerlekle yaklaş
    MouseArea {
        id: drag
        anchors.fill: parent
        property real lx: 0
        property real ly: 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (m) => { lx = m.x; ly = m.y }
        onPositionChanged: (m) => {
            if (!pressed) return
            sky.panX += m.x - lx; sky.panY += m.y - ly
            lx = m.x; ly = m.y
        }
        onWheel: (w) => {
            var f = w.angleDelta.y > 0 ? 1.15 : 1 / 1.15
            sky.zoom = Math.max(0.6, Math.min(4, sky.zoom * f))
        }
    }

    Item {
        id: field
        x: sky.width / 2 + sky.panX
        y: sky.height / 2 + sky.panY
        readonly property real radius: Math.min(sky.width, sky.height) * 0.44 * sky.zoom

        Repeater {
            model: sky.visible ? backend.allGames : []
            Item {
                id: star
                required property var modelData
                readonly property var g: modelData
                readonly property bool installed: g.state !== "not_installed"
                readonly property real size: g.skySize * Math.sqrt(sky.zoom)
                visible: !g.hidden
                x: g.skyX * field.radius - width / 2
                y: g.skyY * field.radius - height / 2
                width: Math.max(18, size * 3)
                height: width

                Repeater {   // yumuşak ışık: iç içe saydam halkalar
                    model: star.installed ? 3 : 0
                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: star.size * (1.6 + index * 0.9)
                        height: width
                        radius: width / 2
                        color: "#FFD58A"
                        opacity: (0.16 - index * 0.045) * star.g.skyGlow
                    }
                }
                Rectangle {   // yıldızın kendisi
                    id: dot
                    anchors.centerIn: parent
                    width: star.size
                    height: width
                    radius: width / 2
                    color: star.installed ? (star.g.favorite ? "#FFC266" : "#FFF1D6") : "transparent"
                    border.width: star.installed ? 0 : 1.2
                    border.color: "#C9D6EE"
                    opacity: Math.max(0.25, star.g.skyGlow)

                    SequentialAnimation on opacity {   // hafif parıldama
                        running: appRoot.motion && sky.visible && star.installed
                        loops: Animation.Infinite
                        PauseAnimation { duration: 800 + (star.g.title.length * 397) % 4000 }
                        NumberAnimation { to: Math.max(0.2, star.g.skyGlow * 0.6); duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: Math.max(0.25, star.g.skyGlow); duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {   // fare üstündeyken halka
                    anchors.centerIn: parent
                    width: star.size + 10
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: "#FFD58A"
                    visible: starMouse.containsMouse
                }
                MouseArea {
                    id: starMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: sky.hoverGame = star.g
                    onExited: if (sky.hoverGame === star.g) sky.hoverGame = null
                    onClicked: appRoot.openDetail(star.g)
                }
                Text {   // adı
                    visible: starMouse.containsMouse || star.size >= 14 || (sky.zoom >= 1.8 && star.size > 9)
                    anchors.left: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: -star.width / 2 + star.size / 2 + 8
                    text: star.g.title
                    color: "#E6ECF7"
                    font.pixelSize: 13
                    style: Text.Outline
                    styleColor: "#070B16"
                }
            }
        }
    }

    // başlık ve açıklama
    ColumnLayout {
        x: 36; y: 30
        width: Math.min(460, sky.width - 72)
        spacing: 8
        Text { text: "Gökyüzü"; color: "#F2F5FA"; font.family: theme.displayFont; font.pixelSize: 34; font.weight: Font.Bold }
        Text {
            Layout.fillWidth: true
            text: "Her yıldız bir oyunun. En çok oynadıkların ortada ve büyük, yakın zamanda oynadıkların daha parlak. İçi boş yıldızlar kurulu değil."
            color: "#A9B6CC"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }
        Text {
            text: "Sürükleyerek gez, tekerlekle yaklaş, yıldıza tıklayınca oyunu aç."
            color: "#7F8CA3"
            font.pixelSize: 12
        }
    }

    // fare üstündeki oyunun bilgisi
    Rectangle {
        visible: sky.hoverGame !== null
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 36
        width: info.implicitWidth + 32
        height: info.implicitHeight + 24
        radius: 10
        color: "#CC0E1528"
        border.color: "#2A3A5C"
        ColumnLayout {
            id: info
            anchors.centerIn: parent
            spacing: 2
            Text { text: sky.hoverGame ? sky.hoverGame.title : ""; color: "#F2F5FA"; font.pixelSize: 16; font.weight: Font.Bold }
            Text {
                text: sky.hoverGame ? [S.platformLabel(sky.hoverGame),
                                       sky.hoverGame.playtimeText || "hiç oynanmadı",
                                       sky.hoverGame.lastPlayedText ? "son: " + sky.hoverGame.lastPlayedText : ""].filter(Boolean).join(", ") : ""
                color: "#A9B6CC"
                font.pixelSize: 13
            }
        }
    }

    Button {
        id: exit
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 28
        text: "Gökyüzünden çık  (Esc)"
        font.family: theme.bodyFont
        font.pixelSize: 14
        font.weight: Font.Bold
        hoverEnabled: true
        onClicked: sky.closeRequested()
        contentItem: Text { text: exit.text; font: exit.font; color: "#F2F5FA"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { implicitHeight: 38; radius: 8; color: exit.hovered ? "#24345A" : "#16213B"; border.color: "#2A3A5C" }
    }
}
