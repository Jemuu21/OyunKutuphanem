import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Onay ve uyarı penceresi
Popup {
    id: dlg
    property string title: ""
    property string message: ""
    property string okText: "Tamam"
    property string cancelText: ""
    property bool danger: false
    property var onOk: null
    property var onCancel: null
    property bool _accepted: false

    function ask(t, m, ok, cancel, isDanger, okFn, cancelFn) {
        title = t; message = m; okText = ok || "Tamam"; cancelText = cancel || ""
        danger = !!isDanger; onOk = okFn || null; onCancel = cancelFn || null
        _accepted = false
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(500, parent ? parent.width - 48 : 500)
    modal: true
    focus: true
    padding: 26
    closePolicy: Popup.CloseOnEscape
    onClosed: if (!_accepted && onCancel) onCancel()

    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }
    enter: Transition { enabled: appRoot.motion; NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }

    contentItem: ColumnLayout {
        spacing: 14
        Text {
            Layout.fillWidth: true
            text: dlg.title
            color: theme.text
            font.family: theme.displayFont
            font.pixelSize: 22
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(msg.implicitHeight, 300)
            clip: true
            Text {
                id: msg
                width: dlg.availableWidth
                text: dlg.message
                color: theme.text
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.15
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            Item { Layout.fillWidth: true }
            AppButton {
                visible: dlg.cancelText !== ""
                text: dlg.cancelText
                onClicked: dlg.close()
            }
            AppButton {
                id: okBtn
                kind: dlg.danger ? "danger" : "primary"
                text: dlg.okText
                focus: true
                onClicked: {
                    dlg._accepted = true
                    dlg.close()
                    if (dlg.onOk) dlg.onOk()
                }
            }
        }
    }
    onOpened: okBtn.forceActiveFocus()
}
