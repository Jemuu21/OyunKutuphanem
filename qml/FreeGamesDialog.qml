import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Epic'in şu an ücretsiz ve sıradaki oyunları
Popup {
    id: dlg
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(680, parent ? parent.width - 48 : 680)
    height: Math.min(implicitHeight, parent ? parent.height - 48 : 700)
    modal: true
    focus: true
    padding: 26
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: theme.overlay }
    background: Rectangle { radius: 14; color: theme.surface; border.color: theme.line }

    readonly property var nowGames: backend.freeGames.filter(g => g.when === "now")
    readonly property var nextGames: backend.freeGames.filter(g => g.when === "next")

    component GameLine: RowLayout {
        id: line
        property var g
        spacing: 16
        Layout.fillWidth: true
        Rectangle {
            Layout.preferredWidth: 168
            Layout.preferredHeight: 94
            color: theme.coverEmpty
            clip: true
            Image {
                anchors.fill: parent
                source: line.g.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 340
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { Layout.fillWidth: true; text: line.g.title; color: theme.text; font.pixelSize: 16; font.weight: Font.Bold; wrapMode: Text.WordWrap }
            Text { text: line.g.dateText; color: theme.muted; font.pixelSize: 13 }
            Text { visible: line.g.owned; text: "Kütüphanende"; color: theme.ok; font.pixelSize: 13; font.weight: Font.Bold }
        }
        AppButton {
            visible: !line.g.owned
            kind: line.g.when === "now" ? "primary" : "secondary"
            text: line.g.when === "now" ? "Mağazada al" : "Mağaza sayfası"
            onClicked: backend.openLink(line.g.url)
        }
    }

    contentItem: Flickable {
        implicitHeight: col.implicitHeight
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
                    text: "Epic'te ücretsiz oyunlar"
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
                AppButton { kind: "ghost"; text: "Kapat"; onClicked: dlg.close() }
            }
            Text {
                Layout.fillWidth: true
                text: "Oyunu almak için mağaza sayfasında 'Al' butonuna basman gerekiyor, Epic bunu sadece kendi sayfasında yaptırıyor. Aldıktan birkaç dakika sonra oyun rafına kendiliğinden gelir."
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Text {
                visible: dlg.nowGames.length === 0 && dlg.nextGames.length === 0
                text: "Şu an listede oyun yok. İnternet bağlantını kontrol et ya da biraz sonra tekrar bak."
                color: theme.muted
                font.pixelSize: 14
            }
            Text { visible: dlg.nowGames.length > 0; text: "Şimdi ücretsiz"; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold; Layout.topMargin: 6 }
            Repeater { model: dlg.nowGames; GameLine { required property var modelData; g: modelData } }
            Text { visible: dlg.nextGames.length > 0; text: "Sıradaki"; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold; Layout.topMargin: 10 }
            Repeater { model: dlg.nextGames; GameLine { required property var modelData; g: modelData } }
        }
    }
}
