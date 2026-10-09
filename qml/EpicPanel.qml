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
            objectName: "epicLoginButton"
            visible: !ep.linked && !backend.epicWaiting
            kind: "primary"
            text: ep.busy || backend.epicBusy ? "Bağlanıyor…" : "Epic ile giriş yap"
            enabled: !ep.busy && !backend.epicBusy
            onClicked: { ep.result = ""; backend.loginEpic() }
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
        visible: !ep.linked && !backend.epicWaiting
        text: "Giriş, bilgisayarındaki tarayıcıda (Chrome, Edge…) açılır. Google, Apple ya da e-postanla giriş yapabilirsin. Şifren programa kaydedilmez."
        color: theme.muted
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // Tarayıcıda giriş yapılırken: adımlar ve yedek yapıştırma kutusu
    Rectangle {
        objectName: "epicSteps"
        visible: !ep.linked && backend.epicWaiting
        Layout.fillWidth: true
        implicitHeight: stepsCol.implicitHeight + 28
        radius: 10
        color: theme.surfaceHigh
        border.color: theme.accent
        ColumnLayout {
            id: stepsCol
            x: 16; y: 14
            width: parent.width - 32
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "Tarayıcında Epic giriş sayfası açıldı"
                color: theme.text
                font.pixelSize: 15
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: [
                    "1. Epic hesabınla giriş yap (Google, Apple, e-posta… hangisiyle istersen).",
                    "2. Girişten sonra içinde kod yazan bir sayfa açılacak. O sayfada Ctrl+A'ya, sonra Ctrl+C'ye bas.",
                    "3. Bu kadar. Program kopyaladığını kendisi görür ve hesabını bağlar, buraya dönmen gerekmez."
                ]
                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    color: theme.text
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            RowLayout {
                spacing: 8
                AppButton { compact: true; text: "Sayfayı tekrar aç"; onClicked: backend.loginEpic() }
                AppButton { compact: true; kind: "ghost"; text: "Vazgeç"; onClicked: backend.cancelEpicLogin() }
            }
            Text {
                Layout.topMargin: 4
                Layout.fillWidth: true
                text: "Kendisi algılamazsa kopyaladığını buraya yapıştır:"
                color: theme.muted
                font.pixelSize: 12
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                AppField {
                    id: codeField
                    Layout.fillWidth: true
                    placeholderText: "Sayfadaki yazı (içinde authorizationCode geçer)"
                    onAccepted: if (text.trim() !== "") connectBtn.clicked()
                }
                AppButton {
                    id: connectBtn
                    kind: "primary"
                    text: "Bağlan"
                    enabled: codeField.text.trim() !== ""
                    onClicked: { ep.busy = true; ep.result = ""; backend.submitEpicCode(codeField.text) }
                }
            }
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
                ep.connected()
            }
        }
    }
}
