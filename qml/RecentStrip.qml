import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "state.js" as S

// Rafın en üstünde: son oynadığın oyunlar, büyük görsellerle. Tıklayınca sayfası, butonla direkt oyna.
Item {
    id: rs
    implicitHeight: col.implicitHeight + 18
    readonly property var games: backend.recentGames
    readonly property int count: Math.max(1, Math.min(games.length, Math.floor((width - 28) / 250)))
    readonly property real cardW: (width - 28 - (count - 1) * 14) / count

    ColumnLayout {
        id: col
        x: 14
        y: 8
        width: rs.width - 28
        spacing: 10
        Text {
            text: "Son oynadıkların"
            color: theme.text
            font.family: theme.displayFont
            font.pixelSize: 20
            font.weight: Font.Bold
        }
        Row {
            spacing: 14
            Repeater {
                model: rs.games.slice(0, rs.count)
                AbstractButton {
                    id: card
                    required property var modelData
                    readonly property var g: modelData
                    readonly property var p: S.primary(g)
                    width: rs.cardW
                    height: Math.round(rs.cardW * 215 / 460) + 0
                    hoverEnabled: true
                    Accessible.name: g.title
                    onClicked: appRoot.openDetail(card.g)
                    scale: hovered && appRoot.motion ? 1.02 : 1
                    Behavior on scale { NumberAnimation { duration: 140 } }
                    background: Item {}
                    contentItem: Item {
                        CoverArt { anchors.fill: parent; game: card.g; highlighted: card.hovered && !appRoot.motion }
                        Rectangle {   // alt kısmı karart: yazı okunsun
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: parent.height * 0.6
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: "#E6000000" }
                            }
                        }
                        ColumnLayout {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 12
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text { Layout.fillWidth: true; text: card.g.title; color: "#FFFFFF"; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: card.g.lastPlayedText; color: "#D0D6DC"; font.pixelSize: 12; elide: Text.ElideRight }
                                }
                                AppButton {
                                    visible: card.hovered || card.p.action !== "play"
                                    compact: true
                                    kind: card.p.strong ? "primary" : "secondary"
                                    text: card.p.text
                                    enabled: card.p.enabled
                                    onClicked: appRoot.runAction(card.g, card.p.action)
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            Layout.topMargin: 8
            text: "Bütün oyunlar"
            color: theme.text
            font.family: theme.displayFont
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }
}
