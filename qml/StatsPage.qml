import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// İstatistikler: toplam süre, son 14 gün, en çok oynananlar, platformlar
Rectangle {
    id: page
    signal closeRequested()
    property var d: ({})
    color: theme.bg
    onVisibleChanged: if (visible) d = backend.statsData()
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

    component Tile: Rectangle {
        property string value: ""
        property string label: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        radius: 10
        color: theme.surface
        border.color: theme.line
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 2
            Text { text: parent.parent.value; color: theme.text; font.family: theme.displayFont; font.pixelSize: 28; font.weight: Font.Bold }
            Text { text: parent.parent.label; color: theme.muted; font.pixelSize: 13 }
        }
    }
    component Heading: Text { color: theme.text; font.family: theme.displayFont; font.pixelSize: 20; font.weight: Font.Bold; Layout.topMargin: 12 }

    AppButton { id: back; x: 24; y: 10; kind: "ghost"; text: "Rafa dön  (Esc)"; onClicked: page.closeRequested() }

    Flickable {
        anchors.top: back.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: col.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: AppScrollBar {}

        ColumnLayout {
            id: col
            width: Math.min(page.width - 80, 1000)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Text { text: "İstatistikler"; color: theme.text; font.family: theme.displayFont; font.pixelSize: 34; font.weight: Font.Bold }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Tile { value: appRoot.minutesText(page.d.totalMinutes || 0, true); label: "toplam oynama" }
                Tile { value: appRoot.minutesText(page.d.recentMinutes || 0, true); label: "son 14 günde" }
                Tile { value: (page.d.gameCount || 0) + ""; label: "oyun" + (page.d.familyCount ? " (" + page.d.familyCount + " tanesi aileden)" : "") }
                Tile { value: (page.d.installedCount || 0) + ""; label: "kurulu" }
            }

            Heading { text: "Son 14 gün" }
            BarChart {
                Layout.fillWidth: true
                visible: (page.d.recentMinutes || 0) > 0
                items: (page.d.days || []).map(x => ({ label: x.label, value: x.minutes,
                         tip: x.date + ": " + (x.minutes ? appRoot.minutesText(x.minutes) + (x.games ? "\n" + x.games : "") : "oynanmadı") }))
            }
            Text {
                Layout.fillWidth: true
                text: (page.d.recentMinutes || 0) > 0
                      ? (page.d.trackedDays && page.d.trackedDays < 14 ? "Oynama günlüğü " + page.d.since + " tarihinde başladı, grafik her gün biraz daha dolacak." : "")
                      : "Henüz kayıt yok. Program, oynadığın süreyi bugünden itibaren gün gün kaydetmeye başladı. Birkaç gün oynayınca burası dolacak."
                visible: text !== ""
                color: theme.muted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            Heading { text: "En çok oynadıkların" }
            HBarList { Layout.fillWidth: true; items: page.d.top || [] }
            Text { visible: !(page.d.top || []).length; text: "Henüz oynama süresi olan oyun yok."; color: theme.muted; font.pixelSize: 13 }

            Heading { text: "Platformlara göre"; visible: (page.d.platforms || []).length > 1 }
            HBarList {
                Layout.fillWidth: true
                visible: (page.d.platforms || []).length > 1
                items: (page.d.platforms || []).map(p => ({ title: p.name, minutes: p.minutes }))
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 10
                text: "Steam süreleri Steam'den gelir. Epic ve bilgisayarından eklediğin oyunların süresi, oyunu bu programdan açtığında sayılır."
                color: theme.faint
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
}
