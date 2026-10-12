import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Epic indirmesinin canlı hız grafiği: son ~1,5 dakikanın hızı (MB/s), şu anki hız, en yüksek, kalan süre
Rectangle {
    id: sc
    property var game: null
    readonly property var samples: game ? game.speedSamples : []
    readonly property real peak: samples.length ? Math.max.apply(null, samples) : 0
    readonly property real current: samples.length ? samples[samples.length - 1] : 0
    readonly property real scaleMax: Math.max(1, peak * 1.1)
    // çubuklar en az 5 px olsun: sığdığı kadar son ölçüm gösterilir
    readonly property int slots: Math.max(10, Math.floor(plot.width / 6))
    readonly property var shownSamples: samples.slice(-slots)
    function mb(v) { return v.toFixed(1).replace(".", ",") + " MB/s" }

    implicitHeight: 150
    radius: 10
    color: theme.surface
    border.color: theme.line

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 22

        ColumnLayout {   // sayılar
            Layout.preferredWidth: 150
            Layout.alignment: Qt.AlignTop
            spacing: 2
            Text { text: "İNDİRME HIZI"; color: theme.faint; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1 }
            Text {
                text: sc.game && sc.game.state === "paused" ? "Durduruldu" : sc.mb(sc.current)
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 24
                font.weight: Font.Bold
            }
            Text { Layout.topMargin: 6; text: "En yüksek: " + sc.mb(sc.peak); color: theme.muted; font.pixelSize: 12 }
            Text {
                visible: !!sc.game && sc.game.info.indexOf("kalan") === 0
                text: sc.game ? sc.game.info.split(",")[0].replace("kalan", "Kalan süre:") : ""
                color: theme.muted
                font.pixelSize: 12
            }
            Text {
                visible: !!sc.game && sc.game.downloadSize !== "" && sc.game.progress >= 0
                text: sc.game ? "İnen: %" + Math.floor(sc.game.progress) + " / " + sc.game.downloadSize : ""
                color: theme.muted
                font.pixelSize: 12
            }
        }

        Item {   // çubuklar: en yeni sağda, eksen çizgisi altta
            id: plot
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real slotW: width / sc.slots
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.line }
            Rectangle {   // en yüksek hız çizgisi
                visible: sc.peak > 0
                width: parent.width; height: 1
                y: parent.height - parent.height * sc.peak / sc.scaleMax
                color: theme.line
                opacity: 0.8
            }
            Repeater {
                model: sc.shownSamples
                Item {
                    id: bar
                    required property real modelData
                    required property int index
                    readonly property real h: Math.max(2, (plot.height - 1) * modelData / sc.scaleMax)
                    x: plot.width - (sc.shownSamples.length - index) * plot.slotW
                    width: plot.slotW
                    height: plot.height - 1
                    Rectangle {   // çubuk: üstü yuvarlak, altı düz; aralarında 2 px boşluk
                        x: 1
                        width: Math.max(1, bar.width - 2)
                        height: bar.h
                        anchors.bottom: parent.bottom
                        radius: Math.min(4, width / 2)
                        color: theme.chart
                        opacity: barMouse.containsMouse ? 1 : 0.85
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Math.min(parent.height, parent.radius); color: parent.color }
                    }
                    MouseArea {
                        id: barMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        ToolTip.visible: containsMouse
                        ToolTip.delay: 0
                        ToolTip.text: sc.mb(bar.modelData)
                    }
                }
            }
            Text {
                visible: sc.samples.length === 0
                anchors.centerIn: parent
                text: "Hız ölçülüyor…"
                color: theme.faint
                font.pixelSize: 12
            }
        }
    }
}
