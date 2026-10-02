import QtQuick
import QtQuick.Layouts

// Rafta gösterilecek oyun yokken ne yapılacağını söyler
ColumnLayout {
    id: es
    signal openSettings()
    readonly property bool nothingLinked: backend.totalCount === 0 && !backend.steamConnected && backend.epicAccount === ""
    readonly property bool loading: backend.totalCount === 0 && !nothingLinked
    readonly property bool searching: backend.search.trim() !== ""
    spacing: 14

    Shelf { Layout.preferredWidth: 360; Layout.alignment: Qt.AlignHCenter }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: es.nothingLinked ? "Rafın şimdilik boş"
            : es.loading ? "Oyunların rafa diziliyor"
            : es.searching ? "Bu isimde bir oyun yok"
            : "Bu filtrede oyun yok"
        color: theme.text
        font.family: theme.displayFont
        font.pixelSize: 26
        font.weight: Font.Bold
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 520
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: theme.muted
        font.pixelSize: 15
        text: es.nothingLinked ? "Steam ya da Epic hesabını bağla, oyunların burada görünsün."
            : es.loading ? "Liste ilk kez çekiliyor. Çok oyunun varsa bir dakika sürebilir."
            : es.searching ? "\"" + backend.search.trim() + "\" ile eşleşen bir oyun bulamadım. Yazımı kontrol et ya da filtreleri gevşet."
            : "Seçtiğin platformda ya da 'Sadece kurulu' açıkken gösterilecek oyun yok."
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        AppButton { visible: es.nothingLinked; kind: "primary"; text: "Hesaplarımı bağla"; onClicked: es.openSettings() }
        AppButton { visible: es.searching; kind: "primary"; text: "Aramayı temizle"; onClicked: backend.search = "" }
        AppButton {
            visible: !es.nothingLinked && !es.loading
            text: "Filtreleri sıfırla"
            onClicked: { backend.search = ""; backend.platformFilter = 0; backend.onlyInstalled = false }
        }
    }
}
