import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bir oyunu raflara ekle / raflardan çıkar
Popup {
    id: sp
    property var game: null
    property var inShelves: []
    function openFor(g) { game = g; inShelves = backend.shelvesOf(g.key); newField.text = ""; open() }
    function refresh() { if (game) inShelves = backend.shelvesOf(game.key) }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent ? parent.width - 48 : 440)
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }
    Connections { target: backend; function onShelfChanged() { sp.refresh() } }

    contentItem: ColumnLayout {
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: sp.game ? sp.game.title + " hangi raflarda olsun?" : ""
            color: theme.text
            font.family: theme.displayFont
            font.pixelSize: 20
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
        }
        Text {
            visible: backend.shelves.length === 0
            text: "Henüz rafın yok. Aşağıdan ilkini oluştur."
            color: theme.muted
            font.pixelSize: 13
        }
        Repeater {
            model: backend.shelves
            ToggleChip {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name
                checked: sp.inShelves.indexOf(modelData.id) >= 0
                onToggled: checked ? backend.addToShelf(modelData.id, sp.game.key) : backend.removeFromShelf(modelData.id, sp.game.key)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            AppField {
                id: newField
                Layout.fillWidth: true
                placeholderText: "Yeni raf adı"
                maximumLength: 40
                Keys.onReturnPressed: createBtn.clicked()
            }
            AppButton {
                id: createBtn
                text: "Oluştur ve ekle"
                enabled: newField.text.trim() !== ""
                onClicked: { backend.addShelf(newField.text, sp.game.key); newField.text = "" }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            AppButton { kind: "primary"; text: "Tamam"; onClicked: sp.close() }
        }
    }
}
