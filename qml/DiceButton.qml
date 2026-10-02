import QtQuick
import QtQuick.Controls

// "Ne oynasam?" zarı
AbstractButton {
    id: d
    implicitWidth: 38
    implicitHeight: 38
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Ne oynasam?"
    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: "Ne oynasam? (Ctrl+R)"

    background: Rectangle {
        radius: 8
        color: d.hovered || d.down ? theme.surfaceHigh : theme.surface
        border.width: d.visualFocus ? 2 : 1
        border.color: d.visualFocus ? theme.accent : theme.line
    }
    contentItem: Item {
        Rectangle {
            id: die
            anchors.centerIn: parent
            width: 18; height: 18; radius: 4
            color: "transparent"
            border.width: 2
            border.color: d.hovered ? theme.accent : theme.text
            rotation: d.hovered ? 12 : 0
            Behavior on rotation { enabled: appRoot.motion; NumberAnimation { duration: 160 } }
            Repeater {
                model: [[4, 4], [10, 10], [4, 10], [10, 4], [7, 7]]
                Rectangle {
                    required property var modelData
                    x: modelData[0] - 0.5; y: modelData[1] - 0.5
                    width: 3; height: 3; radius: 1.5
                    color: die.border.color
                }
            }
        }
    }
}
