import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Liste görünümü: çok oyunda aramak için yoğun satırlar
FocusScope {
    id: root
    property alias view: list

    RowLayout {
        id: header
        width: parent.width
        height: 30
        spacing: 18
        anchors.left: parent.left
        anchors.leftMargin: 20 + 120 + 18
        anchors.right: parent.right
        anchors.rightMargin: 20
        Text { Layout.fillWidth: true; Layout.minimumWidth: 160; text: "Oyun"; color: theme.faint; font.pixelSize: 12 }
        Text { Layout.preferredWidth: 170; text: "Durum"; color: theme.faint; font.pixelSize: 12 }
        Text { Layout.preferredWidth: 150; text: "Oynama"; color: theme.faint; font.pixelSize: 12 }
        Text { Layout.preferredWidth: 100; text: "Son oynama"; color: theme.faint; font.pixelSize: 12 }
        Item { Layout.preferredWidth: 270 }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        model: gamesModel
        delegate: GameRow {}
        clip: true
        focus: true
        interactive: false      // fareyle sürükleme oyunları taşımak için; kaydırma tekerlek ve kaydırma çubuğuyla
        WheelHandler {
            target: null
            onWheel: (ev) => {
                var dy = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y / 120 * 110
                var top = list.originY - list.topMargin
                var bottom = Math.max(top, list.originY + list.contentHeight + list.bottomMargin - list.height)
                list.contentY = Math.max(top, Math.min(bottom, list.contentY - dy))
            }
        }

        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 800
        bottomMargin: 20
        highlightFollowsCurrentItem: false
        ScrollBar.vertical: AppScrollBar {}

        Keys.onReturnPressed: appRoot.enterOn(currentItem ? currentItem.game : null)
        Keys.onEnterPressed: appRoot.enterOn(currentItem ? currentItem.game : null)
        Keys.onSpacePressed: if (currentItem) appRoot.openDetail(currentItem.game)
    }
}
