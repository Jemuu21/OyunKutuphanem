import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Steam hesabını bağlama (sihirbaz ve ayarlar ortak kullanır)
ColumnLayout {
    id: sp
    property bool busy: false
    property string result: ""
    property bool resultOk: false
    property bool advanced: false
    property bool familyBusy: false
    property string familyResult: ""
    property bool familyOk: false
    signal connected()
    spacing: 10

    // ---- Uygulama içi giriş (önerilen yol)
    ColumnLayout {
        visible: backend.webLoginAvailable
        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: backend.steamLoggedIn && !backend.steamExpired
                  ? "Steam hesabınla giriş yapıldı. Oyunların ve aile kütüphanen kendiliğinden güncellenir."
                  : backend.steamExpired
                  ? "Steam oturumun sona ermiş. Oyun listenin güncellenmesi için tekrar giriş yap."
                  : "Steam hesabınla giriş yapman yeterli. Kendi oyunların ve Steam ailende paylaşılan oyunlar kendiliğinden gelir."
            color: backend.steamExpired ? theme.accent : theme.text
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            visible: backend.steamLoggedIn && backend.familyInfo !== ""
            text: backend.familyInfo
            color: theme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        RowLayout {
            spacing: 8
            AppButton {
                visible: !backend.steamLoggedIn || backend.steamExpired
                kind: "primary"
                text: sp.busy ? "Giriş penceresi açık" : "Steam ile giriş yap"
                enabled: !sp.busy
                onClicked: { sp.busy = true; sp.result = ""; backend.loginSteam() }
            }
            AppButton {
                visible: backend.steamLoggedIn && !backend.steamExpired
                text: "Listeyi şimdi yenile"
                onClicked: backend.reload_all()
            }
            AppButton {
                visible: backend.steamLoggedIn
                kind: "ghost"
                text: "Steam'den çıkış yap"
                onClicked: backend.logoutSteam()
            }
        }
        Text {
            Layout.fillWidth: true
            visible: !backend.steamLoggedIn
            text: "Programın içinde Steam'in kendi giriş sayfası açılır. Telefondaki Steam uygulamasıyla QR kodu okutarak da girebilirsin. Şifren programa kaydedilmez."
            color: theme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    Text {
        Layout.fillWidth: true
        visible: sp.result !== ""
        text: sp.result
        color: sp.resultOk ? theme.ok : theme.danger
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }

    // ---- Gelişmiş: API anahtarı (giriş yapmak istemeyenler için)
    AbstractButton {
        id: advToggle
        Layout.topMargin: 4
        visible: !backend.steamLoggedIn || !backend.webLoginAvailable
        hoverEnabled: true
        onClicked: sp.advanced = !sp.advanced
        contentItem: Text {
            text: (sp.advanced || !backend.webLoginAvailable ? "▾ " : "▸ ") + "Gelişmiş: giriş yapmadan API anahtarıyla bağlan"
            color: advToggle.hovered ? theme.text : theme.muted
            font.pixelSize: 13
        }
        background: Item {}
    }
    ColumnLayout {
        visible: (sp.advanced || !backend.webLoginAvailable) && advToggle.visible
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: "Steam, anahtarı sadece en az 5 dolar harcama yapılmış hesaplara veriyor. Bu yolla aile kütüphanesi gelmez."
            color: theme.muted
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            AppField {
                id: keyField
                Layout.fillWidth: true
                placeholderText: "Steam API anahtarı"
                echoMode: TextInput.Password
                text: backend.steamKey
            }
            AppButton { text: "Anahtar al"; onClicked: Qt.openUrlExternally("https://steamcommunity.com/dev/apikey") }
        }
        AppField {
            id: profileField
            Layout.fillWidth: true
            placeholderText: "Profil linki, ör. https://steamcommunity.com/id/kullaniciadi"
            text: backend.steamProfile
        }
        AppButton {
            text: "Anahtarla bağlan"
            enabled: !sp.busy && keyField.text.trim() !== "" && profileField.text.trim() !== ""
            onClicked: { sp.busy = true; sp.result = ""; backend.saveSteam(keyField.text, profileField.text) }
        }
    }

    // ---- Tarayıcı motoru yoksa: elle jeton (eski yol)
    ColumnLayout {
        visible: !backend.webLoginAvailable
        Layout.fillWidth: true
        spacing: 10
        Text { text: "Steam Aile kütüphanesi"; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold; Layout.topMargin: 6 }
        Text {
            Layout.fillWidth: true
            text: "'Jeton sayfasını aç' de, açılan sayfadaki yazının tamamını kopyalayıp aşağıya yapıştır."
            color: theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        AppButton { text: "Jeton sayfasını aç"; onClicked: backend.openSteamTokenPage() }
        AppField { id: tokenField; Layout.fillWidth: true; placeholderText: "Kopyaladığın yazıyı buraya yapıştır"; echoMode: TextInput.Password }
        RowLayout {
            spacing: 12
            AppButton {
                text: sp.familyBusy ? "Çekiliyor" : "Aile kütüphanesini çek"
                enabled: !sp.familyBusy && tokenField.text.trim() !== ""
                onClicked: { sp.familyBusy = true; sp.familyResult = ""; backend.submitSteamToken(tokenField.text) }
            }
            Text {
                Layout.fillWidth: true
                visible: sp.familyResult !== ""
                text: sp.familyResult
                color: sp.familyOk ? theme.ok : theme.danger
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }

    Connections {
        target: backend
        function onSteamResult(ok, msg) {
            sp.busy = false
            sp.result = msg
            sp.resultOk = ok
            if (ok) sp.connected()
        }
        function onFamilyResult(ok, msg) {
            sp.familyBusy = false
            sp.familyResult = msg
            sp.familyOk = ok
            if (ok) { tokenField.text = ""; sp.connected() }
        }
    }
}
