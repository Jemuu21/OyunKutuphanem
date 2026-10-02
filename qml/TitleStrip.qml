import QtQuick
import QtQuick.Window

// Pencerenin en üstü: Windows'un başlık çubuğu yerine. Sol üstte macOS tarzı butonlar,
// boş yerden tutup sürükleyince pencere taşınır, çift tıklayınca ekranı kaplar.
Rectangle {
    id: strip
    property var win
    implicitHeight: 34
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: strip.win.startSystemMove()
        onDoubleClicked: strip.win.visibility === Window.Maximized ? strip.win.showNormal() : strip.win.showMaximized()
    }
    TrafficLights {
        win: strip.win
        x: 16
        anchors.verticalCenter: parent.verticalCenter
    }
}
