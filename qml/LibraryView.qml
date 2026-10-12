import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Kütüphane görünümü: solda oyun listesi, sağda seçili oyunun sayfası
FocusScope {
    id: root
    property alias view: list
    property var selected: null
    property string selectedKey: ""

    function select(g) {
        if (!g) return false
        var i = gamesModel.indexOfKey(g.key)
        if (i < 0) return false
        list.currentIndex = i
        list.positionViewAtIndex(i, ListView.Contain)
        return true
    }

    onSelectedChanged: if (selected) selectedKey = selected.key

    // Liste yenilenince (sıralama, filtre, indirme durumu) seçili oyun aynı kalsın
    Connections {
        target: gamesModel
        function onModelReset() {
            Qt.callLater(function() {
                // arama sonucu boşsa seçili oyun bırakılmaz, sağ taraf sadece gizlenir (boş oyun sayfası açılmaz)
                if (gamesModel.count === 0) return
                var i = root.selectedKey !== "" ? gamesModel.indexOfKey(root.selectedKey) : -1
                list.currentIndex = i >= 0 ? i : 0
                var g = gamesModel.get(list.currentIndex)
                if (g) root.selected = g
                list.positionViewAtIndex(list.currentIndex, ListView.Contain)
            })
        }
    }

    Rectangle {
        id: side
        width: Math.min(320, Math.max(240, root.width * 0.24))
        height: parent.height
        color: theme.surface
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.line }

        ListView {
            id: list
            anchors.fill: parent
            anchors.topMargin: 6
            anchors.rightMargin: 1
            model: gamesModel
            delegate: LibRow {}
            clip: true
            focus: true
            interactive: false      // fareyle sürükleme oyunu rafa taşır; kaydırma tekerlekle
            currentIndex: 0
            onCurrentIndexChanged: { var g = gamesModel.get(currentIndex); if (g) root.selected = g }
            onCountChanged: if (!root.selected && count > 0) root.selected = gamesModel.get(Math.max(0, currentIndex))
            keyNavigationEnabled: true
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 600
            bottomMargin: 12
            ScrollBar.vertical: AppScrollBar {}
            WheelHandler {
                target: null
                onWheel: (ev) => {
                    var dy = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y / 120 * 108
                    var top = list.originY - list.topMargin
                    var bottom = Math.max(top, list.originY + list.contentHeight + list.bottomMargin - list.height)
                    list.contentY = Math.max(top, Math.min(bottom, list.contentY - dy))
                }
            }

            section.property: "group"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                required property string section
                width: list.width
                height: 34
                Text {
                    x: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: parent.section.toLocaleUpperCase(Qt.locale("tr_TR"))
                    color: theme.faint
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
            }

            Keys.onReturnPressed: appRoot.enterOn(root.selected)
            Keys.onEnterPressed: appRoot.enterOn(root.selected)
        }
    }

    DetailPage {
        anchors.left: side.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        embedded: true
        visible: list.count > 0          // arama hiçbir şey bulmazsa sağ taraf boş kalır
        game: root.selected
    }
    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: side.width / 2
        visible: list.count === 0 && backend.search !== ""
        text: "\"" + backend.search + "\" ile eşleşen oyun yok."
        color: theme.muted
        font.pixelSize: 15
    }
}
