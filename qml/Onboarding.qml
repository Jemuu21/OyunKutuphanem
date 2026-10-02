import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// İlk açılış sihirbazı: Steam'i bağla, Epic'i bağla, rafın hazır
Rectangle {
    id: ob
    property int step: 0
    readonly property int steps: 4
    color: theme.bg

    MouseArea { anchors.fill: parent; onWheel: (w) => w.accepted = true }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(640, parent.width - 48)
        height: Math.min(parent.height - 48, inner.implicitHeight + 64)
        radius: 14
        color: theme.surface
        border.color: theme.line

        Flickable {
            anchors.fill: parent
            anchors.margins: 32
            contentHeight: inner.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: inner
                width: parent.width
                spacing: 16

                RowLayout {   // adım göstergesi (gerçek bir sıra olduğu için numaralı)
                    spacing: 6
                    Repeater {
                        model: ob.steps
                        Rectangle {
                            required property int index
                            width: index === ob.step ? 26 : 10
                            height: 6
                            radius: 3
                            color: index <= ob.step ? theme.accent : theme.shelfEdge
                            Behavior on width { enabled: appRoot.motion; NumberAnimation { duration: 180 } }
                        }
                    }
                    Text { Layout.leftMargin: 8; text: "Adım " + (ob.step + 1) + " / " + ob.steps; color: theme.muted; font.pixelSize: 12 }
                }

                Text {
                    Layout.fillWidth: true
                    text: ["Oyun rafını kuralım", "Steam ile giriş yap", "Epic Games ile giriş yap", "Rafın hazır"][ob.step]
                    color: theme.text
                    font.family: theme.displayFont
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                }

                // 1. adım
                Text {
                    visible: ob.step === 0
                    Layout.fillWidth: true
                    text: "Steam ve Epic oyunlarını tek bir rafta toplayacağız. Kurulu oyunların renkli, kurulu olmayanlar gri durur ve indirdikçe renklenir.\n\nYapman gereken tek şey iki hesabına da giriş yapmak. Bir adımı atlarsan sonra Ayarlar'dan bağlayabilirsin."
                    color: theme.text
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15
                }
                // 2. adım
                SteamPanel {
                    visible: ob.step === 1; Layout.fillWidth: true
                    onConnected: autoNext.restart()     // giriş bitince bir sonraki adıma kendiliğinden geç
                }
                // 3. adım
                EpicPanel {
                    visible: ob.step === 2; Layout.fillWidth: true
                    onConnected: autoNext.restart()
                }
                Timer { id: autoNext; interval: 1400; onTriggered: if (ob.step === 1 || ob.step === 2) ob.step += 1 }
                // 4. adım
                ColumnLayout {
                    visible: ob.step === 3
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: backend.steamConnected ? "Steam bağlı." : "Steam bağlı değil, Ayarlar'dan bağlayabilirsin."
                        color: backend.steamConnected ? theme.ok : theme.muted
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: backend.epicAccount !== "" ? "Epic bağlı (" + backend.epicAccount + ")." : "Epic bağlı değil, Ayarlar'dan bağlayabilirsin."
                        color: backend.epicAccount !== "" ? theme.ok : theme.muted
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        text: "İpuçları: Ctrl+F ile ara, ok tuşlarıyla gez, Enter ile oyna. Bir oyuna sağ tıklayınca ya da üç noktaya basınca daha fazla seçenek çıkar. Bütün kısayollar için F1."
                        color: theme.muted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    AppButton {
                        visible: ob.step > 0 && ob.step < 3
                        kind: "ghost"
                        text: "Geri"
                        onClicked: ob.step -= 1
                    }
                    AppButton {
                        visible: ob.step === 0
                        kind: "ghost"
                        text: "Şimdilik geç"
                        onClicked: backend.finishOnboarding()
                    }
                    Item { Layout.fillWidth: true }
                    AppButton {
                        kind: ob.step === 0 || ob.step === 3 ? "primary"
                            : ((ob.step === 1 && backend.steamConnected) || (ob.step === 2 && backend.epicAccount !== "")) ? "primary" : "secondary"
                        text: ob.step === 0 ? "Başla"
                            : ob.step === 3 ? "Rafı aç"
                            : ((ob.step === 1 && backend.steamConnected) || (ob.step === 2 && backend.epicAccount !== "")) ? "Devam" : "Bu adımı atla"
                        onClicked: ob.step === 3 ? backend.finishOnboarding() : ob.step += 1
                    }
                }
            }
        }
    }
}
