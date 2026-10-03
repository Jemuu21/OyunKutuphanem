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
    property var ach: null          // başarımlar
    property bool achLoading: false
    property bool achAll: false
    onGameChanged: {
        ach = null; achAll = false
        achLoading = !!game && game.platform !== "local"
        if (achLoading) backend.loadAchievements(game.key)
    }
    Connections {
        target: backend
        function onAchievementsLoaded(key, data) {
            if (!!page.game && key === page.game.key) { page.ach = data; page.achLoading = false }
        }
    }

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
                    Text { text: page.epic && !page.game.alt ? "Epic Games" : S.platformLabel(page.game); color: theme.muted; font.pixelSize: 14 }
                    Star { visible: page.has && S.isFav(page.game); implicitWidth: 13; implicitHeight: 13 }
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
                        text: page.has && S.isFav(page.game) ? "Favorilerden çıkar" : "Favorilere ekle"
                        onClicked: backend.toggleFavorite(page.game.key)
                    }
                    AppButton {
                        text: page.has && page.game.hidden ? "Raftan gizlemeyi kaldır" : "Raftan gizle"
                        onClicked: backend.toggleHidden(page.game.key)
                    }
                    AppButton {
                        text: "Rafa ekle"
                        onClicked: shelfPick.openFor(page.game)
                    }
                    AppButton {
                        text: "Kapağı değiştir"
                        onClicked: coverPicker.openFor(page.game)
                    }
                    AppButton {
                        visible: page.has && page.game.platform === "local"
                        text: "Adını değiştir"
                        onClicked: localDialog.openRename(page.game)
                    }
                    AppButton {
                        visible: page.has && page.game.state === "installed"
                        kind: "danger"
                        text: page.has && page.game.platform === "local" ? "Raftan kaldır" : "Kaldır"
                        onClicked: appRoot.askUninstall(page.game)
                    }
                }

                // Hem Steam'de hem Epic'te olan oyun: iki kopyanın durumu
                ColumnLayout {
                    id: sources
                    objectName: "dupSources"
                    visible: page.has && !!page.game.alt
                    Layout.fillWidth: true
                    Layout.maximumWidth: 620
                    Layout.topMargin: 8
                    spacing: 6
                    readonly property var steamCopy: page.has && page.game.alt ? (page.game.platform === "steam" ? page.game : page.game.alt) : null
                    readonly property var epicCopy: page.has && page.game.alt ? (page.game.platform === "epic" ? page.game : page.game.alt) : null

                    Text {
                        text: "Kütüphanelerin"
                        color: theme.text
                        font.family: theme.displayFont
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Repeater {
                        model: sources.visible ? [sources.steamCopy, sources.epicCopy] : []
                        Rectangle {
                            id: srcRow
                            required property var modelData
                            readonly property var c: modelData
                            readonly property string otherState: !!c && !!c.alt ? c.alt.state : "not_installed"
                            Layout.fillWidth: true
                            implicitHeight: 50
                            radius: 8
                            color: theme.surfaceHigh
                            border.color: theme.line
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 8
                                spacing: 12
                                Text {
                                    text: srcRow.c ? S.singleLabel(srcRow.c) : ""
                                    color: theme.text
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    Layout.preferredWidth: 110
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: S.statusText(srcRow.c)
                                    color: appRoot.kindColor(S.statusKind(srcRow.c))
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                AppButton {
                                    visible: !!srcRow.c && srcRow.c.state === "installed"
                                    text: "Oyna"
                                    onClicked: backend.play(srcRow.c.key)
                                }
                                AppButton {
                                    // diğer kopya inerken ikinci bir indirme başlatılmasın
                                    visible: !!srcRow.c && srcRow.c.state === "not_installed"
                                             && (srcRow.otherState === "not_installed" || srcRow.otherState === "installed")
                                    text: srcRow.otherState === "installed" ? "Bunu da indir" : "Buradan indir"
                                    onClicked: backend.installFrom(srcRow.c.key, srcRow.c.platform)
                                }
                                AppButton {
                                    visible: !!srcRow.c && srcRow.c !== page.game && srcRow.c.state !== "installed" && srcRow.c.state !== "not_installed"
                                    text: "Göster"
                                    onClicked: appRoot.openDetail(srcRow.c)
                                }
                            }
                        }
                    }
                    AppButton {
                        kind: "ghost"
                        text: "Steam ve Epic kopyasını ayrı kartlarda göster"
                        onClicked: backend.splitDup(page.game.key)
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
                    Label { visible: page.has && page.game.platform === "local"; text: "Dosya" }
                    Value { visible: page.has && page.game.platform === "local"; text: "Bilgisayarından eklediğin oyun. Oynama süresi bu programdan açtığında sayılır." ; wrapMode: Text.WordWrap }
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
                // ---- başarımlar
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    visible: page.has && page.game.platform !== "local" && (page.achLoading || (page.ach && (page.ach.total > 0 || page.ach.error !== "")))
                    spacing: 10
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Başarımlar"; color: theme.text; font.family: theme.displayFont; font.pixelSize: 20; font.weight: Font.Bold }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: page.ach && page.ach.total > 0
                            text: page.ach ? page.ach.done + " / " + page.ach.total : ""
                            color: theme.muted
                            font.pixelSize: 14
                        }
                    }
                    Text { visible: page.achLoading; text: "Yükleniyor…"; color: theme.muted; font.pixelSize: 13 }
                    Text {
                        visible: !!page.ach && page.ach.error !== ""
                        Layout.fillWidth: true
                        text: page.ach ? page.ach.error : ""
                        color: theme.muted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        visible: !!page.ach && page.ach.total > 0
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: theme.shelf
                        Rectangle {
                            width: page.ach && page.ach.total ? parent.width * page.ach.done / page.ach.total : 0
                            height: parent.height
                            radius: 3
                            color: theme.chart
                        }
                    }
                    Repeater {
                        model: page.ach && page.ach.items ? (page.achAll ? page.ach.items : page.ach.items.slice(0, 6)) : []
                        RowLayout {
                            id: achRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 6
                                color: theme.shelf
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: achRow.modelData.icon
                                    asynchronous: true
                                    sourceSize.width: 80
                                    opacity: achRow.modelData.done ? 1 : 0.6
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: achRow.modelData.name
                                    color: achRow.modelData.done ? theme.text : theme.muted
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: achRow.modelData.desc
                                    color: theme.muted
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                text: achRow.modelData.done ? (achRow.modelData.time ? appRoot.dateText(achRow.modelData.time) : "Açıldı") : "Kilitli"
                                color: achRow.modelData.done ? theme.ok : theme.faint
                                font.pixelSize: 12
                            }
                        }
                    }
                    AppButton {
                        visible: !!page.ach && page.ach.items && page.ach.items.length > 6
                        kind: "ghost"
                        text: page.achAll ? "Daha az göster" : "Hepsini göster (" + (page.ach ? page.ach.items.length : 0) + ")"
                        onClicked: page.achAll = !page.achAll
                    }
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
