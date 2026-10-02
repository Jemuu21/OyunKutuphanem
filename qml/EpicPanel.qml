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
    readonly property bool linked: backend.epicAccount !== ""
    signal connected()
    spacing: 10

    property bool manual: false
    Text {
        Layout.fillWidth: true
        text: ep.linked ? "Bağlı Epic hesabı: " + backend.epicAccount : "Epic oyunlarını görmek için hesabınla bir kere giriş yapman yeterli."
        color: theme.text
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }
    RowLayout {
        spacing: 8
        AppButton {
            visible: backend.webLoginAvailable && !ep.linked
            kind: "primary"
            text: ep.busy ? "Giriş penceresi açık" : "Epic ile giriş yap"
            enabled: !ep.busy
            onClicked: { ep.busy = true; ep.result = ""; backend.loginEpic() }
        }
        AppButton {
            visible: ep.linked
            kind: "ghost"
            text: "Epic'ten çıkış yap"
            onClicked: backend.logoutEpic()
        }
    }
    Text {
        Layout.fillWidth: true
        visible: backend.webLoginAvailable && !ep.linked
        text: "Programın içinde Epic'in kendi giriş sayfası açılır, giriş yapınca kendiliğinden kapanır. Şifren programa kaydedilmez."
        color: theme.muted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    Text {
        Layout.fillWidth: true
        visible: ep.result !== "" && !ep.manualVisible
        text: ep.result
        color: ep.resultOk ? theme.ok : theme.danger
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    AbstractButton {
        id: manualToggle
        visible: backend.webLoginAvailable && !ep.linked
        hoverEnabled: true
        onClicked: ep.manual = !ep.manual
        contentItem: Text {
            text: (ep.manual ? "▾ " : "▸ ") + "Giriş penceresi açılmazsa: elle bağlan"
            color: manualToggle.hovered ? theme.text : theme.muted
            font.pixelSize: 13
        }
        background: Item {}
    }
    readonly property bool manualVisible: !ep.linked && (ep.manual || !backend.webLoginAvailable)
    ColumnLayout {
        Layout.fillWidth: true
        visible: ep.manualVisible
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
                ep.manual = false
                ep.connected()
            }
        }
    }
}
