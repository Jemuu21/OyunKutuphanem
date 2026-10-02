import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Tek bir ad soran küçük pencere (yeni raf, rafı yeniden adlandır)
Popup {
    id: nd
    property string title: ""
    property string okText: "Kaydet"
    property var onOk: null
    function ask(t, initial, ok, fn) {
        title = t; okText = ok || "Kaydet"; onOk = fn
        field.text = initial || ""
        open()
    }
    onOpened: { field.forceActiveFocus(); field.selectAll() }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(440, parent ? parent.width - 48 : 440)
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }

    function accept_() {
        if (field.text.trim() === "") return
        var fn = onOk
        close()
        if (fn) fn(field.text.trim())
    }

    contentItem: ColumnLayout {
        spacing: 14
        Text { text: nd.title; color: theme.text; font.family: theme.displayFont; font.pixelSize: 20; font.weight: Font.Bold }
        AppField {
            id: field
            Layout.fillWidth: true
            placeholderText: "Rafın adı, ör. Arkadaşlarla"
            maximumLength: 40
            Keys.onReturnPressed: nd.accept_()
            Keys.onEnterPressed: nd.accept_()
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            AppButton { kind: "ghost"; text: "Vazgeç"; onClicked: nd.close() }
            AppButton { kind: "primary"; text: nd.okText; enabled: field.text.trim() !== ""; onClicked: nd.accept_() }
        }
    }
}
