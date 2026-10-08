import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Oyunun Steam'deki son duyuruları ve yama notları. Tıklayınca tarayıcıda açılır.
ColumnLayout {
    id: news
    property var items: []
    property bool loading: false
    property bool narrow: false          // yan sütunda: kartlar alt alta, resim üstte
    spacing: 10

    Rectangle { visible: !news.narrow; Layout.fillWidth: true; height: 1; color: theme.line }
    Text {
        text: "Haberler ve güncellemeler"
        color: theme.text
        font.family: theme.displayFont
        font.pixelSize: 20
        font.weight: Font.Bold
    }
    Text { visible: news.loading; text: "Yükleniyor…"; color: theme.muted; font.pixelSize: 13 }

    Repeater {
        model: news.items
        AbstractButton {
            id: card
            required property var modelData
            required property int index
            readonly property bool hasImage: modelData.image !== "" && img.status !== Image.Error
            Layout.fillWidth: true
            // resim yüklenince kart da uzasın (kartlar iç içe geçmesin)
            implicitHeight: news.narrow ? narrowCol.y + narrowCol.implicitHeight + 12
                                        : Math.max(wideCol.implicitHeight + 24, img.visible ? img.height + 24 : 0)
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            Accessible.name: modelData.title
            ToolTip.visible: hovered
            ToolTip.delay: 700
            ToolTip.text: "Tarayıcıda aç"
            onClicked: backend.openLink(modelData.url)
            background: Rectangle {
                radius: 10
                color: card.hovered ? theme.surfaceHigh : theme.surface
                border.width: card.visualFocus ? 2 : 1
                border.color: card.visualFocus ? theme.accent : theme.line
            }

            Image {
                id: img
                x: 12; y: 12
                visible: card.hasImage && status === Image.Ready
                width: news.narrow ? card.width - 24 : 180
                height: news.narrow ? (visible ? width * 0.42 : 0) : 84
                source: card.modelData.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 480
                clip: true
            }

            component Meta: Text {
                color: theme.muted
                font.pixelSize: 12
            }

            // yan sütun düzeni
            ColumnLayout {
                id: narrowCol
                visible: news.narrow
                x: 12
                y: 12 + (img.visible ? img.height + 10 : 0)
                width: card.width - 24
                spacing: 4
                Meta {
                    text: card.modelData.label + "  ·  " + appRoot.dateText(card.modelData.date)
                    color: card.modelData.label === "Yama notları" ? theme.accent : theme.muted
                    font.weight: Font.Bold
                }
                Text { Layout.fillWidth: true; text: card.modelData.title; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; visible: text !== ""; text: card.modelData.text; color: theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
            }

            // geniş düzen: resim solda
            ColumnLayout {
                id: wideCol
                visible: !news.narrow
                x: img.visible ? 12 + img.width + 14 : 14
                y: 12
                width: card.width - x - 14
                spacing: 4
                Meta {
                    text: card.modelData.label + "  ·  " + appRoot.dateText(card.modelData.date)
                    color: card.modelData.label === "Yama notları" ? theme.accent : theme.muted
                    font.weight: Font.Bold
                }
                Text { Layout.fillWidth: true; text: card.modelData.title; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; visible: text !== ""; text: card.modelData.text; color: theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            }
        }
    }
}
