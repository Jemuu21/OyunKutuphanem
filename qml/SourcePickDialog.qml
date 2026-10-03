import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Hem Steam'de hem Epic'te olan bir oyunu nereden indireceğini seçtirir
Popup {
    id: sp
    property var game: null
    readonly property var steamCopy: game ? (game.platform === "steam" ? game : game.alt) : null
    readonly property var epicCopy: game ? (game.platform === "epic" ? game : game.alt) : null

    function openFor(g) { game = g; remember.checked = false; open() }
    function choose(platform) {
        var g = game
        if (remember.checked) backend.dupPref = platform
        close()
        if (g) backend.installFrom(g.key, platform)
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(520, parent ? parent.width - 48 : 520)
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }
    enter: Transition { enabled: appRoot.motion; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }

    component SourceCard: AbstractButton {
        id: card
        property string heading: ""
        property string note: ""
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Layout.fillWidth: true
        padding: 14
        implicitHeight: cardCol.implicitHeight + topPadding + bottomPadding
        Accessible.name: heading
        background: Rectangle {
            radius: 10
            color: card.hovered ? theme.surfaceHigh : theme.surface
            border.width: card.visualFocus || card.hovered ? 2 : 1
            border.color: card.visualFocus || card.hovered ? theme.accent : theme.line
        }
        contentItem: ColumnLayout {
            id: cardCol
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: card.heading
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 17
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: card.note
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.1
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        Text {
            Layout.fillWidth: true
            text: sp.game ? sp.game.title + " nereden indirilsin?" : ""
            color: theme.text
            font.family: theme.displayFont
            font.pixelSize: 21
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: "Bu oyun hem Steam'de hem Epic'te kütüphanende var. Hangisinden indirirsen o kopya kurulur ve oynarken o açılır."
            color: theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        SourceCard {
            objectName: "sourceSteam"
            heading: sp.steamCopy && sp.steamCopy.shared ? "Steam (aile kütüphanesi)" : "Steam"
            note: "Steam uygulaması indirir. İlerlemesi burada da görünür. Steam açık olmalı."
                  + (sp.steamCopy && sp.steamCopy.shared ? " Aile kütüphanesindeki oyunu, sahibi oynarken açamazsın." : "")
            onClicked: sp.choose("steam")
        }
        SourceCard {
            objectName: "sourceEpic"
            heading: "Epic Games"
            note: "Bu program indirir. Duraklatıp devam ettirebilir, iptal edebilirsin. Epic uygulamasının açık olması gerekmez."
            onClicked: sp.choose("epic")
        }
        ToggleChip {
            id: remember
            objectName: "sourceRemember"
            text: "Bundan sonra sormadan hep bunu kullan"
        }
        Text {
            Layout.fillWidth: true
            text: "Bu seçimi sonra Ayarlar'dan değiştirebilirsin."
            color: theme.faint
            font.pixelSize: 12
            visible: remember.checked
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            AppButton { text: "Vazgeç"; onClicked: sp.close() }
        }
    }
}
