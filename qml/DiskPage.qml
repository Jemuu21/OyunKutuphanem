import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Disk alanı: sürücüler ve kurulu oyunların kapladığı yer, büyükten küçüğe
Rectangle {
    id: page
    property bool onlyStale: false
    signal closeRequested()
    color: theme.bg

    readonly property var games: backend.diskGames
    readonly property real biggest: games.length ? Math.max(1, games[0].sizeBytes) : 1
    // Hiç oynanmamış: Steam oynama süresi 0. Son oynama tarihi bilinmiyorsa "eski" sayma.
    function never(g) { return !g.lastPlayed && g.platform === "steam" && g.playKnown && g.playtime === 0 }
    function stale(g) {
        if (!g.lastPlayed) return never(g)
        return (Date.now() / 1000 - g.lastPlayed) > 90 * 86400
    }
    function playNote(g) {
        if (never(g)) return "hiç açılmadı"
        if (!g.lastPlayed) return "son oynama bilinmiyor"
        return stale(g) ? "3 aydan uzun süredir açılmadı" : "son: " + g.lastPlayedText
    }
    readonly property var shown: onlyStale ? games.filter(g => stale(g)) : games

    function updateTotal() {
        var t = backend.diskTotalText()
        total.text = t !== "" ? "Kurulu " + games.length + " oyun toplam " + t + " yer kaplıyor." : ""
    }
    onVisibleChanged: if (visible) backend.refreshDisk()
    Connections { target: backend; function onDiskChanged() { page.updateTotal() } }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

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
            width: Math.min(page.width - 80, 1100)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Text { text: "Disk alanı"; color: theme.text; font.family: theme.displayFont; font.pixelSize: 34; font.weight: Font.Bold }
            Text {
                id: total
                Layout.fillWidth: true
                color: theme.muted
                font.pixelSize: 14
                text: ""
            }

            // ---- sürücüler
            Flow {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: backend.diskDrives
                    Rectangle {
                        id: drive
                        required property var modelData
                        width: 340
                        height: 96
                        radius: 10
                        color: theme.surface
                        border.color: drive.modelData.low ? theme.danger : theme.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: drive.modelData.name; color: theme.text; font.pixelSize: 16; font.weight: Font.Bold
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    text: drive.modelData.freeText + " boş / " + drive.modelData.totalText
                                    color: drive.modelData.low ? theme.danger : theme.muted
                                    font.pixelSize: 13
                                }
                            }
                            Rectangle {   // doluluk: oyunlar (vurgu), diğer dosyalar (soluk), boş
                                Layout.fillWidth: true
                                height: 10
                                radius: 5
                                color: theme.shelf
                                clip: true
                                Rectangle { width: parent.width * drive.modelData.usedPart; height: parent.height; radius: 5; color: theme.shelfEdge }
                                Rectangle { width: parent.width * drive.modelData.gamesPart; height: parent.height; radius: 5; color: theme.accent }
                            }
                            Text {
                                text: "Oyunlar: " + drive.modelData.gamesText + " (" + drive.modelData.count + " oyun)"
                                color: theme.muted
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.topMargin: 10
                spacing: 12
                Text { text: "Kurulu oyunlar"; color: theme.text; font.pixelSize: 18; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                ToggleChip {
                    text: "Sadece 3 aydır açılmayanlar"
                    checked: page.onlyStale
                    onToggled: page.onlyStale = checked
                }
            }

            Text {
                visible: page.shown.length === 0
                text: page.onlyStale ? "3 aydır açmadığın kurulu oyun yok." : "Kurulu oyun bulunamadı."
                color: theme.muted
                font.pixelSize: 14
            }

            Repeater {
                model: page.shown
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var g: modelData
                    Layout.fillWidth: true
                    height: 66
                    radius: 8
                    color: rowMouse.containsMouse ? theme.surface : "transparent"
                    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onDoubleClicked: appRoot.openDetail(row.g) }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 16
                        CoverArt { Layout.preferredWidth: 104; Layout.preferredHeight: 48; game: row.g }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 160
                            spacing: 2
                            Text { Layout.fillWidth: true; text: row.g.title; color: theme.text; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight }
                            Text {
                                Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: (row.g.platform === "steam" ? "Steam" : "Epic") + ", " + page.playNote(row.g)
                                color: page.stale(row.g) ? theme.accent : theme.muted
                                font.pixelSize: 12
                            }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 240
                            Layout.maximumWidth: 240
                            spacing: 4
                            Text { text: row.g.sizeText || "boyut bilinmiyor"; color: theme.text; font.pixelSize: 14; font.weight: Font.Bold }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 6
                                radius: 3
                                color: theme.shelf
                                Rectangle { width: parent.width * Math.max(0.01, row.g.sizeBytes / page.biggest); height: parent.height; radius: 3; color: theme.accent }
                            }
                        }
                        AppButton { compact: true; text: "Klasör"; onClicked: backend.openFolder(row.g.key) }
                        AppButton {
                            compact: true; kind: "danger"; text: "Kaldır"
                            enabled: row.g.state === "installed"
                            onClicked: appRoot.askUninstall(row.g)
                        }
                    }
                }
            }
        }
    }
}
