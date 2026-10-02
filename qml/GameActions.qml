import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "state.js" as S

// Ana buton (İndir / Durdur / Oyna ...) ve "daha fazla" menüsü
RowLayout {
    id: ga
    property var game
    property bool compact: true
    readonly property var p: S.primary(game)
    spacing: 6

    AppButton {
        Layout.fillWidth: true
        kind: ga.p.strong ? "primary" : "secondary"
        compact: ga.compact
        text: ga.p.text
        enabled: ga.p.enabled
        onClicked: appRoot.runAction(ga.game, ga.p.action)
    }
    AppButton {
        visible: S.canCancel(ga.game)
        compact: ga.compact
        text: "İptal et"
        onClicked: appRoot.askCancel(ga.game)
    }
    DotsButton {
        id: dots
        compact: ga.compact
        onClicked: appRoot.showGameMenu(ga.game, dots, 0, dots.height + 4)
    }
}
