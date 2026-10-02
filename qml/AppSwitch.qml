import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ayarlar sayfasındaki aç / kapa satırı
AbstractButton {
    id: s
    property string note: ""
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: col.implicitHeight + 16
    Accessible.name: text

    background: Rectangle {
        radius: 8
        color: s.hovered ? theme.surfaceHigh : "transparent"
        border.width: s.visualFocus ? 2 : 0
        border.color: theme.accent
    }
    contentItem: RowLayout {
        spacing: 14
        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 2
            Text { Layout.fillWidth: true; text: s.text; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold; wrapMode: Text.WordWrap }
            Text { Layout.fillWidth: true; visible: s.note !== ""; text: s.note; color: theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
        }
        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 24
            radius: 12
            color: s.checked ? theme.accent : theme.shelfEdge
            Rectangle {
                width: 18; height: 18; radius: 9
                y: 3
                x: s.checked ? parent.width - width - 3 : 3
                color: s.checked ? theme.onAccent : theme.muted
                Behavior on x { enabled: appRoot.motion; NumberAnimation { duration: 140 } }
            }
        }
    }
}
