import QtQuick
import QtQuick.Controls

// Yan yana seçenekler (Hepsi / Steam / Epic gibi)
Rectangle {
    id: seg
    property var options: []
    property int current: 0
    signal picked(int index)

    implicitHeight: 38
    implicitWidth: row.implicitWidth + 8
    radius: 8
    color: theme.surface
    border.color: theme.line

    Rectangle {   // seçili olanın arkasındaki kaydırılan parça
        id: knob
        y: 4
        height: parent.height - 8
        radius: 6
        color: theme.surfaceHigh
        border.color: theme.line
        x: rep.count > seg.current ? rep.itemAt(seg.current).x + 4 : 4
        width: rep.count > seg.current ? rep.itemAt(seg.current).width : 0
        Behavior on x { enabled: appRoot.motion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: appRoot.motion; NumberAnimation { duration: 160 } }
    }
    Row {
        id: row
        x: 4; y: 4
        height: parent.height - 8
        Repeater {
            id: rep
            model: seg.options
            AbstractButton {
                id: opt
                required property string modelData
                required property int index
                height: row.height
                width: label.implicitWidth + 24
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                Accessible.name: modelData
                onClicked: seg.picked(index)
                contentItem: Text {
                    id: label
                    text: opt.modelData
                    font.family: theme.bodyFont
                    font.pixelSize: 13
                    font.weight: seg.current === opt.index ? Font.Bold : Font.Normal
                    color: seg.current === opt.index ? theme.text : (opt.hovered ? theme.text : theme.muted)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: "transparent"; radius: 6
                    border.width: opt.visualFocus ? 2 : 0; border.color: theme.accent
                }
            }
        }
    }
}
