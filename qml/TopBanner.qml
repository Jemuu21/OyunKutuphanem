import QtQuick
import QtQuick.Layouts

// Rafın üstünde duran ince bilgi şeridi (güncelleme, ücretsiz oyun)
Rectangle {
    id: b
    property string text: ""
    property color mark: theme.accent
    property real progress: -1          // 0-100 arası verilirse altta ince bir çizgi çıkar
    default property alias actions: actionRow.data

    implicitHeight: 46
    radius: 8
    color: theme.surface
    border.color: theme.line
    clip: true

    Rectangle { x: 0; width: 4; height: parent.height; color: b.mark }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 8
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: b.text
            color: theme.text
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        RowLayout { id: actionRow; spacing: 6 }
    }
    Rectangle {
        visible: b.progress >= 0
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, b.progress) / 100
        height: 3
        color: b.mark
    }
}
