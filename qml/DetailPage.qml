import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "state.js" as S

// Bir oyunun ayrıntı sayfası
Rectangle {
    id: page
    property var game: null
    readonly property bool has: !!game
    readonly property bool epic: has && game.platform === "epic"
    readonly property var p: S.primary(game)
    signal closeRequested()

    color: theme.bg
    opacity: 0.4
    Behavior on opacity { enabled: appRoot.motion; NumberAnimation { duration: 140 } }
    onVisibleChanged: opacity = visible ? 1 : 0.4

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

    AppButton {
        id: back
        x: 24; y: 18
        kind: "ghost"
        text: "Rafa dön  (Esc)"
        onClicked: page.closeRequested()
    }

    Flickable {
        anchors.top: back.bottom
        anchors.topMargin: 10
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: content.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar {}

        RowLayout {
            id: content
            visible: page.has
            width: Math.min(page.width - 80, 1180)
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            spacing: 48

            // sol: kapak rafın üstünde
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 0
                CoverArt {
                    Layout.preferredWidth: Math.min(540, page.width * 0.42)
                    Layout.preferredHeight: Layout.preferredWidth * 215 / 460
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    game: page.game
                }
                Shelf { Layout.fillWidth: true }
                Text {
                    Layout.topMargin: 6
                    Layout.leftMargin: 20
                    visible: page.has && (page.game.state === "not_installed" || page.game.state === "queued")
                    text: "Kapak, oyun indikçe soldan sağa renklenir."
                    color: theme.faint
                    font.pixelSize: 12
                }
            }

            // sağ: bilgiler ve butonlar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 14

                RowLayout {
                    spacing: 8
                    Text { text: page.epic ? "Epic Games" : (page.has && page.game.shared ? "Steam ailesi" : "Steam"); color: theme.muted; font.pixelSize: 14 }
                    Star { visible: page.has && page.game.favorite; implicitWidth: 13; implicitHeight: 13 }
                }
                Text {
                    Layout.fillWidth: true
                    text: page.has ? page.game.title : ""
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 38
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    lineHeight: 1.0
                }
                RowLayout {
                    spacing: 12
                    Text {
                        text: S.statusText(page.game)
                        color: appRoot.kindColor(S.statusKind(page.game))
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }
                    Text {
                        visible: page.has && page.game.info !== "" && (page.game.state === "downloading" || page.game.state === "playing" || page.game.state === "busy")
                        text: page.has ? page.game.info : ""
                        color: theme.muted
                        font.pixelSize: 14
                    }
                }
                Rectangle {   // geniş ilerleme çizgisi
                    visible: page.has && (page.game.state === "downloading" || page.game.state === "paused" || page.game.state === "steam_dl")
                    Layout.fillWidth: true
                    Layout.maximumWidth: 520
                    height: 6
                    radius: 3
                    color: theme.shelf
                    Rectangle {
                        width: parent.width * Math.max(0, page.has ? page.game.progress : 0) / 100
                        height: parent.height
                        radius: 3
                        color: page.has && page.game.state === "paused" ? theme.muted : theme.accent
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    AppButton {
                        kind: page.p.strong ? "primary" : "secondary"
                        text: page.p.text
                        enabled: page.p.enabled
                        onClicked: appRoot.runAction(page.game, page.p.action)
                    }
                    AppButton {
                        visible: page.epic && page.game.state === "installed" && page.game.update
                        text: "Güncellemeden oyna"
                        onClicked: backend.play(page.game.key)
                    }
                    AppButton {
                        visible: page.has && page.game.state === "queued"
                        text: "Sıradan çıkar"
                        onClicked: backend.dequeue(page.game.key)
                    }
                    AppButton {
                        visible: S.canCancel(page.game)
                        kind: "danger"
                        text: "İptal et"
                        onClicked: appRoot.askCancel(page.game)
                    }
                    AppButton {
                        visible: page.has && (page.game.installPath !== "" || page.game.state === "downloading")
                        text: "Klasörü aç"
                        onClicked: backend.openFolder(page.game.key)
                    }
                    AppButton {
                        visible: page.epic && page.game.cloud && page.game.state === "installed"
                        text: "Kayıtları eşitle"
                        onClicked: backend.syncSaves(page.game.key)
                    }
                    AppButton {
                        text: page.has && page.game.favorite ? "Favorilerden çıkar" : "Favorilere ekle"
                        onClicked: backend.toggleFavorite(page.game.key)
                    }
                    AppButton {
                        text: page.has && page.game.hidden ? "Raftan gizlemeyi kaldır" : "Raftan gizle"
                        onClicked: backend.toggleHidden(page.game.key)
                    }
                    AppButton {
                        text: "Kapağı değiştir"
                        onClicked: coverPicker.openFor(page.game)
                    }
                    AppButton {
                        visible: page.has && page.game.state === "installed"
                        kind: "danger"
                        text: "Kaldır"
                        onClicked: appRoot.askUninstall(page.game)
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: theme.line }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 28
                    rowSpacing: 12

                    component Label: Text { color: theme.muted; font.pixelSize: 14; Layout.alignment: Qt.AlignTop }
                    component Value: Text { color: theme.text; font.pixelSize: 14; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }

                    Label { visible: page.has && page.game.shared; text: "Sahiplik" }
                    Value {
                        visible: page.has && page.game.shared
                        text: "Steam ailenden paylaşılıyor. Kurup oynayabilirsin, ama aynı anda sahibi oynuyorsa Steam izin vermeyebilir."
                        wrapMode: Text.WordWrap
                    }
                    Label { text: "Oynama süresi" }
                    Value { text: page.has && page.game.playtimeText !== "" ? page.game.playtimeText : "Henüz oynanmadı" }
                    Label { text: "Son oynama" }
                    Value { text: page.has && page.game.lastPlayedText !== "" ? page.game.lastPlayedText : "Kayıt yok" }
                    Label { visible: page.has && page.game.sizeText !== ""; text: "Kapladığı yer" }
                    Value { visible: page.has && page.game.sizeText !== ""; text: page.has ? page.game.sizeText : "" }
                    Label { text: "Konum" }
                    Value { text: page.has && page.game.installPath !== "" ? page.game.installPath : "Kurulu değil" }
                    Label { visible: page.epic; text: "Bulut kayıtları" }
                    Value {
                        visible: page.epic
                        text: page.has && page.game.cloud ? "Var. Oyna dediğinde önce indirilir, oyun kapanınca buluta yüklenir."
                                                          : "Bu oyunda bulut kaydı yok."
                        wrapMode: Text.WordWrap
                    }
                    Label { visible: page.has && page.game.downloadSize !== ""; text: "İndirme boyutu" }
                    Value { visible: page.has && page.game.downloadSize !== ""; text: page.has ? page.game.downloadSize : "" }
                    Label { visible: page.epic && page.game.update; text: "Güncelleme" }
                    Value { visible: page.epic && page.game.update; text: "Yeni sürüm hazır. Güncelle'ye basınca sıraya girer." ; wrapMode: Text.WordWrap }
                }
                Text {
                    Layout.fillWidth: true
                    visible: page.has && !page.epic && page.game.state !== "not_installed"
                    text: "Steam oyunlarında indirme, durdurma ve kaldırma Steam'in kendi penceresinde yapılır."
                    color: theme.faint
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
