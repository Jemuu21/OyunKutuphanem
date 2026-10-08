import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Oyunun başarımları: ilerleme çizgisi ve liste. narrow = yan sütunda (açıklama yerine tarih alt satırda)
ColumnLayout {
    id: al
    property var ach: null
    property bool loading: false
    property bool narrow: false
    property bool showAll: false
    readonly property int limit: narrow ? 8 : 6
    spacing: 10

    Rectangle { visible: !al.narrow; Layout.fillWidth: true; height: 1; color: theme.line }
    RowLayout {
        Layout.fillWidth: true
        Text { text: "Başarımlar"; color: theme.text; font.family: theme.displayFont; font.pixelSize: 20; font.weight: Font.Bold }
        Item { Layout.fillWidth: true }
        Text {
            visible: !!al.ach && al.ach.total > 0
            text: al.ach ? al.ach.done + " / " + al.ach.total : ""
            color: theme.muted
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }
    Text { visible: al.loading; text: "Yükleniyor…"; color: theme.muted; font.pixelSize: 13 }
    Text {
        visible: !!al.ach && al.ach.error !== ""
        Layout.fillWidth: true
        text: al.ach ? al.ach.error : ""
        color: theme.muted
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    Rectangle {
        visible: !!al.ach && al.ach.total > 0
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: theme.shelf
        Rectangle {
            width: al.ach && al.ach.total ? parent.width * al.ach.done / al.ach.total : 0
            height: parent.height
            radius: 3
            color: theme.chart
        }
    }
    Repeater {
        model: al.ach && al.ach.items ? (al.showAll ? al.ach.items : al.ach.items.slice(0, al.limit)) : []
        RowLayout {
            id: achRow
            required property var modelData
            readonly property string when: modelData.done ? (modelData.time ? appRoot.dateText(modelData.time) : "Açıldı") : "Kilitli"
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                Layout.preferredWidth: al.narrow ? 36 : 40
                Layout.preferredHeight: al.narrow ? 36 : 40
                Layout.alignment: Qt.AlignTop
                radius: 6
                color: theme.shelf
                clip: true
                Image {
                    anchors.fill: parent
                    source: achRow.modelData.icon
                    asynchronous: true
                    sourceSize.width: 80
                    opacity: achRow.modelData.done ? 1 : 0.6
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: achRow.modelData.name
                    color: achRow.modelData.done ? theme.text : theme.muted
                    font.pixelSize: al.narrow ? 13 : 14
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: al.narrow ? achRow.when : achRow.modelData.desc
                    color: al.narrow && achRow.modelData.done ? theme.ok : (al.narrow ? theme.faint : theme.muted)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: !al.narrow
                text: achRow.when
                color: achRow.modelData.done ? theme.ok : theme.faint
                font.pixelSize: 12
            }
        }
    }
    AppButton {
        visible: !!al.ach && !!al.ach.items && al.ach.items.length > al.limit
        kind: "ghost"
        text: al.showAll ? "Daha az göster" : "Hepsini göster (" + (al.ach ? al.ach.items.length : 0) + ")"
        onClicked: al.showAll = !al.showAll
    }
}
