import QtQuick
import QtQuick.Layouts

// Yatay çubuk listesi: ad solda, değer sağda, çubuk altta (tek veri dizisi, doğrudan etiketli)
ColumnLayout {
    id: hb
    property var items: []          // [{title, minutes, key?}]
    readonly property real maxValue: Math.max(1, Math.max.apply(null, items.map(i => i.minutes)))
    spacing: 10

    Repeater {
        model: hb.items
        ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    color: theme.text
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Text { text: appRoot.minutesText(row.modelData.minutes); color: theme.muted; font.pixelSize: 13 }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: theme.shelf
                Rectangle {
                    width: Math.max(6, parent.width * row.modelData.minutes / hb.maxValue)
                    height: parent.height
                    radius: 3
                    color: theme.chart
                }
            }
        }
    }
}
