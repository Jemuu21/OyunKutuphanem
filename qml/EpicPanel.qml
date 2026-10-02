import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// Epic hesabını bağlama ve oyun klasörü (sihirbaz ve ayarlar ortak kullanır)
ColumnLayout {
    id: ep
    property bool busy: false
    property string result: ""
    property bool resultOk: false
    property bool relogin: false
    readonly property bool linked: backend.epicAccount !== ""
    signal connected()
    spacing: 10

    Text {
        Layout.fillWidth: true
        text: ep.linked ? "Bağlı Epic hesabı: " + backend.epicAccount : "Epic oyunlarını görmek için hesabına bir kere giriş yapman yeterli."
        color: theme.text
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }
    AppButton {
        visible: ep.linked && !ep.relogin
        text: "Başka bir hesapla bağlan"
        onClicked: ep.relogin = true
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: !ep.linked || ep.relogin
        spacing: 10
        Repeater {
            model: [
                "1. 'Giriş sayfasını aç' butonuna bas ve Epic hesabınla giriş yap.",
                "2. Girişten sonra sayfada bir yazı çıkacak. İçinde authorizationCode geçiyor. Yazının tamamını kopyala.",
                "3. Aşağıya yapıştır ve 'Bağlan'a bas. Kod birkaç dakika geçerli."
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
        AppButton { text: "Giriş sayfasını aç"; onClicked: backend.openEpicLoginPage() }
        AppField {
            id: codeField
            Layout.fillWidth: true
            placeholderText: "Kopyaladığın yazıyı buraya yapıştır"
        }
        RowLayout {
            spacing: 12
            AppButton {
                kind: "primary"
                text: ep.busy ? "Bağlanıyor" : "Bağlan"
                enabled: !ep.busy && codeField.text.trim() !== ""
                onClicked: {
                    ep.busy = true
                    ep.result = ""
                    backend.submitEpicCode(codeField.text)
                }
            }
            Text {
                Layout.fillWidth: true
                visible: ep.result !== ""
                text: ep.result
                color: ep.resultOk ? theme.ok : theme.danger
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; height: 1; color: theme.line }
    Text { text: "Epic oyunlarının kurulacağı klasör"; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: backend.epicDir
            color: theme.muted
            font.pixelSize: 13
            elide: Text.ElideMiddle
        }
        AppButton { text: "Değiştir"; onClicked: folderDialog.open() }
    }
    FolderDialog {
        id: folderDialog
        title: "Epic oyunları nereye kurulsun?"
        onAccepted: backend.setEpicDir(selectedFolder.toString())
    }
    Connections {
        target: backend
        function onEpicLoginResult(ok, msg) {
            ep.busy = false
            ep.result = msg
            ep.resultOk = ok
            if (ok) {
                codeField.text = ""
                ep.relogin = false
                ep.connected()
            }
        }
    }
}
