import QtQuick
import QtQuick.Controls

// Izgara görünümü: oyunlar raflara dizilir
FocusScope {
    id: root
    property alias view: grid

    GridView {
        id: grid
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(cellWidth, Math.floor((root.width - 20) / cellWidth) * cellWidth)
        cellWidth: 262
        cellHeight: 292
        model: gamesModel
        delegate: GameTile {}
        clip: true
        focus: true
        interactive: false      // fareyle sürükleme oyunları taşımak için; kaydırma tekerlek ve kaydırma çubuğuyla
        WheelHandler {
            target: null
            onWheel: (ev) => {
                var dy = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y / 120 * 110
                var top = grid.originY - grid.topMargin
                var bottom = Math.max(top, grid.originY + grid.contentHeight + grid.bottomMargin - grid.height)
                grid.contentY = Math.max(top, Math.min(bottom, grid.contentY - dy))
            }
        }

        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 600
        topMargin: 4
        bottomMargin: 24
        highlightFollowsCurrentItem: false
        ScrollBar.vertical: AppScrollBar { parent: root; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }

        Keys.onReturnPressed: appRoot.enterOn(currentItem ? currentItem.game : null)
        Keys.onEnterPressed: appRoot.enterOn(currentItem ? currentItem.game : null)
        Keys.onSpacePressed: if (currentItem) appRoot.openDetail(currentItem.game)
        Keys.onMenuPressed: if (currentItem) appRoot.showGameMenu(currentItem.game, currentItem, 30, 140)
    }
}
