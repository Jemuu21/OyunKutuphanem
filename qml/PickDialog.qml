import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ne oynasam? Kurulu oyunlarından birini seçer.
Popup {
    id: pd
    property string mode: "all"
    property var seq: []
    property int idx: -1
    property var game: idx >= 0 && idx < seq.length ? seq[idx] : null
    readonly property bool rolling: roll.running
    readonly property bool landed: !rolling && idx === seq.length - 1 && seq.length > 0

    function roll_() {
        seq = backend.pickGames(mode)
        if (seq.length === 0) { idx = -1; return }
        if (!appRoot.motion || seq.length === 1) { idx = seq.length - 1; return }
        idx = 0
        roll.step = 0
        roll.interval = 70
        roll.start()
    }
    onOpened: roll_()

    Timer {   // kapakları hızla değiştirip yavaşlayarak seçilen oyunda durur
        id: roll
        property int step: 0
        repeat: true
        onTriggered: {
            pd.idx = Math.min(pd.idx + 1, pd.seq.length - 1)
            step += 1
            interval = 70 + step * step * 6
            if (pd.idx >= pd.seq.length - 1) stop()
        }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(560, parent ? parent.width - 48 : 560)
    modal: true
    focus: true
    padding: 26
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }

    contentItem: ColumnLayout {
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Ne oynasam?"
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 24
                font.weight: Font.Bold
            }
            AppButton { kind: "ghost"; text: "Kapat"; onClicked: pd.close() }
        }
        Segmented {
            options: ["Hepsi", "Uzun süredir açmadıklarım", "Hiç oynamadıklarım"]
            current: pd.mode === "stale" ? 1 : pd.mode === "never" ? 2 : 0
            onPicked: (i) => { pd.mode = ["all", "stale", "never"][i]; pd.roll_() }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 215 / 460 + 22
            visible: pd.game !== null
            CoverArt {
                id: cover
                x: 20
                width: parent.width - 40
                height: width * 215 / 460
                game: pd.game
                scale: pd.landed && appRoot.motion ? 1.0 : (appRoot.motion ? 0.96 : 1.0)
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            }
            Shelf { y: cover.height; width: parent.width }
        }
        Text {
            visible: pd.seq.length === 0
            Layout.fillWidth: true
            text: pd.mode === "all" ? "Kurulu oyunun yok. Önce bir oyun indir."
                : pd.mode === "stale" ? "1 aydan uzun süredir açmadığın kurulu oyun yok."
                : "Kurulu oyunlarının hepsini oynamışsın."
            color: theme.muted
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        ColumnLayout {
            visible: pd.game !== null
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: pd.game ? pd.game.title : ""
                color: theme.text
                font.pixelSize: 20
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                text: !pd.game ? "" : !pd.landed ? "Seçiliyor…"
                    : pd.game.playtimeText !== "" ? pd.game.playtimeText + (pd.game.lastPlayedText ? ", son: " + pd.game.lastPlayedText : "")
                    : "Henüz oynamadın"
                color: theme.muted
                font.pixelSize: 13
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            AppButton {
                kind: "primary"
                text: "Oyna"
                enabled: pd.landed
                onClicked: { backend.play(pd.game.key); pd.close() }
            }
            AppButton { text: "Başka öner"; enabled: !pd.rolling && pd.seq.length > 0; onClicked: pd.roll_() }
            Item { Layout.fillWidth: true }
            AppButton { kind: "ghost"; text: "Ayrıntılar"; enabled: pd.landed; onClicked: { var g = pd.game; pd.close(); appRoot.openDetail(g) } }
        }
    }
}
