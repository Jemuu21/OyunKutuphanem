import QtQuick

// Rafın kenarı: üstte ince ışık, önde tahta yüzü, altta gölge
Item {
    implicitHeight: 22
    Rectangle { id: top; width: parent.width; height: 3; color: theme.shelfEdge }
    Rectangle { anchors.top: top.bottom; width: parent.width; height: 9; color: theme.shelf }
    Rectangle {
        y: 12
        width: parent.width
        height: 10
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, theme.dark ? 0.35 : 0.12) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
