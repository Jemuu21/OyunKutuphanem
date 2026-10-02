import QtQuick
import QtQuick.Controls

// Aydınlık / karanlık anahtarı: güneş ve ay
AbstractButton {
    id: sw
    property bool dark: theme.dark
    implicitWidth: 64
    implicitHeight: 34
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: dark ? "Aydınlık temaya geç" : "Karanlık temaya geç"
    ToolTip.visible: hovered
    ToolTip.delay: 600
    ToolTip.text: dark ? "Aydınlık temaya geç (Ctrl+T)" : "Karanlık temaya geç (Ctrl+T)"
    onClicked: backend.dark = !backend.dark

    background: Rectangle {
        radius: height / 2
        color: sw.dark ? "#2A3542" : "#F3D79B"
        border.width: sw.visualFocus ? 2 : 1
        border.color: sw.visualFocus ? theme.accent : theme.line
        Behavior on color { enabled: appRoot.motion; ColorAnimation { duration: 200 } }
    }
    contentItem: Item {
        Rectangle {
            id: knob
            width: 26; height: 26; radius: 13
            y: (sw.height - height) / 2
            x: sw.dark ? sw.width - width - 4 : 4
            color: sw.dark ? "#DCE4EC" : "#FFFFFF"
            Behavior on x { enabled: appRoot.motion; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // güneş: turuncu daire ve ışınlar
            Item {
                anchors.fill: parent
                visible: !sw.dark
                Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: "#E39A19" }
                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        x: 13 - 1 + Math.cos(index * Math.PI / 4) * 8
                        y: 13 - 1 + Math.sin(index * Math.PI / 4) * 8
                        width: 2; height: 2; radius: 1; color: "#E39A19"
                    }
                }
            }
            // ay: hilal
            Item {
                anchors.fill: parent
                visible: sw.dark
                Rectangle { x: 7; y: 6; width: 13; height: 13; radius: 7; color: "#5F7385" }
                Rectangle { x: 11; y: 4; width: 12; height: 12; radius: 6; color: knob.color }
            }
        }
    }
}
