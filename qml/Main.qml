import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs
import "state.js" as S

// Oyun Kütüphanem: ana pencere
ApplicationWindow {
    id: appRoot
    width: 1320
    height: 860
    minimumWidth: 1080
    minimumHeight: 620
    visible: !startHidden   // "Windows açılınca başlat" ile açıldıysa saatin yanında bekler
    title: "Oyun Kütüphanem"   // görev çubuğunda görünür; pencerenin içinde Windows başlığı yok
    // Windows'un çerçevesi yerine kendi üst şeridimiz (macOS tarzı butonlar)
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinMaxButtonsHint
    color: theme.bg
    font.family: theme.bodyFont
    font.pixelSize: 14

    // Ekran kartı olmadan çizerken animasyonlar ağırlaşır, o zaman kendiliğinden kapanır
    readonly property bool motion: !backend.reduceMotion && !backend.softwareActive
    property var detailGame: null
    property bool settingsOpen: false
    property bool skyOpen: false
    property bool diskOpen: false
    property bool statsOpen: false
    property var dragGame: null         // sürüklenen oyun
    property point dragPos: Qt.point(0, 0)

    function startDrag(g, p) { dragPos = p; dragGame = g }
    function moveDrag(p) { dragPos = p }
    function endDrag() {
        if (!dragGame) return
        dragGhost.Drag.drop()
        dragGame = null
    }
    function minutesText(m, short) {
        m = Math.round(m || 0)
        if (m < 60) return m + " dk"
        var h = Math.floor(m / 60), r = m % 60
        if (short || h >= 100 || r === 0) return h.toLocaleString(Qt.locale("tr_TR"), "f", 0) + " sa"
        return h + " sa " + r + " dk"
    }
    function dateText(ts) {
        var d = new Date(ts * 1000)
        var ay = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
        return d.getDate() + " " + ay[d.getMonth()] + " " + d.getFullYear()
    }
    property int visibilityBeforeSky: Window.Windowed

    // ------------------------------------------------------------ ortak işlevler
    function kindColor(k) {
        return k === "ok" ? theme.ok : k === "accent" ? theme.accent : k === "queued" ? theme.queued
             : k === "progress" ? theme.text : theme.muted
    }
    function runAction(g, action) {
        if (!g || !action) return
        if (action === "chooseSource") {
            // Hem Steam'de hem Epic'te olan oyun: ayarda bir tercih varsa sormadan onu kullan
            if (backend.dupPref === "steam" || backend.dupPref === "epic") backend.installFrom(g.key, backend.dupPref)
            else sourcePick.openFor(g)
            return
        }
        backend[action](g.key)
    }
    function enterOn(g) {
        if (!g) return
        if (g.state === "installed" && !(g.update && g.platform === "epic")) backend.play(g.key)
        else openDetail(g)
    }
    function openDetail(g) {
        // Kütüphane görünümünde oyun soldaki listede seçilir; listede yoksa (filtre vb.) sayfa üstte açılır
        if (backend.viewMode === "library" && libraryView.select(g)) return
        detailGame = g
    }
    function closeDetail() { detailGame = null; focusView() }
    function showGameMenu(g, item, x, y) {
        gameMenu.game = g
        gameMenu.popup(item, x, y)
    }
    function askCancel(g) {
        if (g.platform === "steam") {
            dialog.ask("Steam indirmesi iptal edilsin mi?",
                       "Steam'in kaldırma penceresi açılacak. Orada onaylarsan indirme durur ve inen dosyalar silinir.",
                       "Steam'de aç", "Vazgeç", false, function() { backend.cancel(g.key) })
        } else if (g.updating) {
            dialog.ask(g.title + " güncellemesi iptal edilsin mi?",
                       "Güncelleme durur. Oyunun kendisi silinmez, istediğin zaman tekrar güncelleyebilirsin.",
                       "Güncellemeyi iptal et", "Vazgeç", true, function() { backend.cancel(g.key) })
        } else {
            dialog.ask(g.title + " indirmesi iptal edilsin mi?",
                       "İndirme durur ve şimdiye kadar inen dosyaların hepsi silinir. Sonra indirmek istersen baştan başlar.",
                       "İptal et ve sil", "Vazgeç", true, function() { backend.cancel(g.key) })
        }
    }
    function askUninstall(g) {
        if (g.platform === "steam") { backend.uninstall(g.key); return }   // Steam kendisi sorar
        if (g.platform === "local") {
            dialog.ask(g.title + " raftan kaldırılsın mı?",
                       "Sadece raftan kalkar. Bilgisayarındaki dosyalarına dokunulmaz.",
                       "Raftan kaldır", "Vazgeç", true, function() { backend.removeLocalGame(g.key) })
            return
        }
        dialog.ask(g.title + " kaldırılsın mı?",
                   "Oyunun dosyaları bilgisayarından silinecek. Sonra istersen tekrar indirebilirsin.",
                   "Kaldır", "Vazgeç", true, function() { backend.uninstall(g.key) })
    }
    function askUpdate() {
        var busy = backend.downloadSummary !== ""
        dialog.ask("Güncellensin mi?",
                   "Program yeni sürümü indirip kapanacak. Kurulum birkaç saniye sürer, bitince program kendiliğinden açılır." +
                   (busy ? "\n\nDevam eden indirme duracak. Program açılınca 'Devam et' ile kaldığın yerden sürdürebilirsin." : ""),
                   "Güncelle", "Vazgeç", false, function() { backend.installUpdate() })
    }
    function currentView() {
        return backend.viewMode === "list" ? listShelf.view
             : backend.viewMode === "library" ? libraryView.view : gridShelf.view
    }
    function focusView() { currentView().forceActiveFocus() }
    function openSky() {
        if (skyOpen) return
        backend.prepareSky()
        visibilityBeforeSky = appRoot.visibility
        skyOpen = true
        appRoot.showFullScreen()
    }
    function closeSky() {
        if (!skyOpen) return
        skyOpen = false
        if (visibilityBeforeSky === Window.Maximized) appRoot.showMaximized()
        else appRoot.showNormal()
        focusView()
    }
    function closeTop() {
        if (detailGame) closeDetail()
        else if (statsOpen) { statsOpen = false; focusView() }
        else if (diskOpen) { diskOpen = false; focusView() }
        else if (settingsOpen) { settingsOpen = false; focusView() }
        else if (skyOpen) closeSky()
        else if (backend.search !== "") backend.search = ""
        else focusView()
    }

    onClosing: (close) => { close.accepted = backend.handleClose() }

    Connections {
        target: backend
        function onShowWindowRequested() {
            if (appRoot.visibility === Window.Minimized || !appRoot.visible) appRoot.showNormal()
            appRoot.raise()
            appRoot.requestActivate()
            backend.windowShown()
        }
        function onHideWindowRequested() { appRoot.hide() }
        function onConfirmQuitRequested() {
            dialog.ask("Çıkılsın mı?",
                       "Devam eden indirme durdurulacak. Sonra 'Devam et' ile kaldığın yerden sürdürebilirsin.",
                       "Çık", "Vazgeç", false, function() { backend.quitNow() }, function() { backend.cancelQuit() })
        }
        function onToast(msg, kind) { toasts.show(msg, kind) }
        function onAlert(t, msg) { dialog.ask(t, msg, "Tamam", "", false, null, null) }
        function onChanged() {
            if (search.text !== backend.search) search.text = backend.search
        }
    }

    // ------------------------------------------------------------ klavye kısayolları
    Shortcut { sequence: "Ctrl+F"; onActivated: { appRoot.closeTop(); search.forceActiveFocus(); search.selectAll() } }
    Shortcut { sequence: "Esc"; enabled: !dialog.opened && !freeDialog.opened && !coverPicker.opened && !spaceDialog.opened && !pickDialog.opened && !wishDialog.opened && !localDialog.opened && !shelfPick.opened && !sourcePick.opened && !commonGames.opened && !nameDialog.opened && !gameMenu.visible && !mainMenu.visible; onActivated: appRoot.closeTop() }
    Shortcut { sequence: "Ctrl+1"; onActivated: { backend.viewMode = "grid"; focusView() } }
    Shortcut { sequence: "Ctrl+2"; onActivated: { backend.viewMode = "list"; focusView() } }
    Shortcut { sequence: "Ctrl+3"; onActivated: { backend.viewMode = "library"; focusView() } }
    Shortcut { sequence: "Ctrl+T"; onActivated: backend.dark = !backend.dark }
    Shortcut { sequence: "F5"; onActivated: backend.reload_all() }
    Shortcut { sequence: "Ctrl+G"; onActivated: skyOpen ? closeSky() : openSky() }
    Shortcut { sequence: "Ctrl+,"; onActivated: settingsOpen = true }
    Shortcut { sequence: "F1"; onActivated: shortcutsHelp() }
    Shortcut { sequence: "Ctrl+R"; onActivated: pickDialog.open() }
    Shortcut { sequence: "Ctrl+I"; onActivated: appRoot.statsOpen = !appRoot.statsOpen }

    function shortcutsHelp() {
        dialog.ask("Klavye kısayolları",
                   "Ctrl+F   Rafta ara\n" +
                   "Ok tuşları   Oyunlar arasında gez\n" +
                   "Enter   Kurulu oyunu oyna, değilse ayrıntılarını aç\n" +
                   "Boşluk   Seçili oyunun ayrıntıları\n" +
                   "Esc   Açık sayfayı kapat ya da aramayı temizle\n" +
                   "Ctrl+1 / Ctrl+2 / Ctrl+3   Izgara / liste / kütüphane görünümü\n" +
                   "Ctrl+T   Aydınlık / karanlık tema\n" +
                   "Ctrl+G   Gökyüzü modu\n" +
                   "Ctrl+R   Ne oynasam?\n" +
                   "Ctrl+I   İstatistikler\n" +
                   "Bir oyunu tutup sürükle   Raflara ekle ya da raftaki sırasını değiştir\n" +
                   "F5   Listeyi yenile\n" +
                   "Ctrl+,   Ayarlar",
                   "Tamam", "", false, null, null)
    }

    // ------------------------------------------------------------ ana düzen
    TitleStrip {
        id: titleStrip
        win: appRoot
        z: 90
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: !appRoot.skyOpen
        height: visible ? implicitHeight : 0
    }

    ColumnLayout {
        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        RowLayout {   // üst çubuk
            id: topBar
            // Arama kutusu ve başlık dışındaki her şeyin kapladığı yer. Pencere daralınca önce başlık gizlenir,
            // sonra arama kutusu küçülür; sağdaki menü butonu hiçbir zaman kesilmez.
            readonly property real fixedWidth: {
                var w = 0, n = 0
                for (var i = 0; i < children.length; i++) {
                    var c = children[i]
                    if (c === appTitle || c === search || !c.visible) continue
                    w += (c.Layout.preferredWidth > 0 ? c.Layout.preferredWidth : c.implicitWidth); n++
                }
                return w + n * spacing
            }
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 2
            Layout.bottomMargin: 10
            spacing: 10

            Text {
                id: appTitle
                visible: topBar.width >= topBar.fixedWidth + 200 + implicitWidth + 8 + topBar.spacing
                text: "Oyun Kütüphanem"
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 24
                font.weight: Font.Bold
                Layout.rightMargin: 8
            }
            AppSearchField {
                id: search
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.maximumWidth: 560
                onTextChanged: if (backend.search !== text) backend.search = text
                Keys.onDownPressed: appRoot.focusView()
                Keys.onReturnPressed: appRoot.focusView()
            }
            FilterButton {}
            ViewSwitch {}
            FriendsButton {}
            DiceButton { onClicked: pickDialog.open() }
            DotsButton {
                id: menuButton
                compact: false
                onClicked: mainMenu.popup(menuButton, menuButton.width - mainMenu.width, menuButton.height + 6)
            }
        }

        TopBanner {   // yeni sürüm şeridi
            id: updateBanner
            property bool later: false
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 8
            visible: backend.updateState !== "" && !(later && backend.updateState === "available")
            mark: theme.ok
            progress: backend.updateState === "downloading" ? backend.updateProgress : -1
            text: backend.updateState === "downloading" ? "Güncelleme indiriliyor %" + Math.floor(backend.updateProgress)
                : backend.updateState === "ready" ? "Kuruluyor. Program birazdan kapanıp yeni sürümle açılacak."
                : "Oyun Kütüphanem " + backend.updateVersion + " hazır."
            AppButton {
                visible: backend.updateState === "available" && backend.updateNotes !== ""
                kind: "ghost"; compact: true; text: "Neler yeni"
                onClicked: dialog.ask("Sürüm " + backend.updateVersion + " ile gelenler", backend.updateNotes, "Tamam", "", false, null, null)
            }
            AppButton {
                visible: backend.updateState === "available"
                kind: "ghost"; compact: true; text: "Sonra"
                onClicked: updateBanner.later = true
            }
            AppButton {
                visible: backend.updateState === "available"
                kind: "primary"; compact: true; text: "Güncelle"
                onClicked: appRoot.askUpdate()
            }
        }
        TopBanner {   // Steam oturumu bittiyse
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 8
            visible: backend.steamLoggedIn && backend.steamExpired
            mark: theme.danger
            text: "Steam oturumun sona ermiş, oyun listen güncellenemiyor."
            AppButton { kind: "primary"; compact: true; text: "Steam ile giriş yap"; onClicked: backend.loginSteam() }
        }
        TopBanner {   // istek listesi indirimleri
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 8
            visible: backend.wishBannerVisible && backend.wishNotify
            mark: theme.ok
            text: backend.wishBannerText
            AppButton { kind: "ghost"; compact: true; text: "Kapat"; onClicked: backend.dismissWishBanner() }
            AppButton { kind: "secondary"; compact: true; text: "Göster"; onClicked: wishDialog.open() }
        }
        TopBanner {   // disk dolmak üzere
            objectName: "lowSpaceBanner"
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 8
            visible: backend.lowSpaceText !== ""
            mark: theme.danger
            text: backend.lowSpaceText
            AppButton { kind: "ghost"; compact: true; text: "Kapat"; onClicked: backend.dismissLowSpace() }
            AppButton { kind: "secondary"; compact: true; text: "Yer aç"; onClicked: { diskPage.onlyStale = true; appRoot.diskOpen = true } }
        }
        TopBanner {   // Epic ücretsiz oyun şeridi
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 8
            visible: backend.freeBannerVisible && backend.freeNotify
            text: backend.freeBannerText
            AppButton { kind: "ghost"; compact: true; text: "Kapat"; onClicked: backend.dismissFreeBanner() }
            AppButton { kind: "secondary"; compact: true; text: "Göster"; onClicked: freeDialog.open() }
        }

        ShelfBar {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.bottomMargin: 6
            Layout.preferredHeight: 40
        }

        RowLayout {   // raf ve sağda arkadaş listesi
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
        Item {   // raf
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridShelf {
                id: gridShelf
                anchors.fill: parent
                visible: backend.viewMode !== "list" && backend.viewMode !== "library"
                focus: visible
            }
            LibraryView {
                id: libraryView
                objectName: "libraryView"
                anchors.fill: parent
                visible: backend.viewMode === "library"
                focus: visible
            }
            ListShelf {
                id: listShelf
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                visible: backend.viewMode === "list"
                focus: visible
            }
            EmptyState {
                anchors.centerIn: parent
                visible: !!gamesModel && gamesModel.count === 0
                onOpenSettings: appRoot.settingsOpen = true
            }
        }
            FriendsPanel {
                objectName: "friendsPanel"
                visible: backend.friendsPanel
                Layout.preferredWidth: 310
                Layout.fillHeight: true
            }
        }

        FriendsStrip {
            Layout.fillWidth: true
            visible: backend.showFriends && !backend.friendsPanel && backend.friendsPlaying.length > 0
        }

        Rectangle {   // durum çubuğu
            Layout.fillWidth: true
            height: 32
            color: theme.surface
            Rectangle { width: parent.width; height: 1; color: theme.line }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 24
                Text { text: backend.steamMsg; color: theme.muted; font.pixelSize: 12 }
                Text { text: backend.epicMsg; color: theme.muted; font.pixelSize: 12 }
                Text {   // son 3 günde kütüphaneye gelen oyunlar; tıklayınca oyunun sayfası açılır
                    visible: backend.newGamesText !== ""
                    text: backend.newGamesText
                    color: theme.ok
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.underline: newMouse.containsMouse
                    elide: Text.ElideRight
                    Layout.maximumWidth: 420
                    MouseArea {
                        id: newMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { var g = backend.latestNewGame(); if (g) appRoot.openDetail(g) }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: backend.downloadSummary !== ""
                    width: 7; height: 7; radius: 4
                    color: theme.accent
                }
                Text {
                    text: backend.downloadSummary
                    color: theme.text
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideLeft
                    Layout.maximumWidth: 560
                }
            }
        }
    }

    // ------------------------------------------------------------ menüler
    GameMenu { id: gameMenu }

    AppMenu {
        id: mainMenu
        AppMenuItem { text: "Listeyi yenile (F5)"; onTriggered: backend.reload_all() }
        AppMenuItem { text: "Gökyüzü modu (Ctrl+G)"; onTriggered: appRoot.openSky() }
        AppMenuItem { text: "Epic'te ücretsiz oyunlar"; onTriggered: { backend.checkFreeGames(); freeDialog.open() } }
        AppMenuItem { text: "İstatistikler (Ctrl+I)"; onTriggered: appRoot.statsOpen = true }
        AppMenuItem { text: "Disk alanı"; onTriggered: appRoot.diskOpen = true }
        AppMenuItem { text: "Arkadaş listesi"; onTriggered: { backend.friendsPanel = true; backend.checkFriends(true) } }
        AppMenuItem { text: "Arkadaşınla ortak oyunlar"; onTriggered: commonGames.openFor("", "") }
        AppMenuItem { text: "İstek listemdeki indirimler"; visible: backend.wishAvailable; onTriggered: { backend.checkWishlist(); wishDialog.open() } }
        AppMenuItem { text: "Kendi oyununu ekle…"; onTriggered: localDialog.openAdd() }
        AppMenuSeparator {}
        AppMenuItem {
            text: "Gizlenen oyunları göster"
            checkable: true
            checked: backend.showHidden
            onTriggered: backend.showHidden = !backend.showHidden
        }
        AppMenuItem { text: "Epic Launcher'daki oyunları içe aktar"; onTriggered: backend.importFromLauncher() }
        AppMenuItem { text: "Bütün bulut kayıtlarını eşitle"; onTriggered: backend.syncAllSaves() }
        AppMenuItem { text: "Masaüstüne kısayol oluştur"; visible: backend.isWindows; onTriggered: backend.createShortcut() }
        AppMenuSeparator {}
        AppMenuItem { text: "Güncellemeleri kontrol et"; visible: backend.updateEnabled; onTriggered: backend.checkUpdates(true) }
        AppMenuItem { text: "Klavye kısayolları (F1)"; onTriggered: appRoot.shortcutsHelp() }
        AppMenuItem { text: "Sorun bildir"; onTriggered: backend.reportProblem() }
        AppMenuItem { text: backend.dark ? "Aydınlık tema (Ctrl+T)" : "Karanlık tema (Ctrl+T)"; onTriggered: backend.dark = !backend.dark }
        AppMenuItem { text: "Ayarlar (Ctrl+,)"; onTriggered: appRoot.settingsOpen = true }
        AppMenuSeparator {}
        AppMenuItem { text: "Programdan çık"; onTriggered: backend.requestQuit() }
    }

    // ------------------------------------------------------------ üstte açılan sayfalar
    SkyView {
        anchors.fill: parent
        z: 30
        visible: appRoot.skyOpen
        onCloseRequested: appRoot.closeSky()
    }
    DetailPage {
        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 40
        visible: !!appRoot.detailGame
        game: appRoot.detailGame
        onCloseRequested: appRoot.closeDetail()
    }
    StatsPage {
        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 41
        visible: appRoot.statsOpen
        onCloseRequested: { appRoot.statsOpen = false; appRoot.focusView() }
    }
    DiskPage {
        id: diskPage
        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 42
        visible: appRoot.diskOpen
        onCloseRequested: { appRoot.diskOpen = false; appRoot.focusView() }
    }
    SettingsPage {
        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 45
        visible: appRoot.settingsOpen
        onCloseRequested: { appRoot.settingsOpen = false; appRoot.focusView() }
    }
    Onboarding {
        anchors.top: titleStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 50
        visible: backend.needsOnboarding
    }
    Toasts {
        id: toasts
        z: 60
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        width: Math.min(600, parent.width - 40)
    }
    ResizeHandles { win: appRoot; z: 250 }
    Rectangle {   // pencerenin ince kenar çizgisi
        anchors.fill: parent
        z: 260
        color: "transparent"
        border.width: appRoot.visibility === Window.Windowed ? 1 : 0
        border.color: theme.line
        enabled: false
    }
    AppDialog { id: dialog }
    FreeGamesDialog { id: freeDialog; objectName: "freeDialog" }
    CoverPicker { id: coverPicker; objectName: "coverPicker" }
    PickDialog { id: pickDialog; objectName: "pickDialog" }
    WishlistDialog { id: wishDialog; objectName: "wishDialog" }
    LocalGameDialog { id: localDialog; objectName: "localDialog" }
    ShelfPickDialog { id: shelfPick; objectName: "shelfPick" }
    SourcePickDialog { id: sourcePick; objectName: "sourcePick" }
    CommonGamesDialog { id: commonGames; objectName: "commonGames" }
    NameDialog { id: nameDialog; objectName: "nameDialog" }
    Connections {
        target: backend
        function onOpenGameRequested(g) { appRoot.openDetail(g) }
    }

    Item {   // sürüklenen oyunun küçük kapağı
        id: dragGhost
        objectName: "dragGhost"
        z: 300
        width: 150
        height: 70
        visible: appRoot.dragGame !== null
        // imlecin sağ altında dursun ki bırakılacak raf görünsün; bırakma noktası imlecin ucu
        x: appRoot.dragPos.x + 14
        y: appRoot.dragPos.y + 14
        Drag.active: appRoot.dragGame !== null
        Drag.hotSpot.x: -14
        Drag.hotSpot.y: -14
        Drag.keys: ["game"]
        Rectangle { anchors.fill: parent; anchors.margins: -2; color: theme.accent; radius: 3 }
        CoverArt { anchors.fill: parent; game: appRoot.dragGame }
    }
    Connections {
        target: backend
        function onLocalAdded(g) { coverPicker.openFor(g) }   // yeni eklenen oyuna kapak seçtir
    }

    // Epic oyunu için diskte yeterli yer yoksa
    property var spaceGame: null
    Connections {
        target: backend
        function onSpaceProblem(key, need, free, folder) {
            appRoot.spaceGame = backend.allGames.find(g => g.key === key) || null
            spaceDialog.need = need; spaceDialog.free = free; spaceDialog.folder = folder
            spaceDialog.open()
        }
    }
    Popup {
        id: spaceDialog
        property string need: ""
        property string free: ""
        property string folder: ""
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, parent ? parent.width - 48 : 520)
        modal: true
        focus: true
        padding: 26
        closePolicy: Popup.CloseOnEscape
        Overlay.modal: Rectangle { color: theme.overlay }
        background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }
        contentItem: ColumnLayout {
            spacing: 14
            Text { text: "Diskte yeterli yer yok"; color: theme.text; font.family: theme.displayFont; font.pixelSize: 22; font.weight: Font.Bold }
            Text {
                Layout.fillWidth: true
                text: (appRoot.spaceGame ? appRoot.spaceGame.title : "Bu oyun") + " kurulunca " + spaceDialog.need +
                      " yer kaplayacak, ama seçili diskte " + spaceDialog.free + " boş.\n\nOyunu başka bir diske kurabilir ya da önce yer açabilirsin. Disk alanı sayfası, uzun süredir açmadığın büyük oyunları gösterir."
                color: theme.text
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                AppButton { kind: "primary"; text: "Başka klasöre kur"; onClicked: { spaceDialog.close(); spaceFolder.open() } }
                AppButton { text: "Disk alanına bak"; onClicked: { spaceDialog.close(); appRoot.diskOpen = true } }
                AppButton { kind: "ghost"; text: "Yine de dene"; onClicked: { spaceDialog.close(); backend.installAnyway(appRoot.spaceGame.key) } }
                AppButton { kind: "ghost"; text: "Vazgeç"; onClicked: spaceDialog.close() }
            }
        }
    }
    FolderDialog {
        id: spaceFolder
        title: "Oyun nereye kurulsun?"
        onAccepted: backend.installTo(appRoot.spaceGame.key, selectedFolder.toString())
    }

    Component.onCompleted: focusView()
}
