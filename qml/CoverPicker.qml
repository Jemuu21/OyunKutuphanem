import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// Bir oyunun kapağını değiştir: bilgisayardan resim ya da SteamGridDB önerileri
Popup {
    id: cp
    property var game: null
    property var results: []
    property bool loading: false
    property string error: ""

    function openFor(g) {
        game = g
        results = []
        error = ""
        loading = backend.sgdbKey !== ""
        open()
        if (backend.sgdbKey !== "") backend.searchGridCovers(g.key)
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(760, parent ? parent.width - 48 : 760)
    height: Math.min(col.implicitHeight + 52, parent ? parent.height - 48 : 700)
    modal: true
    focus: true
    padding: 26
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }

    Connections {
        target: backend
        function onGridResults(key, items, err) {
            if (!cp.game || key !== cp.game.key) return
            cp.loading = false
            cp.results = items
            cp.error = err
        }
    }

    FileDialog {
        id: fileDialog
        title: "Kapak resmi seç"
        nameFilters: ["Resimler (*.jpg *.jpeg *.png *.webp *.bmp)"]
        onAccepted: { backend.setCoverFromFile(cp.game.key, selectedFile.toString()); cp.close() }
    }

    contentItem: Flickable {
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: cp.game ? "Kapağı değiştir: " + cp.game.title : ""
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                AppButton { kind: "ghost"; text: "Kapat"; onClicked: cp.close() }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                AppButton { kind: "primary"; text: "Bilgisayarımdan resim seç"; onClicked: fileDialog.open() }
                AppButton {
                    visible: cp.game && cp.game.customCover
                    text: "Varsayılan kapağa dön"
                    onClicked: { backend.resetCover(cp.game.key); cp.close() }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "En iyi görünen resimler yatay olanlardır (yaklaşık 2'ye 1 oranında, örneğin 920x430)."
                color: theme.muted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.line }
            Text { text: "SteamGridDB önerileri"; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold }

            // Anahtar yoksa nasıl alınacağını anlat
            ColumnLayout {
                visible: backend.sgdbKey === ""
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: "SteamGridDB, oyuncuların her oyun için kapak paylaştığı ücretsiz bir site. Önerileri görmek için bir kereliğine ücretsiz anahtar al: siteye Steam hesabınla giriş yap, Ayarlar > API bölümünden anahtarı oluşturup buraya yapıştır."
                    color: theme.muted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    AppField { id: keyField; Layout.fillWidth: true; placeholderText: "SteamGridDB API anahtarı"; echoMode: TextInput.Password }
                    AppButton { text: "Anahtar al"; onClicked: Qt.openUrlExternally("https://www.steamgriddb.com/profile/preferences/api") }
                    AppButton {
                        kind: "primary"; text: "Kaydet"
                        enabled: keyField.text.trim() !== ""
                        onClicked: { backend.saveSgdbKey(keyField.text); cp.loading = true; backend.searchGridCovers(cp.game.key) }
                    }
                }
            }

            Text {
                visible: backend.sgdbKey !== "" && (cp.loading || cp.error !== "" || cp.results.length === 0)
                Layout.fillWidth: true
                text: cp.loading ? "Kapaklar aranıyor…" : cp.error !== "" ? cp.error : "Bu oyun için öneri bulunamadı."
                color: cp.error !== "" ? theme.danger : theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            GridLayout {
                visible: cp.results.length > 0
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: cp.results
                    Rectangle {
                        id: cell
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 215 / 460
                        color: theme.coverEmpty
                        border.width: pick.containsMouse ? 2 : 0
                        border.color: theme.accent
                        Image {
                            anchors.fill: parent
                            anchors.margins: cell.border.width
                            source: cell.modelData.thumb
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 320
                        }
                        MouseArea {
                            id: pick
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { backend.setCoverFromUrl(cp.game.key, cell.modelData.url); cp.close() }
                        }
                    }
                }
            }
        }
    }
}
