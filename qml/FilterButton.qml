import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Üst çubukta tek "Filtre" butonu: platform, sıralama ve "sadece kurulu" bir pencerede.
// Butonun üstünde o an neyin seçili olduğu kısaca yazar.
AbstractButton {
    id: fb
    readonly property var platforms: backend.localCount > 0 ? ["Hepsi", "Steam", "Epic", "Diğer"] : ["Hepsi", "Steam", "Epic"]
    readonly property var sorts: backend.currentShelfIsCustom
                                 ? ["Ada göre", "Son oynanan", "En çok oynanan", "Kurulu olanlar önce", "Rafın sırası"]
                                 : ["Ada göre", "Son oynanan", "En çok oynanan", "Kurulu olanlar önce"]
    readonly property var parts: {
        var p = []
        if (backend.platformFilter > 0) p.push(platforms[backend.platformFilter] || "")
        if (backend.onlyInstalled) p.push("Kurulu")
        if (backend.sortMode > 0 && backend.sortMode < sorts.length) p.push(sorts[backend.sortMode])
        return p
    }
    readonly property bool active: backend.platformFilter > 0 || backend.onlyInstalled
    objectName: "filterButton"
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 28
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: "Filtre ve sıralama"
    onClicked: pop.opened ? pop.close() : pop.open()
    // görünüm ya da açık sayfa değişince pencere kapansın
    readonly property string watchView: backend.viewMode
    readonly property var watchPage: appRoot.detailGame
    onWatchViewChanged: pop.close()
    onWatchPageChanged: pop.close()

    background: Rectangle {
        radius: 8
        color: fb.hovered || pop.opened ? theme.surfaceHigh : theme.surface
        border.width: fb.visualFocus || fb.active ? 2 : 1
        border.color: fb.visualFocus || fb.active ? theme.accent : theme.line
    }
    contentItem: Item {
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Column {   // süzgeç simgesi: üç kısalan çizgi
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Repeater {
                    model: [14, 10, 6]
                    Rectangle { required property int modelData; width: modelData; height: 2; radius: 1; color: theme.text; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: fb.parts.length ? fb.parts.join(" · ") : "Filtre"
                color: theme.text
                font.family: theme.bodyFont
                font.pixelSize: 14
                font.weight: fb.parts.length ? Font.Bold : Font.Normal
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 240)
            }
        }
    }

    Popup {
        id: pop
        objectName: "filterPopup"
        y: fb.height + 6
        x: Math.min(0, (fb.parent ? fb.parent.width : 0) - fb.x - width)
        width: 340
        padding: 18
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle { radius: 12; color: theme.surface; border.color: theme.line }

        component Label: Text { color: theme.muted; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 0.8 }

        contentItem: ColumnLayout {
            spacing: 10
            Label { text: "PLATFORM" }
            Segmented {
                options: fb.platforms
                current: backend.platformFilter
                onPicked: (i) => backend.platformFilter = i
            }
            Label { text: "SIRALAMA"; Layout.topMargin: 6 }
            Repeater {
                model: fb.sorts
                AbstractButton {
                    id: opt
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 34
                    hoverEnabled: true
                    onClicked: backend.sortMode = index
                    background: Rectangle { radius: 7; color: opt.hovered ? theme.surfaceHigh : "transparent" }
                    contentItem: Row {
                        spacing: 10
                        leftPadding: 8
                        Rectangle {   // seçim noktası
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: "transparent"
                            border.width: 1.5
                            border.color: backend.sortMode === opt.index ? theme.accent : theme.muted
                            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: theme.accent; visible: backend.sortMode === opt.index }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: opt.modelData
                            color: theme.text
                            font.pixelSize: 14
                            font.weight: backend.sortMode === opt.index ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
            ToggleChip {
                Layout.topMargin: 6
                text: "Sadece kurulu oyunlar"
                checked: backend.onlyInstalled
                onToggled: backend.onlyInstalled = checked
            }
            AppButton {
                Layout.alignment: Qt.AlignRight
                visible: fb.active || backend.sortMode > 0
                kind: "ghost"
                compact: true
                text: "Sıfırla"
                onClicked: { backend.platformFilter = 0; backend.onlyInstalled = false; backend.sortMode = backend.currentShelfIsCustom ? 4 : 0 }
            }
        }
    }
}
