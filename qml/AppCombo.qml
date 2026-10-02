import QtQuick
import QtQuick.Controls

ComboBox {
    id: c
    font.family: theme.bodyFont
    font.pixelSize: 13
    implicitHeight: 38
    implicitWidth: 190
    leftPadding: 12

    contentItem: Text {
        text: c.displayText
        font: c.font
        color: theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        rightPadding: 26
    }
    indicator: Item {
        x: c.width - 24; anchors.verticalCenter: c.verticalCenter
        width: 12; height: 8
        Rectangle { x: 0; y: 2; width: 7; height: 2; radius: 1; rotation: 40; color: theme.muted }
        Rectangle { x: 4.5; y: 2; width: 7; height: 2; radius: 1; rotation: -40; color: theme.muted }
    }
    background: Rectangle {
        radius: 8
        color: c.hovered ? theme.surfaceHigh : theme.surface
        border.width: c.visualFocus ? 2 : 1
        border.color: c.visualFocus ? theme.accent : theme.line
    }
    delegate: ItemDelegate {
        id: d
        required property string modelData
        required property int index
        width: c.width - 8
        x: 4
        height: 34
        highlighted: c.highlightedIndex === index
        contentItem: Text {
            text: d.modelData
            font: c.font
            color: theme.text
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { radius: 6; color: d.highlighted ? theme.shelf : "transparent" }
    }
    popup: Popup {
        y: c.height + 4
        width: c.width
        padding: 4
        implicitHeight: contentItem.implicitHeight + 8
        contentItem: ListView {
            implicitHeight: contentHeight
            model: c.popup.visible ? c.delegateModel : null
            clip: true
        }
        background: Rectangle { radius: 8; color: theme.surfaceHigh; border.color: theme.line }
    }
}
