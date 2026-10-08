import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Pencere butonları: küçült (sarı), ekranı kapla (yeşil), kapat (kırmızı)
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
        width: 18
        height: 18
        radius: 9
        color: tl.win && tl.win.active || tl.hovering ? fill : (theme.dark ? "#3A4450" : "#C3CBD2")
        border.width: 0.5
        border.color: Qt.darker(color, 1.25)
        Accessible.role: Accessible.Button
        Accessible.name: kind === "close" ? "Kapat" : kind === "min" ? "Simge durumuna küçült" : (tl.maximized ? "Önceki boyut" : "Ekranı kapla")

        Item {   // işaretler hep görünür, fare üstündeyken daha belirgin
            anchors.fill: parent
            opacity: tl.hovering ? 1 : 0.55
            Rectangle { visible: l.kind === "close"; anchors.centerIn: parent; width: 10; height: 2; rotation: 45; color: l.glyph }
            Rectangle { visible: l.kind === "close"; anchors.centerIn: parent; width: 10; height: 2; rotation: -45; color: l.glyph }
            Rectangle { visible: l.kind === "min"; anchors.centerIn: parent; width: 10; height: 2; color: l.glyph }
            Rectangle { visible: l.kind === "max"; anchors.centerIn: parent; width: 10; height: 2; color: l.glyph }
            Rectangle { visible: l.kind === "max"; anchors.centerIn: parent; width: 2; height: 10; color: l.glyph }
        }
        MouseArea {
            id: lm
            anchors.fill: parent
            anchors.margins: -4          // biraz taşan tıklama alanı: kolay basılsın
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: l.pressed()
            ToolTip.visible: containsMouse
            ToolTip.delay: 600
            ToolTip.text: l.Accessible.name
        }
    }

    MouseArea {   // üç butonun üstüne gelindiğini anlamak için (tıklamaları butonlara bırakır)
        id: hoverArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // Sağ üstte, Windows'taki sırayla: küçült, ekranı kapla, kapat (kapat en sağda)
    Row {
        id: lights
        spacing: 12
        Light {
            kind: "min"; fill: "#FEBC2E"; glyph: "#8A5A00"
            onPressed: tl.win.showMinimized()
        }
        Light {
            kind: "max"; fill: "#28C840"; glyph: "#0B5A16"
            onPressed: tl.maximized ? tl.win.showNormal() : tl.win.showMaximized()
        }
        Light {
            kind: "close"; fill: "#FF5F57"; glyph: "#7A0E0A"
            onPressed: tl.win.close()
        }
    }
}
