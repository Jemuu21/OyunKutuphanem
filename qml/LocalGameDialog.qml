import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

// Kendi oyununu (ya da başka bir programı) rafa ekle, ya da adını değiştir
Popup {
    id: lg
    property string fileUrl: ""
    property var renameGame: null
    function openAdd() { renameGame = null; fileUrl = ""; nameField.text = ""; open(); fileDialog.open() }
    function openRename(g) { renameGame = g; fileUrl = ""; nameField.text = g.title; open(); nameField.forceActiveFocus() }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(560, parent ? parent.width - 48 : 560)
    modal: true
    focus: true
    padding: 26
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }

    FileDialog {
        id: fileDialog
        title: "Oyunun dosyasını seç"
        nameFilters: ["Oyunlar ve kısayollar (*.exe *.lnk *.url *.bat)", "Bütün dosyalar (*)"]
        onAccepted: {
            lg.fileUrl = selectedFile.toString()
            if (nameField.text.trim() === "") {
                var n = decodeURIComponent(lg.fileUrl.split("/").pop())
                nameField.text = n.replace(/\.(exe|lnk|url|bat)$/i, "")
            }
            nameField.forceActiveFocus()
            nameField.selectAll()
        }
        onRejected: if (lg.fileUrl === "" && !lg.renameGame) lg.close()
    }

    contentItem: ColumnLayout {
        spacing: 14
        Text {
            text: lg.renameGame ? "Adını değiştir" : "Kendi oyununu ekle"
            color: theme.text
            font.family: theme.displayFont
            font.pixelSize: 22
            font.weight: Font.Bold
        }
        Text {
            visible: !lg.renameGame
            Layout.fillWidth: true
            text: "Steam ya da Epic dışındaki bir oyunu (veya programı) rafına koyabilirsin. Oyunun .exe dosyasını ya da masaüstü kısayolunu seç. Dosyalarına dokunulmaz, sadece rafta görünür."
            color: theme.muted
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        RowLayout {
            visible: !lg.renameGame
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: lg.fileUrl === "" ? "Dosya seçilmedi" : decodeURIComponent(lg.fileUrl.replace("file:///", "").replace("file://", ""))
                color: lg.fileUrl === "" ? theme.faint : theme.text
                font.pixelSize: 13
                elide: Text.ElideMiddle
            }
            AppButton { text: "Dosya seç"; onClicked: fileDialog.open() }
        }
        AppField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Rafta görünecek ad"
            Keys.onReturnPressed: okBtn.clicked()
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            AppButton { kind: "ghost"; text: "Vazgeç"; onClicked: lg.close() }
            AppButton {
                id: okBtn
                kind: "primary"
                text: lg.renameGame ? "Kaydet" : "Rafa ekle"
                enabled: nameField.text.trim() !== "" && (lg.renameGame || lg.fileUrl !== "")
                onClicked: {
                    if (lg.renameGame) backend.renameLocalGame(lg.renameGame.key, nameField.text)
                    else backend.addLocalGame(lg.fileUrl, nameField.text)
                    lg.close()
                }
            }
        }
    }
}
