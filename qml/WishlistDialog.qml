import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Steam istek listesindeki indirimdeki oyunlar
Popup {
    id: dlg
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(720, parent ? parent.width - 48 : 720)
    height: Math.min(col.implicitHeight + 52, parent ? parent.height - 48 : 700)
    modal: true
    focus: true
    padding: 26
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }

    contentItem: Flickable {
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar {}
        ColumnLayout {
            id: col
            width: parent.width - 12
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "İstek listende indirimde olanlar"
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
                AppButton { kind: "ghost"; text: "Kapat"; onClicked: dlg.close() }
            }
            Text {
                Layout.fillWidth: true
                text: backend.wishTotal > 0
                      ? "İstek listendeki " + backend.wishTotal + " oyundan " + backend.wishDeals.length + " tanesi şu an indirimde. Program 6 saatte bir kontrol ediyor."
                      : "İstek listen henüz okunmadı ya da boş. Steam'e giriş yaptıysan birkaç dakika içinde gelir."
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: backend.wishDeals
                RowLayout {
                    id: line
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 16
                    Rectangle {
                        Layout.preferredWidth: 168
                        Layout.preferredHeight: 79
                        color: theme.coverEmpty
                        clip: true
                        Image { anchors.fill: parent; source: line.modelData.image; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 340 }
                        Rectangle {   // indirim oranı
                            anchors.left: parent.left; anchors.bottom: parent.bottom
                            width: pctText.implicitWidth + 12; height: 22
                            color: theme.ok
                            Text { id: pctText; anchors.centerIn: parent; text: "-%" + line.modelData.pct; color: "#0B1A10"; font.pixelSize: 13; font.weight: Font.Bold }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { Layout.fillWidth: true; text: line.modelData.title; color: theme.text; font.pixelSize: 16; font.weight: Font.Bold; elide: Text.ElideRight }
                        RowLayout {
                            spacing: 8
                            Text { text: line.modelData.final; color: theme.ok; font.pixelSize: 15; font.weight: Font.Bold }
                            Text { text: line.modelData.original; color: theme.muted; font.pixelSize: 13; font.strikeout: true }
                        }
                        Text { visible: line.modelData.dateText !== ""; text: line.modelData.dateText; color: theme.muted; font.pixelSize: 12 }
                    }
                    AppButton { text: "Mağazada aç"; onClicked: backend.openLink(line.modelData.url) }
                }
            }
        }
    }
}
