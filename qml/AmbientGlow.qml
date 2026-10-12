import QtQuick

// Seçili oyunun renginden yumuşak bir arka plan tonu. Renk değişince akarak geçer.
Item {
    id: glow
    property string tint: ""          // "#rrggbb" ya da boş
    property real strength: 0.2       // en üstteki renk ne kadar belirgin
    property color topColor: tint !== "" ? Qt.tint(theme.bg, Qt.rgba(base.r, base.g, base.b, strength)) : theme.bg
    readonly property color base: tint !== "" ? tint : theme.bg
    Behavior on topColor { enabled: appRoot.motion; ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: glow.topColor }
            GradientStop { position: 1.0; color: theme.bg }
        }
    }
}
