import QtQuick
import QtQuick.Controls

// Aç / kapa düğmesi gibi çalışan küçük seçenek ("Sadece kurulu")
AbstractButton {
    id: t
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 38
    implicitWidth: label.implicitWidth + 44
    Accessible.name: text

    background: Rectangle {
        radius: 8
        color: t.checked ? theme.surfaceHigh : (t.hovered ? theme.surfaceHigh : theme.surface)
        border.width: t.visualFocus ? 2 : 1
        border.color: t.visualFocus || t.checked ? theme.accent : theme.line
    }
    contentItem: Item {
        Rectangle {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 4
            color: t.checked ? theme.accent : "transparent"
            border.width: 1.5
            border.color: t.checked ? theme.accent : theme.muted
            Rectangle {   // tik işareti
                visible: t.checked
                x: 3; y: 6; width: 4; height: 2; rotation: 45; color: theme.onAccent
            }
            Rectangle {
                visible: t.checked
                x: 5; y: 5; width: 7; height: 2; rotation: -50; color: theme.onAccent
            }
        }
        Text {
            id: label
            x: 34; anchors.verticalCenter: parent.verticalCenter
            text: t.text
            font.family: theme.bodyFont
            font.pixelSize: 13
            color: theme.text
        }
    }
}
