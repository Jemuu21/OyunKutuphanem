import QtQuick
import QtQuick.Controls

// Tek veri dizili dikey çubuk grafik. Üzerine gelince değer görünür.
// items: [{label, value, tip}]  — value: dakika
Item {
    id: bc
    property var items: []
    property real maxValue: Math.max(1, Math.max.apply(null, items.map(i => i.value)))
    property int hovered: -1
    implicitHeight: 190

    readonly property real plotTop: 18
    readonly property real plotBottom: height - 24
    readonly property real slot: items.length ? width / items.length : width

    // yatay ızgara: sadece taban ve tepe, çekingen
    Rectangle { y: bc.plotBottom; width: parent.width; height: 1; color: theme.line }
    Rectangle { y: bc.plotTop; width: parent.width; height: 1; color: theme.line; opacity: 0.5 }
    Text {
        y: 0
        anchors.right: parent.right
        text: appRoot.minutesText(bc.maxValue)
        color: theme.faint
        font.pixelSize: 11
    }

    Repeater {
        model: bc.items
        Item {
            id: cell
            required property var modelData
            required property int index
            x: index * bc.slot
            width: bc.slot
            height: bc.height
            readonly property real h: Math.max(modelData.value > 0 ? 3 : 0, (bc.plotBottom - bc.plotTop) * modelData.value / bc.maxValue)

            Rectangle {   // çubuk: ince, uçta 4px yuvarlak, tabana oturur
                anchors.horizontalCenter: parent.horizontalCenter
                y: bc.plotBottom - cell.h
                width: Math.min(28, bc.slot - 6)
                height: cell.h
                radius: Math.min(4, height / 2)
                color: theme.chart
                opacity: bc.hovered === -1 || bc.hovered === cell.index ? 1 : 0.55
                Rectangle {   // alt köşeler düz kalsın
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.min(4, parent.height)
                    color: parent.color
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: bc.plotBottom + 6
                text: cell.modelData.label
                color: bc.hovered === cell.index ? theme.text : theme.muted
                font.pixelSize: 11
            }
            MouseArea {   // dokunma alanı çubuktan büyük
                anchors.fill: parent
                hoverEnabled: true
                onEntered: bc.hovered = cell.index
                onExited: if (bc.hovered === cell.index) bc.hovered = -1
            }
        }
    }

    Rectangle {   // ipucu
        id: tip
        visible: bc.hovered >= 0
        readonly property var it: bc.hovered >= 0 ? bc.items[bc.hovered] : null
        width: Math.min(260, tipText.implicitWidth + 20)
        height: tipText.implicitHeight + 14
        radius: 8
        color: theme.surfaceHigh
        border.color: theme.line
        x: Math.max(0, Math.min(bc.width - width, bc.hovered * bc.slot + bc.slot / 2 - width / 2))
        y: Math.max(0, bc.plotTop - 6)
        Text {
            id: tipText
            anchors.centerIn: parent
            width: Math.min(240, implicitWidth)
            text: tip.it ? tip.it.tip : ""
            color: theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
