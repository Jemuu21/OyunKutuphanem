import QtQuick
import QtQuick.Controls

// Bir oyunun "daha fazla" menüsü (kartta ⋯ butonu ya da sağ tık)
AppMenu {
    id: menu
    property var game: null
    readonly property bool has: !!game
    readonly property bool epic: has && game.platform === "epic"
    readonly property bool canUninstall: has && game.state === "installed"
    readonly property bool local: has && game.platform === "local"

    AppMenuItem { text: "Ayrıntılar"; onTriggered: appRoot.openDetail(menu.game) }
    AppMenuItem {
        text: "Oyna"
        visible: menu.epic && menu.game.state === "installed" && menu.game.update
        onTriggered: backend.play(menu.game.key)
    }
    AppMenuItem {
        text: "Sıradan çıkar"
        visible: menu.has && menu.game.state === "queued"
        onTriggered: backend.dequeue(menu.game.key)
    }
    AppMenuItem {
        text: "İndirmeyi iptal et"
        visible: menu.has && (menu.game.state === "paused" || menu.game.state === "downloading" || menu.game.state === "queued")
        onTriggered: appRoot.askCancel(menu.game)
    }
    AppMenuItem {
        text: "Oyun klasörünü aç"
        visible: menu.has && (menu.game.installPath !== "" || menu.game.state === "downloading" || menu.game.state === "paused")
        onTriggered: backend.openFolder(menu.game.key)
    }
    AppMenuItem {
        text: "Bulut kayıtlarını eşitle"
        visible: menu.epic && menu.game.cloud && menu.game.state === "installed"
        onTriggered: backend.syncSaves(menu.game.key)
    }
    AppMenuItem {
        text: "Steam mağaza sayfası"
        visible: menu.has && !menu.epic
        onTriggered: backend.openStore(menu.game.key)
    }
    AppMenuItem { text: "Rafa ekle…"; onTriggered: shelfPick.openFor(menu.game) }
    AppMenuItem {
        text: "Bu raftan çıkar"
        visible: backend.currentShelfIsCustom
        onTriggered: backend.removeFromShelf(backend.currentShelf, menu.game.key)
    }
    AppMenuItem { text: "Kapağı değiştir…"; onTriggered: coverPicker.openFor(menu.game) }
    AppMenuSeparator {}
    AppMenuItem {
        text: menu.has && menu.game.favorite ? "Favorilerden çıkar" : "Favorilere ekle"
        onTriggered: backend.toggleFavorite(menu.game.key)
    }
    AppMenuItem {
        text: menu.has && menu.game.hidden ? "Raftan gizlemeyi kaldır" : "Raftan gizle"
        onTriggered: backend.toggleHidden(menu.game.key)
    }
    AppMenuSeparator { visible: menu.canUninstall }
    AppMenuItem { text: "Adını değiştir…"; visible: menu.local; onTriggered: localDialog.openRename(menu.game) }
    AppMenuItem {
        text: menu.local ? "Raftan kaldır" : "Kaldır"
        danger: true
        visible: menu.canUninstall
        onTriggered: appRoot.askUninstall(menu.game)
    }
}
