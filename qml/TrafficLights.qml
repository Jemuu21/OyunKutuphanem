import QtQuick
import QtQuick.Window

// macOS tarzı pencere butonları: kapat (kırmızı), küçült (sarı), büyüt (yeşil)
Item {
    id: tl
    property var win
    readonly property bool maximized: win && win.visibility === Window.Maximized
    readonly property bool hovering: hoverArea.containsMouse
    implicitWidth: lights.implicitWidth
    implicitHeight: lights.implicitHeight
    width: implicitWidth
    height: implicitHeight

    component Light: Rectangle {
        id: l
        property color fill
        property color glyph
        property string kind     // close, min, max
        signal pressed()
        width: 13
        height: 13
        radius: 7
        color: tl.win && tl.win.active || tl.hovering ? fill : (theme.dark ? "#3A4450" : "#C3CBD2")
        border.width: 0.5
        border.color: Qt.darker(color, 1.25)
        Accessible.role: Accessible.Button
        Accessible.name: kind === "close" ? "Kapat" : kind === "min" ? "Simge durumuna küçült" : (tl.maximized ? "Önceki boyut" : "Ekranı kapla")

        Item {   // işaretler sadece fare butonların üstündeyken görünür, macOS'taki gibi
            anchors.fill: parent
            visible: tl.hovering
            Rectangle { visible: l.kind === "close"; anchors.centerIn: parent; width: 7; height: 1.5; rotation: 45; color: l.glyph }
            Rectangle { visible: l.kind === "close"; anchors.centerIn: parent; width: 7; height: 1.5; rotation: -45; color: l.glyph }
            Rectangle { visible: l.kind === "min"; anchors.centerIn: parent; width: 7; height: 1.5; color: l.glyph }
            Rectangle { visible: l.kind === "max"; anchors.centerIn: parent; width: 7; height: 1.5; color: l.glyph }
            Rectangle { visible: l.kind === "max"; anchors.centerIn: parent; width: 1.5; height: 7; color: l.glyph }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: l.pressed()
        }
    }

    MouseArea {   // üç butonun üstüne gelindiğini anlamak için (tıklamaları butonlara bırakır)
        id: hoverArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
    id: lights
    spacing: 8
    Light {
        kind: "close"; fill: "#FF5F57"; glyph: "#7A0E0A"
        onPressed: tl.win.close()
    }
    Light {
        kind: "min"; fill: "#FEBC2E"; glyph: "#8A5A00"
        onPressed: tl.win.showMinimized()
    }
    Light {
        kind: "max"; fill: "#28C840"; glyph: "#0B5A16"
        onPressed: tl.maximized ? tl.win.showNormal() : tl.win.showMaximized()
    }
    }
}
