.pragma library
// Oyun durumunu ekranda gösterilecek yazıya, renge ve ana butona çevirir.

function pct(g) {
    return g.progress >= 0 ? " %" + Math.floor(g.progress) : ""
}

function statusText(g) {
    if (!g) return ""
    switch (g.state) {
    case "not_installed": return "Kurulu değil"
    case "installed": return g.update ? "Güncelleme var" : "Kurulu"
    case "queued": return g.queuePos > 0 ? g.queuePos + ". sırada" : "Sırada"
    case "downloading": return (g.updating ? "Güncelleniyor" : "İndiriliyor") + pct(g)
    case "paused": return "Durduruldu" + pct(g)
    case "steam_dl": return "Steam indiriyor" + pct(g)
    case "playing": return "Oynanıyor"
    case "busy": return "İşlem sürüyor"
    }
    return ""
}

// "muted", "ok", "accent", "queued", "progress"
function statusKind(g) {
    if (!g) return "muted"
    switch (g.state) {
    case "installed": return g.update ? "accent" : "ok"
    case "queued": return "queued"
    case "downloading": case "steam_dl": return "progress"
    case "paused": return "accent"
    case "playing": return "ok"
    }
    return "muted"
}

function isInstalledLike(g) {
    return g.state === "installed" || g.state === "playing"
        || (g.installPath !== "" && (g.state === "busy" || (g.state === "queued" && g.updating)))
}

// Kapağın ne kadarı renkli görünsün (0 = gri, 1 = tam renkli)
function colorFill(g) {
    if (!g) return 0
    if (g.updating && g.installPath !== "") return 1
    if (g.state === "downloading" || g.state === "paused" || g.state === "steam_dl")
        return Math.max(0, g.progress) / 100
    return isInstalledLike(g) ? 1 : 0
}

// Ana buton: { text, action, enabled, strong }  action = backend'deki komutun adı
// strong = sarı vurgulu buton. Sadece "oynamaya hazır" anlamında: Oyna, Güncelle, Devam et.
function primary(g) {
    if (!g) return { text: "", action: "", enabled: false }
    switch (g.state) {
    case "not_installed": return { text: "İndir", action: "install", enabled: true }
    case "queued": return { text: "Sırada", action: "", enabled: false }
    case "downloading":
        return g.stopping ? { text: "Durduruluyor", action: "", enabled: false }
                          : { text: "Durdur", action: "pause", enabled: true }
    case "paused": return { text: "Devam et", action: "install", enabled: true, strong: true }
    case "steam_dl": return { text: "Steam'de yönet", action: "openSteamDownloads", enabled: true }
    case "installed":
        return (g.update && g.platform === "epic") ? { text: "Güncelle", action: "install", enabled: true, strong: true }
                                                   : { text: "Oyna", action: "play", enabled: true, strong: true }
    case "playing": return { text: "Oyunda", action: "", enabled: false }
    case "busy": return { text: "Bekle", action: "", enabled: false }
    }
    return { text: "", action: "", enabled: false }
}

function sizeOrPlay(g) {
    if (!g) return ""
    if ((g.state === "downloading" || g.state === "playing" || g.state === "busy") && g.info !== "")
        return g.info
    if (g.playtimeText !== "") return g.playtimeText
    return (g.platform === "steam" && g.playKnown) ? "Hiç oynanmadı" : ""
}
