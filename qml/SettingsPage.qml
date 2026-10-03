import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sağdan açılan ayarlar paneli
Item {
    id: sp
    signal closeRequested()

    Rectangle {   // arka planı karart, tıklayınca kapat
        anchors.fill: parent
        color: theme.overlay
        MouseArea { anchors.fill: parent; onClicked: sp.closeRequested(); onWheel: (w) => w.accepted = true }
    }

    Rectangle {
        id: panel
        width: Math.min(560, parent.width - 60)
        height: parent.height
        anchors.right: parent.right
        color: theme.surface
        border.color: theme.line
        MouseArea { anchors.fill: parent; onWheel: (w) => w.accepted = false }

        RowLayout {
            id: head
            x: 28; y: 20
            width: parent.width - 56
            Text {
                Layout.fillWidth: true
                text: "Ayarlar"
                color: theme.text
                font.family: theme.displayFont
                font.pixelSize: 28
                font.weight: Font.Bold
            }
            AppButton { kind: "ghost"; text: "Kapat  (Esc)"; onClicked: sp.closeRequested() }
        }

        Flickable {
            anchors.top: head.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            width: parent.width
            contentHeight: col.implicitHeight + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: AppScrollBar {}

            ColumnLayout {
                id: col
                x: 28
                width: panel.width - 56
                spacing: 14

                component Heading: Text {
                    Layout.topMargin: 14
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                Heading { text: "Görünüm" }
                AppSwitch {
                    Layout.fillWidth: true
                    text: "Karanlık tema"
                    note: "Kapalıyken aydınlık tema kullanılır. Kısayolu Ctrl+T."
                    checked: backend.dark
                    onToggled: backend.dark = checked
                }
                AppSwitch {
                    Layout.fillWidth: true
                    text: "Animasyonları azalt"
                    note: "Açılıştaki raf dolma ve kapak renklenme geçişleri kapanır. Değişiklikler anında görünür."
                    checked: backend.reduceMotion
                    onToggled: backend.reduceMotion = checked
                }
                AppSwitch {
                    Layout.fillWidth: true
                    text: "Ekran kartını kullanma"
                    note: "Arayüz ekran kartı yerine işlemciyle çizilir. Eski ya da sorun çıkaran ekran kartlarında işe yarar. Bu modda animasyonlar da kapanır. Program yeniden açılınca geçerli olur."
                    checked: backend.softwareRender
                    onToggled: backend.softwareRender = checked
                }

                AppSwitch {
                    visible: backend.isWindows
                    Layout.fillWidth: true
                    text: "Windows açılınca başlat"
                    note: "Bilgisayar açılınca program pencere açmadan saatin yanında başlar, güncellemeleri kontrol eder ve indirmeleri sürdürür."
                    checked: backend.autoStart
                    onToggled: backend.autoStart = checked
                }

                Heading { text: "Hem Steam'de hem Epic'te olan oyunlar" }
                Text {
                    Layout.fillWidth: true
                    text: "Bu oyunlar rafta tek kart olarak görünür. Kurulu olan kopya açılır. İkisi de kurulu değilse indirirken nereden indirileceğini seçersin."
                    color: theme.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                Segmented {
                    objectName: "dupPrefSeg"
                    options: ["Her seferinde sor", "Hep Steam", "Hep Epic"]
                    current: backend.dupPref === "steam" ? 1 : backend.dupPref === "epic" ? 2 : 0
                    onPicked: (i) => backend.dupPref = ["ask", "steam", "epic"][i]
                }
                RowLayout {
                    visible: backend.splitCount > 0
                    spacing: 12
                    AppButton { text: "Hepsini yeniden birleştir"; onClicked: backend.mergeAllAgain() }
                    Text {
                        Layout.fillWidth: true
                        text: backend.splitCount + " oyunu ayrı kartlarda göstermeyi seçtin."
                        color: theme.muted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                Heading { text: "Bildirimler ve güncellemeler" }
                AppSwitch {
                    Layout.fillWidth: true
                    text: "Epic'in ücretsiz oyunlarını haber ver"
                    note: "Epic her hafta ücretsiz oyun verir. Yeni oyunlar gelince bildirim çıkar ve rafın üstünde bir şerit görünür."
                    checked: backend.freeNotify
                    onToggled: backend.freeNotify = checked
                }
                AppSwitch {
                    Layout.fillWidth: true
                    text: "İstek listemdeki indirimleri haber ver"
                    note: "Steam istek listendeki bir oyun indirime girince bildirim çıkar ve rafın üstünde bir şerit görünür. Steam'e giriş yapmış olman gerekir."
                    checked: backend.wishNotify
                    onToggled: backend.wishNotify = checked
                }
                AppSwitch {
                    Layout.fillWidth: true
                    text: "Oyundaki arkadaşlarımı göster"
                    note: "Steam arkadaşlarından şu an oyunda olanlar rafın altında görünür. Lobisi açık olanlara tek tıkla katılabilirsin."
                    checked: backend.showFriends
                    onToggled: { backend.showFriends = checked; backend.checkFriends(true) }
                }
                AppSwitch {
                    visible: backend.updateEnabled
                    Layout.fillWidth: true
                    text: "Güncellemeleri kendiliğinden kontrol et"
                    note: "Günde iki kez yeni sürüm var mı diye bakar. Güncellemeyi sen onaylamadan kurmaz."
                    checked: backend.autoUpdateCheck
                    onToggled: backend.autoUpdateCheck = checked
                }
                RowLayout {
                    visible: backend.updateEnabled
                    spacing: 12
                    AppButton { text: "Şimdi kontrol et"; onClicked: backend.checkUpdates(true) }
                    Text { text: "Kaynak: " + backend.updateSource; color: theme.muted; font.pixelSize: 12 }
                }

                Heading { text: "Steam" }
                SteamPanel { Layout.fillWidth: true }

                Heading { text: "Epic Games" }
                EpicPanel { Layout.fillWidth: true }

                Heading { text: "Araçlar" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    AppButton { text: "Epic Launcher'daki oyunları içe aktar"; onClicked: backend.importFromLauncher() }
                    AppButton { text: "Bütün bulut kayıtlarını eşitle"; onClicked: backend.syncAllSaves() }
                    AppButton { visible: backend.isWindows; text: "Masaüstüne kısayol oluştur"; onClicked: backend.createShortcut() }
                    AppButton { text: "Disk alanı"; onClicked: { sp.closeRequested(); appRoot.diskOpen = true } }
                    AppButton { text: "Sorun bildir"; onClicked: backend.reportProblem() }
                    AppButton { text: "Kayıt klasörünü aç"; onClicked: backend.openLogFolder() }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    text: "Oyun Kütüphanem " + backend.appVersion + ". Ayarların ve Steam anahtarın şu klasörde durur: " + backend.dataFolder
                    color: theme.faint
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
