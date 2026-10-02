import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Steam hesabını bağlama (sihirbaz ve ayarlar ortak kullanır)
ColumnLayout {
    id: sp
    property bool busy: false
    property string result: ""
    property bool resultOk: false
    property bool familyBusy: false
    property string familyResult: ""
    property bool familyOk: false
    signal connected()
    spacing: 10

    Text {
        Layout.fillWidth: true
        text: backend.steamConnected ? "Steam hesabın bağlı. Bilgileri değiştirmek istersen aşağıdan güncelleyebilirsin."
                                     : "Steam oyunlarını görmek için bir API anahtarı ve profil linkin gerekiyor."
        color: theme.text
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: [
            "1. 'Anahtar al' butonuna bas. Açılan Steam sayfasında alan adı kısmına localhost yazıp anahtarı oluştur.",
            "2. Anahtarı ve Steam profilinin linkini aşağıya yapıştır.",
            "3. Steam'de Profil, Profili Düzenle, Gizlilik Ayarları yolunu izle ve 'Oyun ayrıntıları'nı herkese açık yap. Yoksa liste boş gelir.",
            "Steam, anahtarı sadece en az 5 dolar harcama yapılmış hesaplara veriyor. Anahtar alamazsan bu adımı atla: bilgisayarında kurulu Steam oyunların yine rafta görünür, sadece kurulu olmayanlar görünmez."
        ]
        Text {
            required property string modelData
            Layout.fillWidth: true
            text: modelData
            color: theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
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
    RowLayout {
        spacing: 12
        AppButton {
            kind: "primary"
            text: sp.busy ? "Bağlanıyor" : "Kaydet ve bağlan"
            enabled: !sp.busy && keyField.text.trim() !== "" && profileField.text.trim() !== ""
            onClicked: {
                sp.busy = true
                sp.result = ""
                backend.saveSteam(keyField.text, profileField.text)
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
    }
    // ---- Steam Aile kütüphanesi ----
    Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; height: 1; color: theme.line }
    Text { text: "Steam Aile kütüphanesi"; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
    Text {
        Layout.fillWidth: true
        text: "Bir Steam ailesindeysen, ailende paylaşılan oyunları da rafa ekleyebilirsin. API anahtarın yoksa bu yolla kendi oyunların da gelir."
        color: theme.text
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: [
            "1. 'Jeton sayfasını aç' butonuna bas. Tarayıcında Steam mağazasına giriş yapmış olman gerekiyor.",
            "2. Açılan sayfadaki yazının tamamını kopyala. İçinde webapi_token geçiyor.",
            "3. Aşağıya yapıştır ve 'Aile kütüphanesini çek'e bas. Oyun listesi kaydedilir, jeton hiçbir yere kaydedilmez. Ailene yeni oyun eklenince aynı adımları tekrarlaman yeterli."
        ]
        Text {
            required property string modelData
            Layout.fillWidth: true
            text: modelData
            color: theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
    AppButton { text: "Jeton sayfasını aç"; onClicked: backend.openSteamTokenPage() }
    AppField {
        id: tokenField
        Layout.fillWidth: true
        placeholderText: "Kopyaladığın yazıyı buraya yapıştır"
        echoMode: TextInput.Password
    }
    RowLayout {
        spacing: 12
        AppButton {
            kind: "primary"
            text: sp.familyBusy ? "Çekiliyor" : "Aile kütüphanesini çek"
            enabled: !sp.familyBusy && tokenField.text.trim() !== ""
            onClicked: {
                sp.familyBusy = true
                sp.familyResult = ""
                backend.submitSteamToken(tokenField.text)
            }
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
    Text {
        Layout.fillWidth: true
        visible: backend.familyInfo !== ""
        text: backend.familyInfo
        color: theme.muted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    Connections {
        target: backend
        function onFamilyResult(ok, msg) {
            sp.familyBusy = false
            sp.familyResult = msg
            sp.familyOk = ok
            if (ok) { tokenField.text = ""; sp.connected() }
        }
        function onSteamResult(ok, msg) {
            sp.busy = false
            sp.result = msg
            sp.resultOk = ok
            if (ok) sp.connected()
        }
    }
}
