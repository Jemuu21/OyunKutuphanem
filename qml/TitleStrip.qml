import QtQuick
import QtQuick.Window

// Pencerenin en üstü: Windows'un başlık çubuğu yerine. Sağ üstte pencere butonları,
// boş yerden tutup sürükleyince pencere taşınır, çift tıklayınca ekranı kaplar.
Rectangle {
    id: strip
    property var win
    implicitHeight: 40
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: strip.win.startSystemMove()
        onDoubleClicked: strip.win.visibility === Window.Maximized ? strip.win.showNormal() : strip.win.showMaximized()
    }
    TrafficLights {
        objectName: "windowButtons"
        win: strip.win
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
    }
}
