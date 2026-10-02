# -*- coding: utf-8 -*-
"""
Oyun Kütüphanem  (sürüm 3)
Steam ve Epic Games oyunlarını tek bir koleksiyon rafında gösterir.

 - Arayüz: QML (qml/ klasörü). Bu dosya arka planı yönetir.
 - Steam: oyun listesi Steam Web API'den, kurulu oyunlar Steam klasöründen okunur.
          İndirme / oynama / kaldırma Steam istemcisi üzerinden yapılır.
 - Epic:  her şey Legendary (açık kaynak Epic istemcisi) ile yapılır:
          indirme sırası, durdur / devam et, güncelleme, bulut kayıtları,
          Epic Launcher'daki kurulu oyunları içe aktarma.
"""

import hashlib
import json
import math
import multiprocessing
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

# --------------------------------------------------------------------------
# Genel ayarlar
# --------------------------------------------------------------------------
FROZEN = getattr(sys, "frozen", False)          # .exe olarak mı çalışıyoruz?
IS_WINDOWS = sys.platform.startswith("win")
NO_WINDOW = subprocess.CREATE_NO_WINDOW if IS_WINDOWS else 0

APP_ID = "OyunKutuphanem"

# Programın kendi klasörü (kurulu programda burası yazılamayabilir)
APP_DIR = Path(sys.executable).resolve().parent if FROZEN else Path(__file__).resolve().parent
# Programla gelen dosyalar (QML, yazı tipleri, simge). .exe'de paketin içindedir.
RES_DIR = Path(getattr(sys, "_MEIPASS", APP_DIR))


def _read_setting_file(name):
    """SURUM.txt ve guncelleme.txt: # ile başlamayan ilk dolu satır."""
    for folder in (RES_DIR, APP_DIR):
        try:
            for line in (folder / name).read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    return line
        except Exception:
            pass
    return ""


APP_VERSION = _read_setting_file("SURUM.txt") or "0.0"
UPDATE_REPO = _read_setting_file("guncelleme.txt")      # ör. kullaniciadi/OyunKutuphanem


def _user_dirs():
    """Kullanıcının dosyaları: ayarlar ve veriler AppData'da, kapak önbelleği LocalAppData'da."""
    override = os.environ.get("OYUN_KUTUPHANEM_DATA")   # testler için
    if override:
        return Path(override), Path(override) / "onbellek"
    if IS_WINDOWS:
        data = Path(os.environ.get("APPDATA") or Path.home()) / APP_ID
        cache = Path(os.environ.get("LOCALAPPDATA") or Path.home()) / APP_ID
    else:
        data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / APP_ID
        cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / APP_ID
    return data, cache


DATA_DIR, CACHE_ROOT = _user_dirs()
CONFIG_FILE = DATA_DIR / "ayarlar.json"           # Steam anahtarı vb. (kimseyle paylaşma)
DATA_FILE = DATA_DIR / "kutuphane_verisi.json"    # favoriler, gizlenenler, oynama süreleri
LIST_CACHE = CACHE_ROOT / "kutuphane_onbellek.json"  # hızlı açılış için son oyun listesi
CACHE_DIR = CACHE_ROOT / "kapak_onbellek"
COVER_DIR = DATA_DIR / "ozel_kapaklar"            # kullanıcının kendi seçtiği kapaklar
ICON_FILE = RES_DIR / "icon.ico" if (RES_DIR / "icon.ico").exists() else APP_DIR / "icon.ico"
MUTEX_NAME = "OyunKutuphanem-Calisiyor"          # kurulum programı, program açık mı diye buna bakar
LOG_FILE = DATA_DIR / "kayit.log"

import logging
LOG = logging.getLogger("oyunkutuphanem")


def mask(text):
    """Kayda yazılan metinden gizli bilgileri ve kullanıcı adını çıkarır."""
    text = str(text)
    text = re.sub(r"(key|access_token|token|steamid|code|authorizationCode)=([^&\s\"']+)", r"\1=***", text, flags=re.I)
    text = re.sub(r"eyJ[\w-]{10,}\.[\w-]+\.[\w-]+", "***", text)          # jetonlar
    try:
        home = str(Path.home())
        if len(home) > 3:
            text = text.replace(home, "~")
    except Exception:
        pass
    return text


class _MaskFilter(logging.Filter):
    def filter(self, record):
        record.msg = mask(record.getMessage())
        record.args = ()
        return True


def setup_logging():
    import logging.handlers
    import platform
    import traceback
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    h = logging.handlers.RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=1, encoding="utf-8")
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s", "%Y-%m-%d %H:%M:%S"))
    h.addFilter(_MaskFilter())
    LOG.addHandler(h)
    LOG.setLevel(logging.INFO)

    def hook(t, v, tb):
        LOG.error("Beklenmeyen hata:\n" + "".join(traceback.format_exception(t, v, tb)))
    sys.excepthook = hook
    threading.excepthook = lambda a: hook(a.exc_type, a.exc_value, a.exc_traceback)
    LOG.info(f"=== Oyun Kütüphanem {APP_VERSION} açıldı | {platform.platform()} | "
             f"{'kurulu program' if FROZEN else 'kaynak koddan'} | Python {platform.python_version()}")


def format_bytes(n):
    n = float(n or 0)
    if n <= 0:
        return ""
    gb = n / 1024 ** 3
    if gb >= 1024:
        return f"{gb / 1024:.1f} TB".replace(".", ",")
    if gb >= 1:
        return (f"{gb:.1f} GB" if gb < 100 else f"{gb:.0f} GB").replace(".", ",")
    return f"{n / 1024 ** 2:.0f} MB"


def free_space(path):
    """Klasörün bulunduğu diskteki boş yer (klasör yoksa var olan ilk üst klasöre bakar)."""
    import shutil
    p = Path(path) if path else Path.home()
    while not p.exists() and p != p.parent:
        p = p.parent
    try:
        return shutil.disk_usage(p).free
    except Exception:
        return -1


def epic_install_size(app):
    """Epic oyunu kurulunca diskte kaplayacağı yer (bayt). Bilinmiyorsa 0."""
    info = legendary_json("info", app, "--json", timeout=180)
    return int(((info or {}).get("manifest") or {}).get("disk_size") or 0)


def prepare_user_dirs():
    """Klasörleri oluşturur, eski sürümlerin programın yanında bıraktığı dosyaları bir kerelik taşır."""
    import shutil
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    COVER_DIR.mkdir(parents=True, exist_ok=True)
    moves = [(APP_DIR / "ayarlar.json", CONFIG_FILE),
             (APP_DIR / "kutuphane_verisi.json", DATA_FILE),
             (APP_DIR / "kutuphane_onbellek.json", LIST_CACHE)]
    for old, new in moves:
        try:
            if old.exists() and not new.exists():
                shutil.copy2(old, new)
        except Exception:
            pass
    old_cache = APP_DIR / "kapak_onbellek"
    try:
        if old_cache.is_dir() and not any(CACHE_DIR.iterdir()):
            for f in old_cache.glob("*.jpg"):
                shutil.copy2(f, CACHE_DIR / f.name)
    except Exception:
        pass


# --------------------------------------------------------------------------
# Windows açılınca başlatma
# --------------------------------------------------------------------------
RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


def autostart_command():
    if FROZEN:
        return f'"{sys.executable}" --tray'
    pyw = Path(sys.executable).with_name("pythonw.exe")
    exe = pyw if pyw.exists() else Path(sys.executable)
    return f'"{exe}" "{Path(__file__).resolve()}" --tray'


def autostart_enabled():
    if not IS_WINDOWS:
        return False
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY) as k:
            winreg.QueryValueEx(k, APP_ID)
            return True
    except Exception:
        return False


def set_autostart(on):
    if not IS_WINDOWS:
        return False
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, RUN_KEY, 0, winreg.KEY_SET_VALUE) as k:
        if on:
            winreg.SetValueEx(k, APP_ID, 0, winreg.REG_SZ, autostart_command())
        else:
            try:
                winreg.DeleteValue(k, APP_ID)
            except FileNotFoundError:
                pass
    return True

# Alt süreçlerin Türkçe karakterleri bozmaması için
os.environ.setdefault("PYTHONIOENCODING", "utf-8")
os.environ.setdefault("PYTHONUTF8", "1")


def console_python():
    """pythonw.exe ile açıldıysak, komutlar için python.exe'yi kullan."""
    exe = Path(sys.executable)
    if exe.name.lower() == "pythonw.exe":
        alt = exe.with_name("python.exe")
        if alt.exists():
            return str(alt)
    return str(exe)


if FROZEN:
    LEGENDARY = [sys.executable, "--legendary"]  # .exe kendi içindeki Legendary'yi çalıştırır
else:
    LEGENDARY = [console_python(), "-m", "legendary.cli"]


def read_json(path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default


def write_json(path, data):
    tmp = Path(str(path) + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, path)


def load_config():
    cfg = {"steam_api_key": "", "steam_profile": "", "steam_id": "",
           "epic_dir": r"C:\Games" if IS_WINDOWS else str(Path.home() / "Games"),
           "tray_hint_shown": False, "sort": 0,
           "dark": True, "reduce_motion": False, "software_render": False,
           "view": "grid", "onboarded": False,
           "free_notify": True, "auto_update_check": True}
    cfg.update(read_json(CONFIG_FILE, {}))
    return cfg


def format_playtime(minutes):
    if not minutes:
        return ""
    if minutes < 60:
        return f"{int(minutes)} dk oynandı"
    hours = minutes / 60
    return f"{hours:.1f} saat oynandı".replace(".", ",") if hours < 10 else f"{int(hours)} saat oynandı"


def format_last_played(ts):
    if not ts:
        return ""
    days = int((time.time() - ts) // 86400)
    if days <= 0:
        return "bugün"
    if days == 1:
        return "dün"
    if days < 30:
        return f"{days} gün önce"
    if days < 365:
        return f"{days // 30} ay önce"
    return f"{days // 365} yıl önce"


# Oyun durumları (QML de aynı yazıları kullanır)
NOT_INSTALLED = "not_installed"
INSTALLED = "installed"
QUEUED = "queued"                  # Epic: indirme sırasında bekliyor
DOWNLOADING = "downloading"        # Epic: bu program indiriyor
PAUSED = "paused"                  # Epic: durduruldu, devam ettirilebilir
STEAM_DOWNLOADING = "steam_dl"     # Steam: Steam istemcisi indiriyor
PLAYING = "playing"                # Epic: oyun açık
BUSY = "busy"                      # kaldırılıyor, kayıt eşitleniyor vb.


# --------------------------------------------------------------------------
# Steam
# --------------------------------------------------------------------------
def find_steam_path():
    if IS_WINDOWS:
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
                p = Path(winreg.QueryValueEx(k, "SteamPath")[0])
                if p.exists():
                    return p
        except Exception:
            pass
        for p in (r"C:\Program Files (x86)\Steam", r"C:\Program Files\Steam"):
            if Path(p).exists():
                return Path(p)
    else:
        p = Path.home() / ".steam" / "steam"
        if p.exists():
            return p
    return None


def parse_vdf(text):
    """Steam'in .vdf / .acf dosyalarını sözlüğe çevirir (anahtarlar küçük harf)."""
    tokens = re.findall(r'"((?:\\.|[^"\\])*)"|([{}])', text)
    root, key = {}, None
    stack = [root]
    for s, brace in tokens:
        if brace == "{":
            d = {}
            if key is not None:
                stack[-1][key] = d
            stack.append(d)
            key = None
        elif brace == "}":
            if len(stack) > 1:
                stack.pop()
        else:
            if key is None:
                key = s.lower()
            else:
                stack[-1][key] = s.replace("\\\\", "\\")
                key = None
    return root


def steam_library_dirs(steam_path):
    dirs = [steam_path / "steamapps"]
    vdf = steam_path / "steamapps" / "libraryfolders.vdf"
    if vdf.exists():
        data = parse_vdf(vdf.read_text(encoding="utf-8", errors="ignore"))
        for k, v in data.get("libraryfolders", {}).items():
            if isinstance(v, dict) and "path" in v:
                p = Path(v["path"]) / "steamapps"
            elif isinstance(v, str) and k.isdigit():
                p = Path(v) / "steamapps"
            else:
                continue
            if p.exists() and p not in dirs:
                dirs.append(p)
    return dirs


def steam_local_state(steam_path):
    """Kurulu / inen Steam oyunlarını appmanifest dosyalarından okur."""
    result = {}
    if not steam_path:
        return result
    for d in steam_library_dirs(steam_path):
        for f in d.glob("appmanifest_*.acf"):
            try:
                st = parse_vdf(f.read_text(encoding="utf-8", errors="ignore")).get("appstate", {})
                appid = st.get("appid") or f.stem.split("_")[-1]
                flags = int(st.get("stateflags", "0") or 0)
                to_dl = int(st.get("bytestodownload", "0") or 0)
                done = int(st.get("bytesdownloaded", "0") or 0)
            except Exception:
                continue
            result[str(appid)] = {
                "name": st.get("name", f"Steam oyunu {appid}"),
                "flags": flags, "to_dl": to_dl, "done": done,
                "path": str(d / "common" / st.get("installdir", "")),
                "size": int(st.get("sizeondisk", "0") or 0),
            }
    return result


def resolve_steam_id(api_key, text):
    import requests
    text = (text or "").strip().rstrip("/")
    m = re.search(r"(7656\d{13})", text)
    if m:
        return m.group(1)
    m = re.search(r"steamcommunity\.com/id/([^/?#]+)", text)
    name = m.group(1) if m else text
    r = requests.get("https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/",
                     params={"key": api_key, "vanityurl": name}, timeout=20)
    if r.status_code in (401, 403):
        raise RuntimeError("Steam API anahtarı geçersiz. Ayarlar'dan kontrol et.")
    data = r.json().get("response", {})
    if data.get("success") == 1:
        return data["steamid"]
    raise RuntimeError("Steam profilin bulunamadı. Ayarlar'a profil linkini doğru yapıştırdığından emin ol.")


def steam_owned_games(api_key, steam_id):
    import requests
    r = requests.get("https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/",
                     params={"key": api_key, "steamid": steam_id, "include_appinfo": 1,
                             "include_played_free_games": 1, "format": "json"}, timeout=30)
    if r.status_code in (401, 403):
        raise RuntimeError("Steam API anahtarı geçersiz. Ayarlar'dan kontrol et.")
    r.raise_for_status()
    games = r.json().get("response", {}).get("games", [])
    return [{"appid": g["appid"], "name": g.get("name") or f"Steam oyunu {g['appid']}",
             "playtime": g.get("playtime_forever", 0), "last": g.get("rtime_last_played", 0)}
            for g in games]


# ---- Steam Aile kütüphanesi -------------------------------------------------
# Steam'in aile servisleri API anahtarıyla değil, mağazaya giriş yapmış kullanıcının
# kısa süreli web jetonuyla çalışır. Jeton bu sayfada görünür (Steam'e giriş yapılı tarayıcıda).
STEAM_TOKEN_PAGE = "https://store.steampowered.com/pointssummary/ajaxgetasyncconfig"


def steam_token_from_text(text):
    text = (text or "").strip()
    m = re.search(r'"webapi_token"\s*:\s*"([^"]+)"', text)
    if m:
        return m.group(1)
    m = re.search(r"(eyJ[\w-]+\.[\w-]+\.[\w-]+)", text)
    return m.group(1) if m else ""


def jwt_payload(token):
    import base64
    try:
        part = token.split(".")[1]
        part += "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part))
    except Exception:
        return {}


def steam_api_get(path, params, timeout=60):
    import requests
    r = requests.get("https://api.steampowered.com/" + path, params=params, timeout=timeout)
    if r.status_code in (401, 403):
        raise RuntimeError("Jetonun süresi dolmuş ya da geçersiz. Sayfayı yenileyip yeni yazıyı yapıştır.")
    r.raise_for_status()
    return (r.json() or {}).get("response", {}) or {}


def steam_fetch_with_token(token):
    """Jetonla kendi oyunlarını ve ailede paylaşılan oyunları çeker. Jeton hiçbir yere kaydedilmez."""
    pl = jwt_payload(token)
    steamid = str(pl.get("sub") or "")
    if not token or not steamid:
        raise RuntimeError("Yapıştırdığın yazıda Steam jetonu bulunamadı. Tarayıcında Steam mağazasına "
                           "giriş yaptığından emin ol, sayfayı yenileyip tekrar kopyala.")
    if pl.get("exp") and pl["exp"] < time.time():
        raise RuntimeError("Bu jetonun süresi dolmuş. Sayfayı yenileyip yeni yazıyı yapıştır.")

    owned = []
    try:
        resp = steam_api_get("IPlayerService/GetOwnedGames/v1/",
                             {"access_token": token, "steamid": steamid, "include_appinfo": 1,
                              "include_played_free_games": 1})
        owned = [{"appid": g["appid"], "name": g.get("name") or f"Steam oyunu {g['appid']}",
                  "playtime": g.get("playtime_forever", 0), "last": g.get("rtime_last_played", 0)}
                 for g in resp.get("games", [])]
    except RuntimeError:
        raise
    except Exception:
        pass   # kendi listesi gelmese de aile listesini denemeye devam

    fam = steam_api_get("IFamilyGroupsService/GetFamilyGroupForUser/v1/", {"access_token": token})
    gid = fam.get("family_groupid")
    in_family = bool(gid) and not fam.get("is_not_member_of_any_group")
    family = []
    if in_family:
        resp = steam_api_get("IFamilyGroupsService/GetSharedLibraryApps/v1/",
                             {"access_token": token, "family_groupid": gid, "include_own": "false",
                              "include_excluded": "false", "include_free": "false",
                              "include_non_games": "false", "language": "turkish", "max_apps": 20000},
                             timeout=120)
        for a in resp.get("apps", []):
            if a.get("exclude_reason") or "appid" not in a:
                continue   # ailede paylaşılamayan oyunlar
            if steamid in [str(o) for o in a.get("owner_steamids", [])]:
                continue   # kendi oyunu, zaten listede
            family.append({"appid": a["appid"], "name": a.get("name") or f"Steam oyunu {a['appid']}"})
    return {"steamid": steamid, "owned": owned, "family": family, "in_family": in_family,
            "updated": int(time.time())}


# ---- Epic'in haftalık ücretsiz oyunları ----------------------------------------
EPIC_FREE_URL = "https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions"
TR_MONTHS = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos",
             "Eylül", "Ekim", "Kasım", "Aralık"]


def _iso_ts(s):
    from datetime import datetime
    return datetime.fromisoformat(str(s).replace("Z", "+00:00")).timestamp()


def tr_date(ts):
    lt = time.localtime(ts)
    return f"{lt.tm_mday} {TR_MONTHS[lt.tm_mon - 1]}"


def epic_free_games():
    """Şu an ücretsiz olan ve sıradaki Epic oyunları."""
    import requests
    r = requests.get(EPIC_FREE_URL, params={"locale": "tr", "country": "TR", "allowCountries": "TR"}, timeout=30)
    r.raise_for_status()
    elements = (((r.json() or {}).get("data") or {}).get("Catalog") or {}).get("searchStore", {}).get("elements") or []
    now = time.time()
    out = []
    for e in elements:
        promos = e.get("promotions") or {}

        def free_offers(kind):
            found = []
            for group in promos.get(kind) or []:
                for o in group.get("promotionalOffers") or []:
                    if (o.get("discountSetting") or {}).get("discountPercentage") == 0:
                        try:
                            found.append((_iso_ts(o["startDate"]), _iso_ts(o["endDate"])))
                        except Exception:
                            pass
            return found

        status = None
        for s, en in free_offers("promotionalOffers"):
            if s <= now < en:
                status = ("now", s, en)
        if not status:
            upcoming = sorted(free_offers("upcomingPromotionalOffers"))
            if upcoming:
                status = ("next",) + upcoming[0]
        if not status or not e.get("title"):
            continue
        slug = None
        for m in ((e.get("catalogNs") or {}).get("mappings") or []) + (e.get("offerMappings") or []):
            if m.get("pageSlug"):
                slug = m["pageSlug"]
                break
        slug = slug or e.get("productSlug")
        imgs = {i.get("type"): i.get("url") for i in e.get("keyImages") or [] if i.get("url")}
        img = (imgs.get("OfferImageWide") or imgs.get("DieselStoreFrontWide") or imgs.get("Thumbnail")
               or next(iter(imgs.values()), ""))
        if img and "epicgames.com" in img and "?" not in img:
            img += "?h=220&w=470&resize=1"
        out.append({"id": e.get("id") or e["title"], "title": e["title"], "namespace": e.get("namespace") or "",
                    "url": f"https://store.epicgames.com/tr/p/{slug}" if slug else "https://store.epicgames.com/tr/free-games",
                    "image": img, "when": status[0], "start": int(status[1]), "end": int(status[2])})
    return out


# ---- Otomatik güncelleme (GitHub Releases) -------------------------------------
def version_tuple(v):
    nums = re.findall(r"\d+", str(v))
    return tuple(int(n) for n in nums) or (0,)


def check_github_update(repo, current):
    """Daha yeni bir sürüm varsa {version, notes, url, size} döndürür, yoksa None."""
    import requests
    r = requests.get(f"https://api.github.com/repos/{repo}/releases/latest",
                     headers={"Accept": "application/vnd.github+json"}, timeout=20)
    if r.status_code == 404:
        return None   # henüz sürüm yayınlanmamış
    r.raise_for_status()
    rel = r.json() or {}
    latest = (rel.get("tag_name") or "").lstrip("vV")
    if not latest or version_tuple(latest) <= version_tuple(current):
        return None
    assets = [a for a in rel.get("assets") or [] if str(a.get("name", "")).lower().endswith(".exe")]
    assets.sort(key=lambda a: "kurulum" not in a["name"].lower())
    if not assets:
        return None
    return {"version": latest, "notes": (rel.get("body") or "").strip()[:2000],
            "url": assets[0]["browser_download_url"], "size": int(assets[0].get("size") or 0),
            "name": assets[0]["name"]}


STEAM_APPDETAILS = "https://store.steampowered.com/api/appdetails"   # oyunun güncel kapak adresi buradan


def steam_header(appid):
    return f"https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/{appid}/header.jpg"


# --------------------------------------------------------------------------
# Epic (Legendary)
# --------------------------------------------------------------------------
def legendary_run(*args, timeout=600):
    return subprocess.run(LEGENDARY + list(args), capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=timeout,
                          creationflags=NO_WINDOW, stdin=subprocess.DEVNULL)


def last_error_line(r, default="bilinmeyen hata"):
    lines = [l for l in (r.stderr or "").strip().splitlines() if "ERROR" in l or "CRITICAL" in l]
    lines = lines or (r.stderr or "").strip().splitlines()
    return lines[-1] if lines else default


def legendary_json(*args, timeout=180):
    r = legendary_run(*args, timeout=timeout)
    out = r.stdout.strip()
    if r.returncode != 0 or not out:
        raise RuntimeError(f"Legendary hatası: {last_error_line(r)}")
    return json.loads(out)


def legendary_tmp_dir():
    if os.environ.get("LEGENDARY_CONFIG_PATH"):
        base = Path(os.environ["LEGENDARY_CONFIG_PATH"])
    elif os.environ.get("XDG_CONFIG_HOME"):
        base = Path(os.environ["XDG_CONFIG_HOME"]) / "legendary"
    else:
        base = Path.home() / ".config" / "legendary"
    return base / "tmp"


def epic_image(game_json):
    imgs = (game_json.get("metadata") or {}).get("keyImages") or []
    by_type = {i.get("type"): i.get("url") for i in imgs if i.get("url")}
    for t in ("DieselGameBox", "OfferImageWide", "DieselStoreFrontWide", "Thumbnail", "DieselGameBoxTall"):
        if by_type.get(t):
            url = by_type[t]
            if "epicgames.com" in url and "?" not in url:
                url += "?h=220&w=470&resize=1"
            return url
    return ""


def epic_is_third_party(game_json):
    attrs = (game_json.get("metadata") or {}).get("customAttributes") or {}
    return bool((attrs.get("ThirdPartyManagedApp") or {}).get("value")
                or (attrs.get("ThirdPartyManagedProvider") or {}).get("value"))


def epic_has_cloud_saves(game_json):
    attrs = (game_json.get("metadata") or {}).get("customAttributes") or {}
    return attrs.get("CloudSaveFolder") is not None


def egl_installed_apps():
    """Epic Games Launcher'ın kendi kurduğu oyunlar: {app_name: klasör}"""
    folder = Path(os.environ.get("PROGRAMDATA", r"C:\ProgramData")) / "Epic" / "EpicGamesLauncher" / "Data" / "Manifests"
    apps = {}
    if not folder.exists():
        return apps
    for f in folder.glob("*.item"):
        try:
            d = json.loads(f.read_text(encoding="utf-8", errors="ignore"))
        except Exception:
            continue
        if d.get("bIsIncompleteInstall") or not d.get("AppName"):
            continue
        if d.get("InstallLocation") and Path(d["InstallLocation"]).exists():
            apps[d["AppName"]] = d["InstallLocation"]
    return apps


def epic_import_from_launcher(installed_names):
    """Epic Launcher'da kurulu olup bizde görünmeyen oyunları içe aktarır. Kaç oyun eklendiğini döndürür."""
    missing = set(egl_installed_apps()) - set(installed_names)
    if not missing:
        return 0
    legendary_run("-y", "egl-sync", "--import-only", "--one-shot", timeout=900)
    after = {i["app_name"] for i in legendary_json("list-installed", "--json")}
    return len(missing & after)


def load_epic():
    status = legendary_json("status", "--json", "--offline")
    if status.get("account", "<not logged in>") == "<not logged in>":
        return {"logged_in": False}
    games = legendary_json("list", "--json", timeout=900)  # bu komut sürüm bilgilerini de günceller
    installed = legendary_json("list-installed", "--json")
    imported = 0
    try:
        imported = epic_import_from_launcher([i["app_name"] for i in installed])
        if imported:
            installed = legendary_json("list-installed", "--json")
    except Exception:
        pass

    slim_games = []
    namespaces = sorted({(info or {}).get("namespace") for g in games
                         for info in (g.get("asset_infos") or {}).values() if (info or {}).get("namespace")})
    for g in games:
        if epic_is_third_party(g):
            continue  # EA / Ubisoft gibi başka launcher isteyen oyunlar
        versions = {p: (info or {}).get("build_version") for p, info in (g.get("asset_infos") or {}).items()}
        slim_games.append({"app_name": g["app_name"], "title": g.get("app_title") or g["app_name"],
                           "image": epic_image(g), "cloud": epic_has_cloud_saves(g), "versions": versions})
    slim_installed = [{"app_name": i["app_name"], "path": i.get("install_path", ""),
                       "version": i.get("version"), "platform": i.get("platform") or "Windows",
                       "size": int(i.get("install_size") or 0)}
                      for i in installed]
    return {"logged_in": True, "account": status.get("account"), "games": slim_games, "namespaces": namespaces,
            "installed": slim_installed, "imported": imported}


def kill_tree(proc):
    """İndirmeyi durdurur. Legendary yan süreçler açtığı için hepsini birlikte kapatır."""
    pid = proc.processId()
    if IS_WINDOWS and pid:
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"],
                       capture_output=True, creationflags=NO_WINDOW)
    else:
        proc.kill()


def wait_for_game(install_path, appear_timeout=120):
    """Oyun klasöründen çalışan bir program açılmasını, sonra da kapanmasını bekler.
    Oynanan süreyi saniye olarak döndürür."""
    import psutil
    base = os.path.normcase(os.path.abspath(install_path)).rstrip("\\/") + os.sep

    def running():
        for p in psutil.process_iter(["exe"]):
            try:
                exe = p.info.get("exe")
                if exe and os.path.normcase(exe).startswith(base):
                    return True
            except Exception:
                pass
        return False

    t0 = time.time()
    while not running():
        if time.time() - t0 > appear_timeout:
            return 0
        time.sleep(3)
    start, misses = time.time(), 0
    while misses < 2:            # oyun bazen yeniden başlar, iki kez üst üste yoksa kapandı say
        time.sleep(5)
        misses = 0 if running() else misses + 1
    return time.time() - start - 5


# --------------------------------------------------------------------------
# .exe modunda Legendary'yi çalıştırma
# --------------------------------------------------------------------------
def _fix_std_streams():
    """Pencereli .exe'de çıktı kanalları yoktur; ana programın verdiği kanallara bağlan."""
    if not IS_WINDOWS:
        return
    import ctypes
    import msvcrt
    k32 = ctypes.windll.kernel32
    k32.GetStdHandle.restype = ctypes.c_void_p
    for name, num, mode in (("stdin", -10, "r"), ("stdout", -11, "w"), ("stderr", -12, "w")):
        if getattr(sys, name) is not None:
            continue
        h = k32.GetStdHandle(num)
        stream = None
        if h and h != ctypes.c_void_p(-1).value:
            try:
                fd = msvcrt.open_osfhandle(h, os.O_RDONLY if mode == "r" else 0)
                stream = open(fd, mode, encoding="utf-8", errors="replace", buffering=1)
            except Exception:
                stream = None
        setattr(sys, name, stream or open(os.devnull, mode))


def run_legendary_mode():
    _fix_std_streams()
    sys.argv = ["legendary"] + sys.argv[2:]
    from legendary.cli import main as legendary_main
    legendary_main()




# ==========================================================================
# Arayüz (QML) ve arka plan yönetimi
# ==========================================================================
def run_gui():
    from PySide6.QtCore import (QAbstractListModel, QByteArray, QModelIndex, QObject, QProcess,
                                Qt, QTimer, QUrl, Property, Signal, Slot)
    from PySide6.QtGui import QDesktopServices, QFont, QFontDatabase, QIcon, QImage
    from PySide6.QtNetwork import (QLocalServer, QLocalSocket, QNetworkAccessManager,
                                   QNetworkReply, QNetworkRequest)
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuick import QQuickWindow, QSGRendererInterface
    from PySide6.QtQuickControls2 import QQuickStyle
    from PySide6.QtWidgets import QApplication, QMenu, QMessageBox, QSystemTrayIcon

    prepare_user_dirs()
    setup_logging()

    def acc(name, default):
        """Değeri değişince QML'e haber veren basit özellik (getter, setter)."""
        attr = "_" + name

        def getter(self):
            return getattr(self, attr, default)

        def setter(self, value):
            if getattr(self, attr, default) != value:
                setattr(self, attr, value)
                self.changed.emit()
        return getter, setter

    # ------------------------------------------------------------ oyun
    class Game(QObject):
        changed = Signal()

        key = Property(str, *acc("key", ""), notify=changed)
        platform = Property(str, *acc("platform", ""), notify=changed)
        gid = Property(str, *acc("gid", ""), notify=changed)
        title = Property(str, *acc("title", ""), notify=changed)
        state = Property(str, *acc("state", NOT_INSTALLED), notify=changed)
        progress = Property(float, *acc("progress", -1.0), notify=changed)   # -1: bilinmiyor
        info = Property(str, *acc("info", ""), notify=changed)
        cover = Property(str, *acc("cover", ""), notify=changed)
        coverGray = Property(str, *acc("coverGray", ""), notify=changed)
        installPath = Property(str, *acc("installPath", ""), notify=changed)
        update = Property(bool, *acc("update", False), notify=changed)
        updating = Property(bool, *acc("updating", False), notify=changed)
        cloud = Property(bool, *acc("cloud", False), notify=changed)
        stopping = Property(bool, *acc("stopping", False), notify=changed)
        favorite = Property(bool, *acc("favorite", False), notify=changed)
        hidden = Property(bool, *acc("hidden", False), notify=changed)
        playtime = Property(int, *acc("playtime", 0), notify=changed)        # dakika
        lastPlayed = Property(int, *acc("lastPlayed", 0), notify=changed)    # unix zamanı
        queuePos = Property(int, *acc("queuePos", 0), notify=changed)
        playKnown = Property(bool, *acc("playKnown", False), notify=changed)  # oynama süresi biliniyor mu
        shared = Property(bool, *acc("shared", False), notify=changed)       # Steam ailesinden paylaşılan oyun
        downloadSize = Property(str, *acc("downloadSize", ""), notify=changed)
        sizeBytes = Property(float, *acc("sizeBytes", 0.0), notify=changed)      # diskte kapladığı yer
        customCover = Property(bool, *acc("customCover", False), notify=changed)  # kapağı kullanıcı seçti
        skyX = Property(float, *acc("skyX", 0.0), notify=changed)
        skyY = Property(float, *acc("skyY", 0.0), notify=changed)
        skySize = Property(float, *acc("skySize", 4.0), notify=changed)
        skyGlow = Property(float, *acc("skyGlow", 0.4), notify=changed)

        def _pt(self):
            return format_playtime(self.playtime)

        def _lp(self):
            return format_last_played(self.lastPlayed)

        playtimeText = Property(str, _pt, notify=changed)
        sizeText = Property(str, lambda self: format_bytes(self.sizeBytes), notify=changed)
        lastPlayedText = Property(str, _lp, notify=changed)

        def __init__(self, platform, gid, title, image_url, parent):
            super().__init__(parent)
            self.platform, self.gid, self.title = platform, str(gid), title
            self.key = f"{platform}:{gid}"
            self.image_url = image_url

        @property
        def id(self):
            return self.gid

    # ------------------------------------------------------------ liste modeli
    class GamesModel(QAbstractListModel):
        GameRole = Qt.ItemDataRole.UserRole + 1
        countChanged = Signal()

        def __init__(self):
            super().__init__()
            self._items = []

        def rowCount(self, parent=QModelIndex()):
            return 0 if parent.isValid() else len(self._items)

        def data(self, index, role=Qt.ItemDataRole.DisplayRole):
            if index.isValid() and role == self.GameRole:
                return self._items[index.row()]
            return None

        def roleNames(self):
            return {self.GameRole: QByteArray(b"game")}

        def set_items(self, items):
            if items == self._items:
                return
            self.beginResetModel()
            self._items = list(items)
            self.endResetModel()
            self.countChanged.emit()

        count = Property(int, lambda self: len(self._items), notify=countChanged)

        @Slot(int, result=QObject)
        def get(self, i):
            return self._items[i] if 0 <= i < len(self._items) else None

    # ------------------------------------------------------------ tema
    PALETTES = {
        True: {   # karanlık: gece rafı
            "bg": "#151B21", "shelf": "#232C35", "shelfEdge": "#323E4A", "shelfShadow": "#0B0F13",
            "surface": "#1C232A", "surfaceHigh": "#252E37", "line": "#2E3944",
            "text": "#E9EDF0", "muted": "#8D99A5", "faint": "#5E6A75",
            "accent": "#E8A93A", "accentHover": "#F2BC5C", "onAccent": "#1E1505",
            "ok": "#6CC48F", "danger": "#E0695C", "queued": "#A8A0E8",
            "coverEmpty": "#1A2027", "overlay": "#CC0B0F13",
        },
        False: {  # aydınlık: gündüz rafı
            "bg": "#E4E9EC", "shelf": "#C9D2D9", "shelfEdge": "#B2BDC6", "shelfShadow": "#9AA6B0",
            "surface": "#F4F6F8", "surfaceHigh": "#FFFFFF", "line": "#C7D0D7",
            "text": "#1C252D", "muted": "#56636F", "faint": "#8592A0",
            "accent": "#A8660A", "accentHover": "#8F5607", "onAccent": "#FFFFFF",
            "ok": "#2F8A55", "danger": "#B5443A", "queued": "#5B4FC4",
            "coverEmpty": "#D3DAE0", "overlay": "#B3E4E9EC",
        },
    }

    class Theme(QObject):
        changed = Signal()

        def __init__(self, dark, display_font, body_font):
            super().__init__()
            self._dark = dark
            self._display, self._body = display_font, body_font

        def set_dark(self, d):
            if d != self._dark:
                self._dark = d
                self.changed.emit()

        def _c(name, sig=changed):
            return Property(str, lambda self: PALETTES[self._dark][name], notify=sig)

        bg, shelf, shelfEdge, shelfShadow = _c("bg"), _c("shelf"), _c("shelfEdge"), _c("shelfShadow")
        surface, surfaceHigh, line = _c("surface"), _c("surfaceHigh"), _c("line")
        text, muted, faint = _c("text"), _c("muted"), _c("faint")
        accent, accentHover, onAccent = _c("accent"), _c("accentHover"), _c("onAccent")
        ok, danger, queued, coverEmpty, overlay = _c("ok"), _c("danger"), _c("queued"), _c("coverEmpty"), _c("overlay")
        dark = Property(bool, lambda self: self._dark, notify=changed)
        displayFont = Property(str, lambda self: self._display, constant=True)
        bodyFont = Property(str, lambda self: self._body, constant=True)

    # ------------------------------------------------------------ arka plan işleri
    class Invoker(QObject):
        """Arka plandaki işin sonucunu ana iş parçacığına güvenle taşır."""
        call = Signal(object)

        def __init__(self):
            super().__init__()
            self.call.connect(self._run)

        def _run(self, fn):
            fn()

    # ------------------------------------------------------------ ana yönetici
    class Backend(QObject):
        changed = Signal()          # ayarlar / filtreler / durum yazıları
        gamesChanged = Signal()     # oyun kümesi değişti (gökyüzü için)
        toast = Signal(str, str)    # mesaj, tür (info / ok / error)
        alert = Signal(str, str)    # başlık, mesaj
        steamResult = Signal(bool, str)
        familyResult = Signal(bool, str)
        freeChanged = Signal()
        diskChanged = Signal()
        gridResults = Signal(str, "QVariantList", str)      # oyun, kapak önerileri, hata
        spaceProblem = Signal(str, str, str, str)           # oyun, gereken, boş, klasör
        updateChanged = Signal()
        epicLoginResult = Signal(bool, str)
        showWindowRequested = Signal()
        hideWindowRequested = Signal()
        confirmQuitRequested = Signal()

        def __init__(self, app, theme, model, tray_ok):
            super().__init__()
            self.app, self.theme, self.model = app, theme, model
            self.cfg = load_config()
            self.data = {"favorites": [], "hidden": [], "epic_play": {}}
            self.data.update(read_json(DATA_FILE, {}))
            self.invoker = Invoker()
            self.net = QNetworkAccessManager(self)
            self.steam_path = find_steam_path()
            self.games = {}
            self.epic_proc = None
            self.epic_active = None
            self.queue = []
            self.paused_by_user = set()
            self.epic_loading = False
            self.quitting = False
            self.tray = None
            self._tray_ok = tray_ok

            self._search, self._platformFilter = "", 0
            self._sortMode = int(self.cfg.get("sort", 0))
            self._onlyInstalled, self._showHidden = False, False
            self._steamMsg, self._epicMsg = "Steam: bekleniyor", "Epic: bekleniyor"
            self._epicAccount, self._downloadSummary = "", ""
            self._steamConnected = bool((self.cfg.get("steam_api_key") and self.cfg.get("steam_profile"))
                                        or self.cfg.get("steam_via_token"))
            self._needsOnboarding = (not self.cfg.get("onboarded") and not self.cfg.get("steam_api_key")
                                     and not self.cfg.get("steam_via_token"))
            self._introActive = False
            self._watch = set()          # yeni oyun takibi açık olan platformlar
            self._cancelling = set()     # iptal edilen ve temizlenecek indirmeler
            self._new_batch = []
            self._suppress_new = False   # hesap bağlarken gelen oyunlar "yeni" sayılmasın

            self._relayout_timer = QTimer(self, singleShot=True, interval=30)
            self._relayout_timer.timeout.connect(self._relayout_now)
            self.steam_timer = QTimer(self, interval=3000)
            self.steam_timer.timeout.connect(self.poll_steam_local)
            self.update_timer = QTimer(self, interval=60 * 60 * 1000)
            self.update_timer.timeout.connect(self.load_epic)

        # ======================================================== QML özellikleri
        def _simple(name, cfg_key=None, typ=bool, sig=changed):
            attr = "_" + name

            def getter(self):
                return self.cfg.get(cfg_key) if cfg_key else getattr(self, attr)

            def setter(self, v):
                if cfg_key:
                    if self.cfg.get(cfg_key) == v:
                        return
                    self.cfg[cfg_key] = v
                    write_json(CONFIG_FILE, self.cfg)
                    if cfg_key == "dark":
                        self.theme.set_dark(v)
                else:
                    if getattr(self, attr) == v:
                        return
                    setattr(self, attr, v)
                self.changed.emit()
            return Property(typ, getter, setter, notify=sig)

        def _filter(name, typ, sig=changed):
            attr = "_" + name

            def getter(self):
                return getattr(self, attr)

            def setter(self, v):
                if getattr(self, attr) == v:
                    return
                setattr(self, attr, v)
                if name == "sortMode":
                    self.cfg["sort"] = v
                    write_json(CONFIG_FILE, self.cfg)
                self.changed.emit()
                self.relayout()
            return Property(typ, getter, setter, notify=sig)

        dark = _simple("dark", "dark")
        reduceMotion = _simple("reduceMotion", "reduce_motion")
        softwareRender = _simple("softwareRender", "software_render")
        viewMode = _simple("viewMode", "view", str)
        search = _filter("search", str)
        platformFilter = _filter("platformFilter", int)
        sortMode = _filter("sortMode", int)
        onlyInstalled = _filter("onlyInstalled", bool)
        showHidden = _filter("showHidden", bool)
        steamMsg = _simple("steamMsg", typ=str)
        epicMsg = _simple("epicMsg", typ=str)
        epicAccount = _simple("epicAccount", typ=str)
        downloadSummary = _simple("downloadSummary", typ=str)
        steamConnected = _simple("steamConnected")
        needsOnboarding = _simple("needsOnboarding")
        introActive = _simple("introActive")

        steamKey = Property(str, lambda self: self.cfg.get("steam_api_key", ""), notify=changed)
        steamProfile = Property(str, lambda self: self.cfg.get("steam_profile", ""), notify=changed)
        epicDir = Property(str, lambda self: self.cfg.get("epic_dir", ""), notify=changed)
        totalCount = Property(int, lambda self: len(self.games), notify=gamesChanged)
        allGames = Property("QVariantList", lambda self: list(self.games.values()), notify=gamesChanged)
        isWindows = Property(bool, lambda self: IS_WINDOWS, constant=True)
        # Program bu açılışta ekran kartı olmadan mı çiziyor? (ayar yeniden başlatınca geçerli olur)
        softwareActive = Property(bool, lambda self: bool(getattr(self, "_software_active", False)), constant=True)
        appVersion = Property(str, lambda self: APP_VERSION, constant=True)

        def _family_info(self):
            fam = read_json(LIST_CACHE, {}).get("steam_family") or {}
            if not fam.get("updated"):
                return ""
            when = format_last_played(fam["updated"])
            if not fam.get("in_family"):
                return f"Bir Steam ailesinde görünmüyorsun (son kontrol: {when})."
            return f"Aile kütüphanesi: {len(fam.get('apps', []))} paylaşılan oyun (son güncelleme: {when})."

        familyInfo = Property(str, _family_info, notify=changed)

        # ---- Epic ücretsiz oyunlar
        freeNotify = _simple("freeNotify", "free_notify")

        def _free_list(self):
            out = []
            ns = getattr(self, "_epic_ns", set())
            for f in getattr(self, "_free", []):
                d = dict(f)
                d["owned"] = bool(f.get("namespace")) and f["namespace"] in ns
                d["dateText"] = (f"{tr_date(f['end'])} tarihine kadar ücretsiz" if f["when"] == "now"
                                 else f"{tr_date(f['start'])} tarihinde ücretsiz oluyor")
                out.append(d)
            return out

        def _free_banner(self):
            items = [f for f in self._free_list() if f["when"] == "now" and not f["owned"]]
            ids = sorted(f["id"] for f in items)
            return bool(ids) and ids != sorted(self.data.get("epic_free_dismissed", []))

        def _free_banner_text(self):
            items = [f for f in self._free_list() if f["when"] == "now" and not f["owned"]]
            if not items:
                return ""
            names = ", ".join(f["title"] for f in items)
            return f"Epic'te bu hafta ücretsiz: {names}. {tr_date(min(f['end'] for f in items))} tarihine kadar alabilirsin."

        freeGames = Property("QVariantList", _free_list, notify=freeChanged)
        freeBannerVisible = Property(bool, _free_banner, notify=freeChanged)
        freeBannerText = Property(str, _free_banner_text, notify=freeChanged)

        # ---- Otomatik güncelleme
        autoUpdateCheck = _simple("autoUpdateCheck", "auto_update_check")
        updateEnabled = Property(bool, lambda self: bool(UPDATE_REPO) and (
            (FROZEN and IS_WINDOWS) or bool(os.environ.get("OYUN_KUTUPHANEM_UPDATE_TEST"))), constant=True)
        updateSource = Property(str, lambda self: f"github.com/{UPDATE_REPO}" if UPDATE_REPO else "", constant=True)
        updateState = Property(str, lambda self: getattr(self, "_upd_state", ""), notify=updateChanged)   # "", available, downloading, ready
        updateVersion = Property(str, lambda self: (getattr(self, "_upd", None) or {}).get("version", ""), notify=updateChanged)
        updateNotes = Property(str, lambda self: (getattr(self, "_upd", None) or {}).get("notes", ""), notify=updateChanged)
        updateProgress = Property(float, lambda self: float(getattr(self, "_upd_progress", -1.0)), notify=updateChanged)
        dataFolder = Property(str, lambda self: str(DATA_DIR), constant=True)

        def _get_autostart(self):
            return autostart_enabled()

        def _set_autostart(self, on):
            try:
                set_autostart(bool(on))
            except Exception as e:
                self.toast.emit(f"Başlangıç ayarı değiştirilemedi: {e}", "error")
            self.changed.emit()

        autoStart = Property(bool, _get_autostart, _set_autostart, notify=changed)

        # ======================================================== başlangıç
        def start(self):
            cache = read_json(LIST_CACHE, {})
            if cache.get("steam"):
                self._steam_apply(cache["steam"])
                self._watch.add("steam")
            if cache.get("epic", {}).get("logged_in"):
                self._epic_apply(cache["epic"], from_cache=True)
                self._watch.add("epic")
            self._new_batch = []
            if self.games:
                self._play_intro()
            self._relayout_now()
            self.steam_timer.start()
            self.update_timer.start()
            self.steam_list_timer = QTimer(self, interval=30 * 60 * 1000)
            self.steam_list_timer.timeout.connect(lambda: self.load_steam())
            self.steam_list_timer.start()
            # Epic ücretsiz oyunlar: önce kayıtlı listeyi göster, sonra 6 saatte bir kontrol et
            self._free = read_json(LIST_CACHE, {}).get("epic_free") or []
            self.freeChanged.emit()
            self.free_timer = QTimer(self, interval=6 * 60 * 60 * 1000)
            self.free_timer.timeout.connect(self.checkFreeGames)
            self.free_timer.start()
            QTimer.singleShot(8000, self.checkFreeGames)
            # Güncelleme: açılıştan biraz sonra ve 12 saatte bir
            self.upd_timer = QTimer(self, interval=12 * 60 * 60 * 1000)
            self.upd_timer.timeout.connect(lambda: self.checkUpdates(False))
            self.upd_timer.start()
            QTimer.singleShot(15000, lambda: self.checkUpdates(False))
            if not self.needsOnboarding:
                self.reload_all()

        def _play_intro(self):
            if self.reduceMotion or self.introActive:
                return
            self.introActive = True
            QTimer.singleShot(1400, lambda: setattr(self, "introActive", False))

        def run_background(self, fn, callback):
            def worker():
                try:
                    result, error = fn(), None
                except Exception as e:  # noqa
                    result, error = None, e
                self.invoker.call.emit(lambda: callback(result, error))
            threading.Thread(target=worker, daemon=True).start()

        @Slot()
        def reload_all(self):
            self.load_steam()
            self.load_epic()

        @Slot()
        def finishOnboarding(self):
            self.cfg["onboarded"] = True
            write_json(CONFIG_FILE, self.cfg)
            self.needsOnboarding = False
            self.reload_all()

        def save_data(self):
            write_json(DATA_FILE, self.data)

        def save_list_cache(self, part, value):
            cache = read_json(LIST_CACHE, {})
            cache[part] = value
            try:
                write_json(LIST_CACHE, cache)
            except Exception:
                pass

        def notify(self, text, kind="info"):
            self.toast.emit(text, kind)
            if self.tray and self.tray.isVisible() and getattr(self, "_window_hidden", False):
                self.tray.showMessage("Oyun Kütüphanem", text, QIcon(str(ICON_FILE)), 6000)

        # ======================================================== oyunlar ve sıralama
        def upsert(self, platform, gid, title, image_url="", count_new=True):
            key = f"{platform}:{gid}"
            g = self.games.get(key)
            if g is None:
                g = Game(platform, gid, title, image_url, self)
                g.favorite = key in self.data["favorites"]
                g.hidden = key in self.data["hidden"]
                self.games[key] = g
                self.load_cover(g)
                self._games_dirty = True
                # Bu platformun listesi daha önce yüklendiyse, yeni gelen oyun gerçekten yeni alınmıştır
                if count_new and platform in self._watch:
                    self._new_batch.append(g)
            elif title and g.title != title:
                g.title = title
            return g

        def remove_platform(self, platform, keep_keys):
            for key in [k for k, g in self.games.items() if g.platform == platform and k not in keep_keys]:
                if self.games[key].state in (DOWNLOADING, QUEUED, PLAYING):
                    continue
                self.games.pop(key)   # nesne silinmez, açık bir sayfa onu kullanıyor olabilir
                self._games_dirty = True

        def _flush_new(self, platform):
            """Yenileme sonrası yeni gelen oyunları kaydet ve haber ver."""
            batch = [g for g in self._new_batch if g.platform == platform]
            self._new_batch = [g for g in self._new_batch if g.platform != platform]
            suppress = self._suppress_new
            self._suppress_new = False
            first = platform not in self._watch
            self._watch.add(platform)
            if not batch or suppress or first:
                return
            now = int(time.time())
            lst = [n for n in self.data.get("new_games", []) if now - n.get("ts", 0) < 30 * 86400]
            for g in batch:
                lst.append({"key": g.key, "title": g.title, "ts": now})
            self.data["new_games"] = lst[-20:]
            self.save_data()
            names = ", ".join(g.title for g in batch[:3]) + (f" ve {len(batch) - 3} oyun daha" if len(batch) > 3 else "")
            self.notify(f"Kütüphanene yeni oyun eklendi: {names}", "ok")
            self.changed.emit()

        def _recent_new(self):
            now = time.time()
            return [n for n in self.data.get("new_games", [])
                    if now - n.get("ts", 0) < 3 * 86400 and n.get("key") in self.games]

        def _new_text(self):
            items = self._recent_new()
            if not items:
                return ""
            items = items[::-1]
            text = "Yeni eklendi: " + ", ".join(n["title"] for n in items[:2])
            if len(items) > 2:
                text += f" ve {len(items) - 2} oyun daha"
            return text

        newGamesText = Property(str, _new_text, notify=changed)

        @Slot(result=QObject)
        def latestNewGame(self):
            items = self._recent_new()
            return self.games.get(items[-1]["key"]) if items else None

        def relayout(self):
            self._relayout_timer.start()

        def _relayout_now(self):
            if getattr(self, "_games_dirty", False):
                self._games_dirty = False
                self.gamesChanged.emit()
            q = self._search.strip().casefold()
            plat = {0: None, 1: "steam", 2: "epic"}.get(self._platformFilter)
            mode = self._sortMode

            def sort_key(g):
                fav = 0 if g.favorite else 1
                title = g.title.casefold()
                if mode == 1:
                    return (fav, -(g.lastPlayed or 0), title)
                if mode == 2:
                    return (fav, -(g.playtime or 0), title)
                if mode == 3:
                    return (fav, 1 if g.state == NOT_INSTALLED else 0, title)
                return (fav, title)

            visible = [g for g in self.games.values()
                       if (not q or q in g.title.casefold())
                       and (not plat or g.platform == plat)
                       and (not self._onlyInstalled or g.state != NOT_INSTALLED)
                       and (self._showHidden or not g.hidden)]
            visible.sort(key=sort_key)
            self.model.set_items(visible)

        def _game(self, key):
            return self.games.get(key)

        @Slot(str)
        def toggleFavorite(self, key):
            self._toggle(key, "favorites")

        @Slot(str)
        def toggleHidden(self, key):
            g = self._toggle(key, "hidden")
            if g and g.hidden:
                self.toast.emit(f"{g.title} gizlendi. Menüden 'Gizlenen oyunları göster' ile geri getirebilirsin.", "info")

        def _toggle(self, key, name):
            g = self._game(key)
            if not g:
                return None
            lst = self.data[name]
            if key in lst:
                lst.remove(key)
            else:
                lst.append(key)
            self.save_data()
            g.favorite = key in self.data["favorites"]
            g.hidden = key in self.data["hidden"]
            self.relayout()
            return g

        # ======================================================== kapak görselleri
        @staticmethod
        def _req(url):
            """Ağ isteği: bazı siteler kimliksiz istekleri geri çevirdiği için tarayıcı gibi tanıtır."""
            req = QNetworkRequest(QUrl(url))
            req.setAttribute(QNetworkRequest.Attribute.RedirectPolicyAttribute,
                             QNetworkRequest.RedirectPolicy.NoLessSafeRedirectPolicy)
            req.setRawHeader(b"User-Agent", f"Mozilla/5.0 (Windows NT 10.0; Win64; x64) OyunKutuphanem/{APP_VERSION}".encode())
            return req

        def load_cover(self, g):
            custom = self.data.get("custom_covers", {}).get(g.key)
            if custom and (COVER_DIR / custom).exists() and (COVER_DIR / custom.replace(".jpg", "_gri.jpg")).exists():
                self._set_cover(g, COVER_DIR / custom, COVER_DIR / custom.replace(".jpg", "_gri.jpg"))
                g.customCover = True
                return
            url = g.image_url
            if not url:
                return
            h = hashlib.md5(url.encode()).hexdigest()
            color, gray = CACHE_DIR / f"{h}.jpg", CACHE_DIR / f"{h}_gri.jpg"
            if color.exists() and gray.exists():
                self._set_cover(g, color, gray)
                return
            reply = self.net.get(self._req(url))
            reply.finished.connect(lambda: self._cover_done(reply, g, color, gray))

        def _cover_done(self, reply, g, color, gray):
            url = reply.url().toString()
            if reply.error() != QNetworkReply.NetworkError.NoError and "store_item_assets/steam/apps" in url:
                old = url.replace("shared.cloudflare.steamstatic.com/store_item_assets", "cdn.cloudflare.steamstatic.com")
                r2 = self.net.get(self._req(old))
                r2.finished.connect(lambda: self._cover_done(r2, g, color, gray))
                reply.deleteLater()
                return
            ok_img = False
            if reply.error() != QNetworkReply.NetworkError.NoError:
                code = reply.attribute(QNetworkRequest.Attribute.HttpStatusCodeAttribute)
                LOG.info(f"Kapak alınamadı: {g.title} | {code or reply.errorString()} | {url.split('?')[0]}")
            if reply.error() == QNetworkReply.NetworkError.NoError:
                img = QImage()
                if img.loadFromData(reply.readAll()):
                    if img.width() > 520:
                        img = img.scaledToWidth(520, Qt.TransformationMode.SmoothTransformation)
                    img.save(str(color), "JPG", 90)
                    img.convertToFormat(QImage.Format.Format_Grayscale8).save(str(gray), "JPG", 88)
                    self._set_cover(g, color, gray)
                    ok_img = True
            reply.deleteLater()
            if not ok_img and g.platform == "steam" and not getattr(g, "_asked_store", False):
                # Yeni oyunların kapağı Steam'de kodlu bir adreste duruyor; doğru adresi mağazaya sor
                self._ask_steam_store(g, color, gray)

        def _ask_steam_store(self, g, color, gray):
            g._asked_store = True
            missing = self.data.setdefault("cover_missing", {})
            if time.time() - missing.get(g.id, 0) < 7 * 86400:
                return   # bu hafta zaten sorduk, kapağı yok
            reply = self.net.get(self._req(f"{STEAM_APPDETAILS}?appids={g.id}&filters=basic"))

            def done():
                url = ""
                if reply.error() == QNetworkReply.NetworkError.NoError:
                    try:
                        info = json.loads(bytes(reply.readAll()).decode("utf-8")).get(g.id) or {}
                        data = info.get("data") or {}
                        url = data.get("header_image") or data.get("capsule_image") or ""
                    except Exception:
                        url = ""
                    if not url:
                        missing[g.id] = int(time.time())   # Steam'de de kapağı yok, bir hafta sorma
                        self._save_data_later()
                        LOG.info(f"Steam mağazasında kapak yok: {g.title} ({g.id})")
                else:
                    code = reply.attribute(QNetworkRequest.Attribute.HttpStatusCodeAttribute)
                    LOG.warning(f"Steam mağazası kapak adresini vermedi: {g.title} ({g.id}) | {code or reply.errorString()}")
                reply.deleteLater()
                if url:
                    LOG.info(f"Kapak yeni adresten alınıyor: {g.title}")
                    r2 = self.net.get(self._req(url))
                    r2.finished.connect(lambda: self._cover_done(r2, g, color, gray))
            reply.finished.connect(done)

        def _save_data_later(self):
            if not hasattr(self, "_save_timer"):
                self._save_timer = QTimer(self, singleShot=True, interval=3000)
                self._save_timer.timeout.connect(self.save_data)
            self._save_timer.start()

        @staticmethod
        def _set_cover(g, color, gray):
            g.cover = QUrl.fromLocalFile(str(color)).toString()
            g.coverGray = QUrl.fromLocalFile(str(gray)).toString()

        # ======================================================== Steam
        @Slot(str, str)
        def saveSteam(self, key, profile):
            key, profile = key.strip(), profile.strip()
            if key != self.cfg.get("steam_api_key") or profile != self.cfg.get("steam_profile"):
                self.cfg["steam_id"] = ""
            self.cfg["steam_api_key"], self.cfg["steam_profile"] = key, profile
            write_json(CONFIG_FILE, self.cfg)
            self._suppress_new = True
            self.changed.emit()
            self.load_steam(report=True)

        def load_steam(self, report=False):
            cfg = dict(self.cfg)
            if not cfg.get("steam_api_key") or not cfg.get("steam_profile"):
                # Hesap bağlı değilken de bilgisayarda kurulu Steam oyunlarını göster
                via_token = bool(self.cfg.get("steam_via_token"))
                owned = (read_json(LIST_CACHE, {}).get("steam") or []) if via_token else []
                self.steamConnected = via_token
                first = not any(g.platform == "steam" for g in self.games.values())
                self._steam_apply(owned, local_only=not via_token)
                self._flush_new("steam")
                if first and self.games:
                    self._play_intro()
                self.relayout()
                if report:
                    self.steamResult.emit(False, "API anahtarını ve profil linkini birlikte gir.")
                return
            self.cfg.pop("steam_via_token", None)
            self.steamMsg = "Steam güncelleniyor"

            def job():
                sid = cfg.get("steam_id") or resolve_steam_id(cfg["steam_api_key"], cfg["steam_profile"])
                return sid, steam_owned_games(cfg["steam_api_key"], sid)

            self.run_background(job, lambda r, e: self._steam_loaded(r, e, report))

        def _steam_loaded(self, result, error, report):
            if error:
                LOG.warning(f"Steam listesi alınamadı: {error}")
                self.steamMsg = "Steam: hata"
                if report:
                    self.steamResult.emit(False, str(error))
                else:
                    self.toast.emit(f"Steam: {error}", "error")
                self.poll_steam_local()
                return
            sid, owned = result
            LOG.info(f"Steam listesi geldi: {len(owned)} oyun")
            if sid != self.cfg.get("steam_id"):
                self.cfg["steam_id"] = sid
                write_json(CONFIG_FILE, self.cfg)
            self.steamConnected = True
            first = not any(g.platform == "steam" for g in self.games.values())
            self.save_list_cache("steam", owned)
            self._steam_apply(owned)
            self._flush_new("steam")
            if first and self.games:
                self._play_intro()
            self.relayout()
            if report:
                self.steamResult.emit(True, f"{len(owned)} Steam oyunu bulundu." if owned else
                                      "Bağlandı ama oyun gelmedi. Steam profilinde 'Oyun ayrıntıları' gizli olabilir.")

        # ======================================================== Epic ücretsiz oyunlar
        @Slot()
        def checkFreeGames(self):
            self.run_background(epic_free_games, self._free_loaded)

        def _free_loaded(self, result, error):
            if error or result is None:
                return   # internet yoksa sessizce geç, kayıtlı liste kalır
            self._free = result
            self.save_list_cache("epic_free", result)
            self.freeChanged.emit()
            ns = getattr(self, "_epic_ns", set())
            now_items = [f for f in result if f["when"] == "now"]
            seen = set(self.data.get("epic_free_seen", []))
            fresh = [f for f in now_items if f["id"] not in seen and f.get("namespace") not in ns]
            if fresh and self.freeNotify:
                self.notify("Epic'te bu hafta ücretsiz: " + ", ".join(f["title"] for f in fresh), "ok")
            if now_items:
                self.data["epic_free_seen"] = sorted(seen | {f["id"] for f in now_items})[-200:]
                self.save_data()

        @Slot()
        def dismissFreeBanner(self):
            items = [f for f in self._free_list() if f["when"] == "now" and not f["owned"]]
            self.data["epic_free_dismissed"] = sorted(f["id"] for f in items)
            self.save_data()
            self.freeChanged.emit()

        @Slot(str)
        def openLink(self, url):
            QDesktopServices.openUrl(QUrl(url))
            if "store.epicgames.com" in url:
                # Oyunu aldıysa birkaç dakika sonra Epic listesi yenilensin, oyun rafa gelsin
                QTimer.singleShot(3 * 60 * 1000, self.load_epic)

        # ======================================================== otomatik güncelleme
        def _set_upd(self, state=None, progress=None):
            if state is not None:
                self._upd_state = state
            if progress is not None:
                self._upd_progress = progress
            self.updateChanged.emit()

        @Slot(bool)
        def checkUpdates(self, manual=False):
            if not self.updateEnabled:
                if manual:
                    self.toast.emit("Güncelleme kontrolü sadece kurulu programda çalışır." if UPDATE_REPO else
                                    "Güncelleme kaynağı ayarlanmamış.", "info")
                return
            if not manual and not self.autoUpdateCheck:
                return
            if getattr(self, "_upd_state", "") in ("downloading", "ready"):
                return

            def done(info, error):
                if error:
                    if manual:
                        self.toast.emit(f"Güncelleme kontrol edilemedi: {error}", "error")
                    return
                if not info:
                    if manual:
                        self.toast.emit(f"Program güncel (sürüm {APP_VERSION}).", "ok")
                    return
                first_time = (getattr(self, "_upd", None) or {}).get("version") != info["version"]
                self._upd = info
                self._set_upd("available", -1.0)
                if first_time:
                    self.notify(f"Oyun Kütüphanem {info['version']} hazır. Güncellemek için üstteki şeride bak.", "ok")
            self.run_background(lambda: check_github_update(UPDATE_REPO, APP_VERSION), done)

        @Slot()
        def installUpdate(self):
            info = getattr(self, "_upd", None)
            if not info or getattr(self, "_upd_state", "") == "downloading":
                return
            folder = CACHE_ROOT / "guncelleme"
            target = folder / info["name"]
            self._set_upd("downloading", 0.0)

            def job():
                import requests
                folder.mkdir(parents=True, exist_ok=True)
                for old in folder.glob("*.exe"):
                    try:
                        old.unlink()
                    except Exception:
                        pass
                part = target.with_suffix(".indiriliyor")
                done_bytes, last = 0, 0.0
                with requests.get(info["url"], stream=True, timeout=60) as r:
                    r.raise_for_status()
                    total = int(r.headers.get("Content-Length") or info.get("size") or 0)
                    with open(part, "wb") as f:
                        for chunk in r.iter_content(256 * 1024):
                            f.write(chunk)
                            done_bytes += len(chunk)
                            if total and time.time() - last > 0.3:
                                last = time.time()
                                pct = done_bytes * 100.0 / total
                                self.invoker.call.emit(lambda p=pct: self._set_upd(progress=p))
                if info.get("size") and done_bytes != info["size"]:
                    raise RuntimeError("Dosya eksik indi, tekrar dene.")
                os.replace(part, target)
                return target

            def done(path, error):
                if error:
                    self._set_upd("available", -1.0)
                    self.alert.emit("Güncelleme indirilemedi", f"{error}\n\nİnternet bağlantını kontrol edip tekrar dene.")
                    return
                self._set_upd("ready", 100.0)
                self._launch_installer(path)
            self.run_background(job, done)

        def _launch_installer(self, path):
            if not IS_WINDOWS:
                self.toast.emit(f"Güncelleme indirildi: {path} (kurulum sadece Windows'ta çalışır)", "info")
                return
            # Program kapanınca kurulumu sessizce başlat. Kurulum bitince program kendiliğinden açılır.
            p = str(path).replace("'", "''")
            ps = (f"Wait-Process -Id {os.getpid()} -ErrorAction SilentlyContinue; "
                  f"Start-Process -FilePath '{p}' -ArgumentList '/SILENT','/SP-','/SUPPRESSMSGBOXES','/NORESTART','/NOCANCEL'")
            subprocess.Popen(["powershell", "-NoProfile", "-WindowStyle", "Hidden", "-Command", ps],
                             creationflags=NO_WINDOW, stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.quitNow()

        # ======================================================== sorun bildir
        @Slot()
        def reportProblem(self):
            """Sistem özeti ve kaydın son satırlarını panoya kopyalar."""
            import platform
            from PySide6.QtGui import QGuiApplication
            try:
                lines = LOG_FILE.read_text(encoding="utf-8", errors="replace").splitlines()[-150:]
            except Exception:
                lines = ["(kayıt okunamadı)"]
            steam = sum(1 for g in self.games.values() if g.platform == "steam")
            epic = sum(1 for g in self.games.values() if g.platform == "epic")
            head = [
                f"Oyun Kütüphanem {APP_VERSION} | {platform.platform()} | {'kurulu' if FROZEN else 'kaynak'}",
                f"Steam bağlı: {'evet' if self.steamConnected else 'hayır'} ({steam} oyun) | "
                f"Epic bağlı: {'evet' if self.epicAccount else 'hayır'} ({epic} oyun) | "
                f"Ekran kartı: {'kapalı' if self.softwareActive else 'açık'}",
                "-" * 60,
            ]
            QGuiApplication.clipboard().setText(mask("\n".join(head + lines)))
            LOG.info("Sorun bildirimi panoya kopyalandı")
            self.toast.emit("Kayıt panoya kopyalandı. Claude'a ya da bana yapıştırıp gönderebilirsin.", "ok")

        @Slot()
        def openLogFolder(self):
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(DATA_DIR)))

        def _log_toast(self, msg, kind):
            if kind == "error":
                LOG.warning(f"Uyarı gösterildi: {msg}")

        def _log_alert(self, title, msg):
            LOG.warning(f"Pencere gösterildi: {title} | {msg[:500]}")

        # ======================================================== kapağı kendin seç
        sgdbKey = Property(str, lambda self: self.cfg.get("sgdb_key", ""), notify=changed)

        @Slot(str)
        def saveSgdbKey(self, k):
            self.cfg["sgdb_key"] = k.strip()
            write_json(CONFIG_FILE, self.cfg)
            self.changed.emit()

        def _save_custom_cover(self, g, img):
            if img.isNull():
                self.toast.emit("Bu dosya resim olarak açılamadı.", "error")
                return
            if img.width() > 920:
                img = img.scaledToWidth(920, Qt.TransformationMode.SmoothTransformation)
            name = f"{hashlib.md5(g.key.encode()).hexdigest()}_{int(time.time())}.jpg"   # yeni ad: eski resim önbellekte kalmasın
            self._remove_custom_files(g)
            img.save(str(COVER_DIR / name), "JPG", 92)
            img.convertToFormat(QImage.Format.Format_Grayscale8).save(str(COVER_DIR / name.replace(".jpg", "_gri.jpg")), "JPG", 90)
            self.data.setdefault("custom_covers", {})[g.key] = name
            self.save_data()
            self._set_cover(g, COVER_DIR / name, COVER_DIR / name.replace(".jpg", "_gri.jpg"))
            g.customCover = True
            LOG.info(f"Özel kapak seçildi: {g.title}")
            self.toast.emit(f"{g.title} için kapak değişti.", "ok")

        def _remove_custom_files(self, g):
            old = self.data.get("custom_covers", {}).get(g.key)
            if old:
                for f in (COVER_DIR / old, COVER_DIR / old.replace(".jpg", "_gri.jpg")):
                    try:
                        f.unlink()
                    except Exception:
                        pass

        @Slot(str, str)
        def setCoverFromFile(self, key, file_url):
            g = self._game(key)
            if g:
                path = QUrl(file_url).toLocalFile() if file_url.startswith("file:") else file_url
                self._save_custom_cover(g, QImage(path))

        @Slot(str, str)
        def setCoverFromUrl(self, key, url):
            g = self._game(key)
            if not g:
                return
            reply = self.net.get(self._req(url))

            def done():
                img = QImage()
                if reply.error() == QNetworkReply.NetworkError.NoError and img.loadFromData(reply.readAll()):
                    self._save_custom_cover(g, img)
                else:
                    self.toast.emit("Kapak indirilemedi, başka birini dene.", "error")
                reply.deleteLater()
            reply.finished.connect(done)

        @Slot(str)
        def resetCover(self, key):
            g = self._game(key)
            if not g:
                return
            self._remove_custom_files(g)
            self.data.get("custom_covers", {}).pop(key, None)
            self.save_data()
            g.customCover = False
            g.cover = g.coverGray = ""
            g._asked_store = False
            self.load_cover(g)
            self.toast.emit(f"{g.title} için varsayılan kapağa dönüldü.", "ok")

        @Slot(str)
        def searchGridCovers(self, key):
            g = self._game(key)
            api_key = self.cfg.get("sgdb_key", "")
            if not g or not api_key:
                return

            def job():
                import requests
                base = "https://www.steamgriddb.com/api/v2"
                h = {"Authorization": f"Bearer {api_key}"}
                params = {"dimensions": "460x215,920x430", "types": "static"}
                if g.platform == "steam":
                    r = requests.get(f"{base}/grids/steam/{g.id}", headers=h, params=params, timeout=20)
                else:
                    s = requests.get(f"{base}/search/autocomplete/{requests.utils.quote(g.title)}", headers=h, timeout=20)
                    if s.status_code == 401:
                        raise RuntimeError("SteamGridDB anahtarı geçersiz.")
                    found = (s.json() or {}).get("data") or []
                    if not found:
                        return []
                    r = requests.get(f"{base}/grids/game/{found[0]['id']}", headers=h, params=params, timeout=20)
                if r.status_code == 401:
                    raise RuntimeError("SteamGridDB anahtarı geçersiz. Ayarlar'dan kontrol et.")
                if r.status_code == 404:
                    return []
                r.raise_for_status()
                items = (r.json() or {}).get("data") or []
                return [{"url": i["url"], "thumb": i.get("thumb") or i["url"]} for i in items if i.get("url")][:18]

            def done(result, error):
                if error:
                    LOG.warning(f"SteamGridDB: {error}")
                self.gridResults.emit(key, result or [], str(error) if error else "")
            self.run_background(job, done)

        # ======================================================== disk alanı
        def _disk_drives(self):
            return getattr(self, "_drives", [])

        def _disk_games(self):
            return getattr(self, "_disk_list", [])

        diskDrives = Property("QVariantList", _disk_drives, notify=diskChanged)
        diskGames = Property("QVariantList", _disk_games, notify=diskChanged)

        @Slot()
        def refreshDisk(self):
            import shutil
            games = [g for g in self.games.values()
                     if g.installPath and g.state in (INSTALLED, PLAYING, BUSY, DOWNLOADING, STEAM_DOWNLOADING, PAUSED)]
            games.sort(key=lambda g: -(g.sizeBytes or 0))
            self._disk_list = games
            drives = {}
            folders = [g.installPath for g in games] + [self.cfg.get("epic_dir") or ""]
            if self.steam_path:
                folders += [str(d) for d in steam_library_dirs(self.steam_path)]
            for folder in folders:
                if not folder:
                    continue
                p = Path(folder)
                while not p.exists() and p != p.parent:
                    p = p.parent
                try:
                    usage = shutil.disk_usage(p)
                except Exception:
                    continue
                dev = None
                if IS_WINDOWS and p.anchor:
                    name = p.anchor
                else:
                    try:     # Linux/macOS: diskin bağlandığı klasör
                        dev = os.stat(p).st_dev
                        m = p.resolve()
                        while m != m.parent and os.stat(m.parent).st_dev == dev:
                            m = m.parent
                        name = str(m)
                    except Exception:
                        name = str(p)
                d = drives.setdefault(name, {"name": name.rstrip("\\") or name, "total": usage.total,
                                             "free": usage.free, "games": 0.0, "count": 0,
                                             "_dev": dev if not IS_WINDOWS else None})
            for g in games:
                p = Path(g.installPath)
                key = p.anchor if IS_WINDOWS and p.anchor else None
                if key is None:
                    try:
                        dev = os.stat(p if p.exists() else p.parent).st_dev
                        key = next((k for k, v in drives.items() if v.get("_dev") == dev), None)
                    except Exception:
                        key = None
                if key in drives:
                    drives[key]["games"] += g.sizeBytes or 0
                    drives[key]["count"] += 1
            out = []
            for d in drives.values():
                total = float(d["total"]) or 1.0
                out.append({"name": d["name"], "totalText": format_bytes(d["total"]), "freeText": format_bytes(d["free"]),
                            "gamesText": format_bytes(d["games"]) or "0 GB", "count": d["count"],
                            "gamesPart": min(1.0, d["games"] / total), "usedPart": min(1.0, (d["total"] - d["free"]) / total),
                            "low": d["free"] < 0.1 * d["total"]})
            out.sort(key=lambda d: d["name"])
            self._drives = out
            self.diskChanged.emit()

        @Slot(result=str)
        def diskTotalText(self):
            return format_bytes(sum(g.sizeBytes or 0 for g in getattr(self, "_disk_list", [])))

        @Slot()
        def openSteamTokenPage(self):
            QDesktopServices.openUrl(QUrl(STEAM_TOKEN_PAGE))

        @Slot(str)
        def submitSteamToken(self, text):
            token = steam_token_from_text(text)
            if not token:
                self.familyResult.emit(False, "Yapıştırdığın yazıda jeton bulunamadı. Sayfadaki yazının tamamını kopyala. "
                                              "Jeton boş görünüyorsa önce tarayıcında Steam mağazasına giriş yap.")
                return

            def done(result, error):
                if error:
                    self.familyResult.emit(False, str(error))
                    return
                self.save_list_cache("steam_family", {"apps": result["family"], "in_family": result["in_family"],
                                                      "updated": result["updated"]})
                has_key = bool(self.cfg.get("steam_api_key") and self.cfg.get("steam_profile"))
                if not has_key and result["owned"]:
                    # API anahtarı yoksa kendi oyunlarını da bu jetonla aldık
                    self.save_list_cache("steam", result["owned"])
                    self.cfg["steam_via_token"] = True
                    write_json(CONFIG_FILE, self.cfg)
                self.changed.emit()
                self._suppress_new = True
                self.load_steam()
                parts = []
                if not has_key and result["owned"]:
                    parts.append(f"{len(result['owned'])} kendi oyunun")
                if result["in_family"]:
                    parts.append(f"{len(result['family'])} aile oyunu")
                if parts:
                    self.familyResult.emit(True, " ve ".join(parts) + " rafa eklendi.")
                else:
                    self.familyResult.emit(True, "Bağlandı ama bir Steam ailesinde görünmüyorsun.")
            self.run_background(lambda: steam_fetch_with_token(token), done)

        def _steam_apply(self, owned, local_only=False):
            keys = set()
            for item in owned:
                g = self.upsert("steam", item["appid"], item["name"], steam_header(item["appid"]))
                g.playtime, g.lastPlayed = int(item.get("playtime", 0)), int(item.get("last", 0))
                g.playKnown, g.shared = True, False
                keys.add(g.key)
            own_keys = set(keys)
            family = (read_json(LIST_CACHE, {}).get("steam_family") or {}).get("apps", [])
            for item in family:
                key = f"steam:{item['appid']}"
                if key in own_keys:
                    continue
                g = self.upsert("steam", item["appid"], item["name"], steam_header(item["appid"]), count_new=False)
                g.shared = True
                keys.add(g.key)
            n_family = len(keys) - len(own_keys)
            for appid, st in steam_local_state(self.steam_path).items():
                if appid == "228980":  # Steamworks Common Redistributables
                    continue
                g = self.upsert("steam", appid, st["name"], steam_header(appid))
                keys.add(g.key)
            self.remove_platform("steam", keys)
            n_local = len(keys) - len(own_keys) - n_family   # sadece bilgisayarda kurulu olanlar
            fam_txt = f", {n_family} aile oyunu" if n_family else ""
            if local_only:
                n = n_local
                self.steamMsg = (f"Steam: {n} kurulu oyun{fam_txt} (hesap bağlı değil)" if (n or n_family)
                                 else "Steam bağlı değil")
            else:
                self.steamMsg = (f"Steam: {len(owned)} oyun{fam_txt}" if owned else f"Steam: oyun gelmedi{fam_txt}")
            self.poll_steam_local()

        @Slot()
        def poll_steam_local(self):
            local = steam_local_state(self.steam_path)
            changed = False
            for g in self.games.values():
                if g.platform != "steam" or g.state == BUSY:
                    continue
                st = local.get(g.id)
                old = g.state
                g.sizeBytes = float(st["size"]) if st else 0.0
                if not st:
                    g.state, g.progress, g.installPath = NOT_INSTALLED, -1.0, ""
                elif st["to_dl"] > 0 and st["done"] < st["to_dl"]:
                    g.state = STEAM_DOWNLOADING
                    g.progress = st["done"] * 100.0 / st["to_dl"]
                    g.installPath = st["path"]
                else:
                    g.state, g.progress, g.installPath = INSTALLED, -1.0, st["path"]
                changed |= old != g.state
            if changed:
                self._update_summary()
                if self._onlyInstalled or self._sortMode == 3:
                    self.relayout()

        # ======================================================== Epic: liste
        @Slot()
        def load_epic(self):
            if self.epic_loading:
                return
            self.epic_loading = True
            self.epicMsg = "Epic güncelleniyor"
            self.run_background(load_epic, self._epic_loaded)

        def _epic_loaded(self, result, error):
            self.epic_loading = False
            if error:
                LOG.warning(f"Epic listesi alınamadı: {error}")
                self.epicMsg = "Epic: hata"
                self.toast.emit(f"Epic: {error}", "error")
                return
            if not result["logged_in"]:
                self.epicMsg = "Epic bağlı değil"
                self.epicAccount = ""
                self.save_list_cache("epic", {})
                self.remove_platform("epic", set())
                self.relayout()
                return
            first = not any(g.platform == "epic" for g in self.games.values())
            self.save_list_cache("epic", result)
            self._epic_apply(result)
            self._flush_new("epic")
            if first and self.games:
                self._play_intro()
            if result.get("imported"):
                self.alert.emit("Epic Launcher oyunları eklendi",
                                f"Epic Launcher'da kurulu {result['imported']} oyun bulundu ve içe aktarıldı. "
                                "Bu oyunları tekrar indirmeden buradan oynayabilirsin.")
            self.relayout()

        def _epic_apply(self, result, from_cache=False):
            installed = {i["app_name"]: i for i in result.get("installed", [])}
            tmp = legendary_tmp_dir()
            plays = self.data.get("epic_play", {})
            keys, updates = set(), 0
            for item in result.get("games", []):
                g = self.upsert("epic", item["app_name"], item["title"], item["image"])
                keys.add(g.key)
                g.cloud = bool(item.get("cloud", False))
                p = plays.get(g.id, {})
                g.playtime, g.lastPlayed = int(p.get("minutes", 0)), int(p.get("last", 0))
                if g.state in (DOWNLOADING, QUEUED, PLAYING, BUSY):
                    continue  # şu an bir iş yapılıyor, durumuna dokunma
                inst = installed.get(g.id)
                if inst:
                    g.state, g.progress = INSTALLED, -1.0
                    g.installPath = inst.get("path", "") or ""
                    g.sizeBytes = float(inst.get("size") or 0)
                    latest = item.get("versions", {}).get(inst.get("platform", "Windows"))
                    g.update = bool(latest and inst.get("version") and latest != inst["version"])
                    updates += g.update
                elif (tmp / f"{g.id}.resume").exists():
                    g.state, g.update = PAUSED, False
                    g.installPath = (self.data.get("partial", {}).get(g.id) or {}).get("path", "")
                else:
                    g.state, g.progress, g.update = NOT_INSTALLED, -1.0, False
            self.remove_platform("epic", keys)
            self._epic_ns = set(result.get("namespaces") or [])
            self.freeChanged.emit()
            self.epicAccount = result.get("account") or ""
            msg = f"Epic: {len(keys)} oyun"
            if updates:
                msg += f", {updates} güncelleme var"
            self.epicMsg = msg + (" (güncelleniyor)" if from_cache else "")

        @Slot()
        def importFromLauncher(self):
            if not egl_installed_apps():
                self.alert.emit("Epic Launcher", "Epic Launcher'da kurulu oyun bulunamadı.")
                return
            self.toast.emit("Epic Launcher'daki oyunlar kontrol ediliyor…", "info")
            self.load_epic()

        @Slot()
        def openEpicLoginPage(self):
            QDesktopServices.openUrl(QUrl("https://legendary.gl/epiclogin"))

        @Slot(str)
        def submitEpicCode(self, text):
            m = re.search(r'"authorizationCode"\s*:\s*"([^"]+)"', text or "")
            code = m.group(1) if m else (text or "").strip().strip('"')
            if not code:
                self.epicLoginResult.emit(False, "Önce sayfadaki yazıyı kopyalayıp buraya yapıştır.")
                return

            def job():
                r = legendary_run("auth", "--code", code, "--disable-webview", timeout=120)
                if r.returncode != 0:
                    raise RuntimeError(last_error_line(r, "Giriş başarısız"))

            def done(_, error):
                if error:
                    self.epicLoginResult.emit(False, f"Giriş olmadı: {error}. Kod birkaç dakikada geçersiz olur, "
                                                     "sayfayı yenileyip yeni kodu dene.")
                else:
                    self.epicLoginResult.emit(True, "Epic hesabın bağlandı.")
                    self._suppress_new = True
                    self.load_epic()
            self.run_background(job, done)

        @Slot(str)
        def setEpicDir(self, path):
            if path.startswith("file:"):
                path = QUrl(path).toLocalFile()
            path = str(Path(path)) if path else ""
            if path and path != self.cfg.get("epic_dir"):
                self.cfg["epic_dir"] = path
                write_json(CONFIG_FILE, self.cfg)
                self.changed.emit()

        # ======================================================== Epic: indirme sırası
        def _refresh_queue(self):
            for i, q in enumerate(self.queue):
                q.queuePos = i + 1
            self._update_summary()

        def _update_summary(self):
            parts = []
            if self.epic_active:
                g = self.epic_active
                pct = f" %{g.progress:.0f}" if g.progress >= 0 else ""
                parts.append(f"{g.title} {'güncelleniyor' if g.updating else 'indiriliyor'}{pct}")
            if self.queue:
                parts.append(f"sırada {len(self.queue)} oyun")
            steam_dl = [g for g in self.games.values() if g.state == STEAM_DOWNLOADING]
            if steam_dl:
                parts.append(f"Steam {len(steam_dl)} oyun indiriyor")
            self.downloadSummary = ", ".join(parts)

        def enqueue(self, g, update=False):
            g.updating = update
            if self.epic_active is None:
                self._epic_start_download(g)
                return
            if g not in self.queue:
                self.queue.append(g)
            g.state, g.stopping = QUEUED, False
            self._refresh_queue()
            self.toast.emit(f"{g.title} sıraya eklendi ({len(self.queue)}. sırada).", "info")

        @Slot(str)
        def dequeue(self, key):
            g = self._game(key)
            if not g:
                return
            if g in self.queue:
                self.queue.remove(g)
            g.queuePos = 0
            resumable = (legendary_tmp_dir() / f"{g.id}.resume").exists()
            if g.installPath and g.updating:
                g.state = INSTALLED
            else:
                g.state = PAUSED if resumable else NOT_INSTALLED
            self._refresh_queue()

        def _start_next(self):
            if self.epic_active is None and self.queue:
                nxt = self.queue.pop(0)
                nxt.queuePos = 0
                self._epic_start_download(nxt)
            self._refresh_queue()

        def _epic_start_download(self, g):
            args = ["-y", "install", g.id, "--skip-sdl"]
            if g.updating:
                args.append("--update-only")
            else:
                base = getattr(g, "_base", None) or self.cfg.get("epic_dir") or ""
                if base:
                    try:
                        Path(base).mkdir(parents=True, exist_ok=True)
                        args += ["--base-path", base]
                    except Exception:
                        pass
            proc = QProcess(self)
            proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            proc.readyReadStandardOutput.connect(lambda: self._epic_output(g, proc))
            proc.finished.connect(lambda code, _status: self._epic_finished(g, code))
            proc._log = []
            self.epic_proc, self.epic_active = proc, g
            self.paused_by_user.discard(g.id)
            g.state, g.stopping, g.queuePos = DOWNLOADING, False, 0
            g.info = "hazırlanıyor"
            self._update_summary()
            proc.start(LEGENDARY[0], LEGENDARY[1:] + args)

        def _epic_output(self, g, proc):
            text = bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace")
            for line in text.splitlines():
                proc._log = (proc._log + [line])[-30:]
                m = re.search(r"Install path: (.+)$", line)
                if m:
                    g.installPath = m.group(1).strip()
                    if not g.updating:
                        base = getattr(g, "_base", None) or self.cfg.get("epic_dir") or ""
                        self.data.setdefault("partial", {})[g.id] = {"path": g.installPath, "base": base}
                        self.save_data()
                m = re.search(r"Download size: ([\d.]+) MiB", line)
                if m:
                    g.downloadSize = f"{float(m.group(1)) / 1024:.1f} GB".replace(".", ",")
                    if g.progress < 0:
                        g.info = f"indirilecek: {g.downloadSize}"
                m = re.search(r"Progress: ([\d.]+)%.*ETA: (\d\d:\d\d:\d\d)", line)
                if m:
                    g.progress = float(m.group(1))
                    g.info = f"kalan {m.group(2)}"
                m = re.search(r"\+ Download\s*-\s*([\d.]+) MiB/s", line)
                if m and g.progress >= 0:
                    eta = g.info.split(",")[0].strip()
                    g.info = f"{eta}, {float(m.group(1)):.1f} MB/s"
            self._update_summary()

        def _epic_finished(self, g, code):
            proc = self.epic_proc
            LOG.info(f"Epic indirmesi bitti: {g.title} | çıkış kodu {code} | "
                     f"{'durduruldu' if g.id in self.paused_by_user else ''}")
            if code != 0 and g.id not in self.paused_by_user and proc:
                LOG.warning("Legendary son satırlar:\n" + "\n".join(proc._log[-15:]))
            self.epic_proc, self.epic_active = None, None
            g.stopping = False
            if g.id in self._cancelling:
                self._cancelling.discard(g.id)
                self.paused_by_user.discard(g.id)
                if proc:
                    proc.deleteLater()
                self._cleanup_cancelled(g)
                self._start_next()
                return
            if g.id in self.paused_by_user:
                g.state, g.info = PAUSED, ""
            elif code == 0:
                g.state, g.progress, g.info = INSTALLED, -1.0, ""
                g.update = False
                self.data.get("partial", {}).pop(g.id, None)
                self.save_data()
                self.notify(f"{g.title} {'güncellendi' if g.updating else 'indirildi'}.", "ok")
                g.updating = False
                QTimer.singleShot(1000, self.load_epic)
            else:
                g.state, g.info = PAUSED, ""
                log = "\n".join(proc._log[-8:]) if proc else ""
                self.notify(f"{g.title} indirilirken sorun oldu.", "error")
                self.alert.emit("İndirme durdu",
                                f"{g.title} indirilirken bir sorun oldu. 'Devam et' ile tekrar deneyebilirsin.\n\n{log}")
            if proc:
                proc.deleteLater()
            self._start_next()

        # ======================================================== Epic: bulut kayıtları
        @staticmethod
        def _sync_job(app, direction):
            flag = "--skip-upload" if direction == "down" else "--skip-download"
            r = legendary_run("-y", "sync-saves", flag, app, timeout=300)
            if r.returncode != 0:
                raise RuntimeError(last_error_line(r))

        @Slot(str)
        def syncSaves(self, key):
            g = self._game(key)
            if not g:
                return
            g.state, g.info = BUSY, "kayıtlar eşitleniyor"

            def job():
                self._sync_job(g.id, "down")
                self._sync_job(g.id, "up")

            def done(_, error):
                g.state, g.info = INSTALLED, ""
                self.notify(f"{g.title}: kayıt eşitleme başarısız ({error})" if error
                            else f"{g.title}: bulut kayıtları eşitlendi.", "error" if error else "ok")
            self.run_background(job, done)

        @Slot()
        def syncAllSaves(self):
            self.toast.emit("Bütün Epic bulut kayıtları eşitleniyor…", "info")

            def job():
                r = legendary_run("-y", "sync-saves", timeout=1800)
                if r.returncode != 0:
                    raise RuntimeError(last_error_line(r))
            self.run_background(job, lambda _, e: self.notify(
                f"Kayıt eşitleme sorunu: {e}" if e else "Bütün bulut kayıtları eşitlendi.", "error" if e else "ok"))

        # ======================================================== oyun komutları
        @Slot(str)
        def openSteamDownloads(self, _key=""):
            QDesktopServices.openUrl(QUrl("steam://open/downloads"))

        @Slot(str)
        def install(self, key):
            g = self._game(key)
            if not g:
                return
            if g.platform == "steam":
                QDesktopServices.openUrl(QUrl(f"steam://install/{g.id}"))
                self.toast.emit("Steam'de kurulum penceresi açıldı. Steam boş yeri orada gösterir. "
                                "İndirme başlayınca burada görünecek.", "info")
                return
            update = g.updating or (g.update and bool(g.installPath))
            resuming = g.state == PAUSED
            if update or resuming:
                self.enqueue(g, update=update)
                return
            self._check_space_then_install(g)

        def _check_space_then_install(self, g):
            base = getattr(g, "_base", None) or self.cfg.get("epic_dir") or ""
            g.state, g.info = BUSY, "gereken yer hesaplanıyor"

            def job():
                return epic_install_size(g.id), free_space(base)

            def done(result, error):
                g.state, g.info = NOT_INSTALLED, ""
                if error or not result or not result[0] or result[1] < 0:
                    LOG.info(f"Boyut öğrenilemedi, kontrol atlandı: {g.title} | {error}")
                    self.enqueue(g)       # öğrenemezsek indirmeyi engellemeyelim
                    return
                need, free = result
                LOG.info(f"Yer kontrolü: {g.title} | gereken {format_bytes(need)} | boş {format_bytes(free)}")
                if need + 2 * 1024 ** 3 > free:      # 2 GB pay bırak
                    self.spaceProblem.emit(g.key, format_bytes(need), format_bytes(free), base)
                    return
                self.toast.emit(f"{g.title} kurulunca {format_bytes(need)} yer kaplayacak "
                                f"(diskte {format_bytes(free)} boş).", "info")
                self.enqueue(g)
            self.run_background(job, done)

        @Slot(str)
        def installAnyway(self, key):
            g = self._game(key)
            if g:
                LOG.info(f"Yer yetersiz ama yine de indiriliyor: {g.title}")
                self.enqueue(g)

        @Slot(str, str)
        def installTo(self, key, folder):
            g = self._game(key)
            if not g:
                return
            if folder.startswith("file:"):
                folder = QUrl(folder).toLocalFile()
            g._base = str(Path(folder))
            self._check_space_then_install(g)

        @Slot(str)
        def pause(self, key):
            g = self._game(key)
            proc = self.epic_proc
            if not g or not proc or self.epic_active is not g:
                return
            self.paused_by_user.add(g.id)
            g.stopping = True
            kill_tree(proc)  # Legendary kaldığı yeri kaydeder, 'Devam et' ile sürer

            def still_running():
                try:
                    if proc.state() != QProcess.ProcessState.NotRunning:
                        proc.kill()
                except RuntimeError:
                    pass
            QTimer.singleShot(3000, still_running)

        @Slot(str)
        def cancel(self, key):
            """İndirmeyi iptal eder ve o ana kadar inen dosyaları siler.
            Güncelleme iptal edilirse oyunun kendisi silinmez."""
            g = self._game(key)
            if not g:
                return
            if g.platform == "steam":
                # Steam indirmelerini Steam yönetir; kaldırma penceresi yarım inen dosyaları da siler
                QDesktopServices.openUrl(QUrl(f"steam://uninstall/{g.id}"))
                return
            LOG.info(f"İndirme iptal ediliyor: {g.title} | {'güncelleme' if g.updating else 'indirme'}")
            if g in self.queue:
                self.queue.remove(g)
                g.queuePos = 0
                self._refresh_queue()
            if self.epic_active is g and self.epic_proc:
                self._cancelling.add(g.id)
                g.stopping = True
                g.info = "iptal ediliyor"
                kill_tree(self.epic_proc)   # bitince _epic_finished temizliği başlatır
                proc = self.epic_proc

                def still_running():
                    try:
                        if proc.state() != QProcess.ProcessState.NotRunning:
                            proc.kill()
                    except RuntimeError:
                        pass
                QTimer.singleShot(3000, still_running)
                return
            self._cleanup_cancelled(g)

        def _cleanup_cancelled(self, g):
            update = bool(g.updating)
            partial = self.data.get("partial", {}).get(g.id) or {}
            path = "" if update else (partial.get("path") or (g.installPath if g.state != INSTALLED else ""))
            bases = [b for b in (partial.get("base"), getattr(g, "_base", None), self.cfg.get("epic_dir")) if b]
            g.state, g.info, g.stopping = BUSY, "indirilen dosyalar siliniyor", False
            app = g.id

            def job():
                import shutil
                tmp = legendary_tmp_dir()
                for f in (tmp / f"{app}.resume", tmp / f"{app}.repair"):
                    try:
                        f.unlink(missing_ok=True)
                    except Exception:
                        pass
                if not path:
                    return 0
                target = Path(path).resolve()
                # Güvenlik: sadece Epic oyun klasörünün İÇİNDEKİ bu oyunun klasörü silinir
                safe = any(target != Path(b).resolve() and Path(b).resolve() in target.parents for b in bases)
                if not safe or not target.exists():
                    LOG.warning(f"İptal: klasör silinmedi (güvenli değil ya da yok): {target}")
                    return 0
                # Legendary bu oyunu kurulu sayıyorsa (yarım değil, tam kurulu) asla silme
                try:
                    if app in {i["app_name"] for i in legendary_json("list-installed", "--json")}:
                        LOG.warning(f"İptal: {app} kurulu görünüyor, klasör silinmedi")
                        return 0
                except Exception:
                    pass
                size = sum(f.stat().st_size for f in target.rglob("*") if f.is_file())
                for attempt in range(5):     # dosyalar bir an kilitli kalabilir, birkaç kez dene
                    try:
                        shutil.rmtree(target)
                        break
                    except FileNotFoundError:
                        break
                    except Exception as e:
                        if attempt == 4:
                            raise RuntimeError(f"Bazı dosyalar silinemedi: {e}")
                        time.sleep(1.5)
                return size

            def done(size, error):
                self.data.get("partial", {}).pop(app, None)
                self.save_data()
                g.progress, g.info, g.downloadSize = -1.0, "", ""
                if update:
                    g.state, g.updating = INSTALLED, False
                    self.toast.emit(f"{g.title} güncellemesi iptal edildi. Oyunun kendisi duruyor, "
                                    "istersen sonra tekrar güncelleyebilirsin.", "info")
                else:
                    g.state, g.installPath, g.sizeBytes = NOT_INSTALLED, "", 0.0
                    if error:
                        self.alert.emit("İptal edildi ama bazı dosyalar silinemedi",
                                        f"{error}\n\nKlasörü kendin silebilirsin: {path}")
                    else:
                        freed = f", indirilen {format_bytes(size)} silindi" if size else ""
                        self.toast.emit(f"{g.title} indirmesi iptal edildi{freed}.", "ok")
                LOG.info(f"İptal tamamlandı: {g.title} | silinen {format_bytes(size or 0) or '0'} | hata: {error}")
                self._update_summary()
                self.relayout()
            self.run_background(job, done)

        @Slot(str)
        def play(self, key):
            g = self._game(key)
            if not g:
                return
            if g.platform == "steam":
                QDesktopServices.openUrl(QUrl(f"steam://rungameid/{g.id}"))
                return
            g.state, g.info = PLAYING, "başlatılıyor"
            path, app, cloud = g.installPath, g.id, g.cloud
            log = []

            def set_info(text):
                self.invoker.call.emit(lambda: setattr(g, "info", text))

            def job():
                if cloud:
                    set_info("bulut kayıtları indiriliyor")
                    try:
                        self._sync_job(app, "down")
                    except Exception as e:
                        log.append(f"kayıtlar indirilemedi: {e}")
                set_info("oyun açık")
                subprocess.Popen(LEGENDARY + ["launch", app], creationflags=NO_WINDOW,
                                 stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                seconds = wait_for_game(path) if path else 0
                if cloud:
                    set_info("kayıtlar buluta yükleniyor")
                    try:
                        self._sync_job(app, "up")
                    except Exception as e:
                        log.append(f"kayıtlar yüklenemedi: {e}")
                return seconds

            def done(seconds, error):
                g.state, g.info = INSTALLED, ""
                rec = self.data["epic_play"].setdefault(g.id, {"minutes": 0, "last": 0})
                rec["last"] = int(time.time())
                rec["minutes"] = rec.get("minutes", 0) + int((seconds or 0) // 60)
                g.playtime, g.lastPlayed = rec["minutes"], rec["last"]
                self.save_data()
                if error or log:
                    self.notify(f"{g.title}: " + "; ".join(log + ([str(error)] if error else [])), "error")
                elif cloud:
                    self.notify(f"{g.title}: kayıtların buluta yüklendi.", "ok")
                if self._sortMode in (1, 2):
                    self.relayout()

            self.run_background(job, done)

        @Slot(str)
        def openFolder(self, key):
            g = self._game(key)
            if not g:
                return
            for p in (g.installPath, self.cfg.get("epic_dir") if g.platform == "epic" else ""):
                if p and Path(p).exists():
                    QDesktopServices.openUrl(QUrl.fromLocalFile(p))
                    return
            self.toast.emit("Klasör henüz oluşmadı.", "info")

        @Slot(str)
        def openStore(self, key):
            g = self._game(key)
            if g and g.platform == "steam":
                QDesktopServices.openUrl(QUrl(f"https://store.steampowered.com/app/{g.id}"))

        @Slot(str)
        def uninstall(self, key):
            g = self._game(key)
            if not g:
                return
            if g.platform == "steam":
                QDesktopServices.openUrl(QUrl(f"steam://uninstall/{g.id}"))
                return
            g.state, g.info = BUSY, "kaldırılıyor"

            def job():
                r = legendary_run("-y", "uninstall", g.id, timeout=1800)
                if r.returncode != 0:
                    raise RuntimeError(last_error_line(r))

            def done(_, error):
                if error:
                    self.alert.emit("Kaldırılamadı", str(error))
                    g.state = INSTALLED
                else:
                    g.state, g.installPath, g.update = NOT_INSTALLED, "", False
                    self.toast.emit(f"{g.title} kaldırıldı.", "ok")
                g.info = ""
                self.relayout()
            self.run_background(job, done)

        # ======================================================== gökyüzü
        @Slot()
        def prepareSky(self):
            """Her oyuna gökyüzünde bir yer verir: çok oynananlar merkeze yakın ve büyük,
            yakında oynananlar parlak, kurulu olmayanlar soluk."""
            games = sorted(self.games.values(), key=lambda g: (-(g.playtime or 0), g.title.casefold()))
            now = time.time()
            golden = math.pi * (3 - math.sqrt(5))
            n = max(1, len(games))
            for i, g in enumerate(games):
                h = int(hashlib.md5(g.key.encode()).hexdigest()[:8], 16)
                jitter = ((h % 1000) / 1000 - 0.5) * 0.06
                r = math.sqrt((i + 0.5) / n) + jitter
                a = i * golden + (h % 360) / 360 * 0.4
                g.skyX, g.skyY = r * math.cos(a), r * math.sin(a)
                hours = (g.playtime or 0) / 60
                g.skySize = 3.0 + min(16.0, 4.2 * math.log10(1 + hours) * 2)
                if g.lastPlayed:
                    days = (now - g.lastPlayed) / 86400
                    glow = 1.0 if days < 14 else max(0.35, 1.0 - days / 365)
                else:
                    glow = 0.3
                if g.state == NOT_INSTALLED:
                    glow *= 0.6
                g.skyGlow = glow

        # ======================================================== ayarlar ve araçlar
        @Slot()
        def createShortcut(self):
            if not IS_WINDOWS:
                self.alert.emit("Kısayol", "Bu özellik sadece Windows'ta çalışır.")
                return
            if FROZEN:
                target, arguments = sys.executable, ""
            else:
                pyw = Path(sys.executable).with_name("pythonw.exe")
                target = str(pyw if pyw.exists() else Path(sys.executable))
                arguments = f'"{Path(__file__).resolve()}"'

            def q(s):
                return "'" + str(s).replace("'", "''") + "'"
            ps = ("$d=[Environment]::GetFolderPath('Desktop');"
                  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $d 'Oyun Kütüphanem.lnk'));"
                  f"$s.TargetPath={q(target)};$s.Arguments={q(arguments)};"
                  f"$s.WorkingDirectory={q(APP_DIR)};"
                  + (f"$s.IconLocation={q(ICON_FILE)};" if ICON_FILE.exists() else "")
                  + "$s.Save()")
            r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps],
                               capture_output=True, text=True, creationflags=NO_WINDOW)
            if r.returncode == 0:
                self.toast.emit("Masaüstüne 'Oyun Kütüphanem' kısayolu eklendi.", "ok")
            else:
                self.alert.emit("Kısayol oluşturulamadı", r.stderr.strip()[-400:])

        # ======================================================== pencere ve çıkış
        @Slot(result=bool)
        def handleClose(self):
            """Pencerenin X'ine basıldı. True dönerse program kapanır."""
            if not self.quitting and self.tray and self.tray.isVisible():
                self._window_hidden = True
                self.hideWindowRequested.emit()
                if not self.cfg.get("tray_hint_shown"):
                    self.tray.showMessage("Oyun Kütüphanem arka planda çalışıyor",
                                          "İndirmeler devam ediyor. Saatin yanındaki simgeden geri açabilir, "
                                          "sağ tıklayıp 'Çıkış' ile kapatabilirsin.", QIcon(str(ICON_FILE)), 8000)
                    self.cfg["tray_hint_shown"] = True
                    write_json(CONFIG_FILE, self.cfg)
                return False
            if self.epic_proc and not getattr(self, "_quit_confirmed", False):
                self.quitting = False
                self.showWindowRequested.emit()
                self.confirmQuitRequested.emit()
                return False
            self._shutdown()
            QTimer.singleShot(0, self.app.quit)
            return True

        @Slot()
        def requestQuit(self):
            self.quitting = True
            if self.epic_proc:
                self.showWindowRequested.emit()
                self.confirmQuitRequested.emit()
                return
            self._shutdown()
            self.app.quit()

        @Slot()
        def quitNow(self):
            self._quit_confirmed = True
            self.quitting = True
            self._shutdown()
            self.app.quit()

        @Slot()
        def cancelQuit(self):
            self.quitting = False

        @Slot()
        def windowShown(self):
            self._window_hidden = False

        def _shutdown(self):
            if self.epic_proc:
                if self.epic_active:
                    self.paused_by_user.add(self.epic_active.id)
                self.queue.clear()
                kill_tree(self.epic_proc)
                self.epic_proc.waitForFinished(3000)
            if self.tray:
                self.tray.hide()

    # ==================================================================== kurulum
    QQuickStyle.setStyle("Basic")
    cfg = load_config()
    if cfg.get("software_render"):
        QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.Software)

    app = QApplication.instance() or QApplication(sys.argv)
    app.setApplicationName("Oyun Kütüphanem")
    app.setQuitOnLastWindowClosed(False)
    if ICON_FILE.exists():
        app.setWindowIcon(QIcon(str(ICON_FILE)))

    # --- Tek kopya kontrolü: program zaten açıksa uyar ve açık olanı öne getir ---
    import getpass
    try:
        user = getpass.getuser()
    except Exception:
        user = "kullanici"
    server_name = "OyunKutuphanem-" + hashlib.md5(user.encode("utf-8")).hexdigest()[:10]
    sock = QLocalSocket()
    sock.connectToServer(server_name)
    if sock.waitForConnected(800):
        sock.write(b"show")
        sock.flush()
        sock.waitForBytesWritten(800)
        sock.disconnectFromServer()
        box = QMessageBox(QMessageBox.Icon.Information, "Oyun Kütüphanem",
                          "Uygulama zaten açık!\n\nAçık olan pencereyi öne getirdim. Göremiyorsan saatin "
                          "yanındaki oyun kolu simgesine tıkla.")
        box.exec()
        return app, None
    QLocalServer.removeServer(server_name)
    server = QLocalServer(app)
    server.listen(server_name)

    # --- yazı tipleri ---
    families = {}
    for f in (RES_DIR / "fonts").glob("*.ttf"):
        fid = QFontDatabase.addApplicationFont(str(f))
        if fid >= 0:
            fams = QFontDatabase.applicationFontFamilies(fid)
            if fams:
                families[f.stem.split("-")[0]] = fams[0]
    body_font = families.get("AtkinsonHyperlegibleNext", "Segoe UI")
    display_font = families.get("BricolageGrotesque", body_font)
    base_font = QFont(body_font)
    base_font.setPixelSize(14)
    app.setFont(base_font)

    theme = Theme(bool(cfg.get("dark", True)), display_font, body_font)
    model = GamesModel()
    backend = Backend(app, theme, model, QSystemTrayIcon.isSystemTrayAvailable())
    backend.toast.connect(backend._log_toast)
    backend.alert.connect(backend._log_alert)
    backend._software_active = bool(cfg.get("software_render")) or os.environ.get("QT_QUICK_BACKEND") == "software"
    start_hidden = "--tray" in sys.argv and QSystemTrayIcon.isSystemTrayAvailable()
    backend._window_hidden = start_hidden
    if IS_WINDOWS:   # kurulum/kaldırma programı "program açık" diye buna bakar
        import ctypes
        app._mutex = ctypes.windll.kernel32.CreateMutexW(None, False, MUTEX_NAME)

    # --- sistem tepsisi ---
    if QSystemTrayIcon.isSystemTrayAvailable():
        tray = QSystemTrayIcon(QIcon(str(ICON_FILE)) if ICON_FILE.exists() else app.windowIcon(), app)
        tray.setToolTip("Oyun Kütüphanem")
        menu = QMenu()
        menu.addAction("Göster", backend.showWindowRequested.emit)
        menu.addAction("Çıkış", backend.requestQuit)
        tray.setContextMenu(menu)
        tray._menu = menu
        tray.activated.connect(lambda reason: backend.showWindowRequested.emit()
                               if reason in (QSystemTrayIcon.ActivationReason.Trigger,
                                             QSystemTrayIcon.ActivationReason.DoubleClick) else None)
        tray.show()
        backend.tray = tray

    def on_second_launch():
        conn = server.nextPendingConnection()
        if conn:
            conn.readyRead.connect(lambda: conn.readAll())
            conn.disconnected.connect(conn.deleteLater)
        backend.showWindowRequested.emit()
    server.newConnection.connect(on_second_launch)

    # --- QML ---
    engine = QQmlApplicationEngine()
    qml_errors = []
    def on_qml_warnings(ws):
        for w in ws:
            qml_errors.append(w.toString())
            LOG.warning(f"Arayüz uyarısı: {w.toString()}")
    engine.warnings.connect(on_qml_warnings)
    ctx = engine.rootContext()
    ctx.setContextProperty("backend", backend)
    ctx.setContextProperty("theme", theme)
    ctx.setContextProperty("gamesModel", model)
    ctx.setContextProperty("startHidden", start_hidden)
    engine.load(QUrl.fromLocalFile(str(RES_DIR / "qml" / "Main.qml")))
    if not engine.rootObjects():
        QMessageBox.critical(None, "Oyun Kütüphanem", "Arayüz açılamadı:\n\n" + "\n".join(qml_errors[-6:]))
        return app, None
    QTimer.singleShot(0, backend.start)

    def apply_titlebar():
        """Windows'un başlık çubuğunu uygulamanın temasına boyar (Windows 11'de tam renk, 10'da koyu/açık)."""
        if not IS_WINDOWS:
            return
        try:
            import ctypes
            win = engine.rootObjects()[0]
            hwnd = ctypes.c_void_p(int(win.winId()))
            pal = PALETTES[theme._dark]

            def colorref(h):
                return int(h[1:3], 16) | (int(h[3:5], 16) << 8) | (int(h[5:7], 16) << 16)

            def dwm(attr, value):
                v = ctypes.c_int(value)
                ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, attr, ctypes.byref(v), ctypes.sizeof(v))
            dwm(20, 1 if theme._dark else 0)        # koyu başlık çubuğu (Windows 10 20H1+ ve 11)
            dwm(19, 1 if theme._dark else 0)        # eski Windows 10 sürümleri
            dwm(35, colorref(pal["bg"]))            # başlık çubuğu rengi (Windows 11)
            dwm(36, colorref(pal["text"]))          # başlık yazısı rengi (Windows 11)
            dwm(34, colorref(pal["line"]))          # pencere kenarı rengi (Windows 11)
            dwm(33, 2)                              # yuvarlak köşeler (Windows 11)
        except Exception:
            pass
    theme.changed.connect(apply_titlebar)
    QTimer.singleShot(0, apply_titlebar)

    def teardown():
        # Arayüzü tema ve listeden önce kapat, yoksa kapanırken gereksiz hata yazıları çıkar
        import shiboken6
        try:
            shiboken6.delete(engine)
        except Exception:
            pass
    app.aboutToQuit.connect(teardown)
    app._keep = (backend, theme, model, server, engine)  # engine en son: ilk o silinir
    return app, backend


def main():
    app, backend = run_gui()
    if backend is None:      # program zaten açıktı ya da arayüz açılamadı
        return
    sys.exit(app.exec())


if __name__ == "__main__":
    multiprocessing.freeze_support()   # .exe modunda Legendary'nin yan süreçleri için gerekli
    if len(sys.argv) > 1 and sys.argv[1] == "--legendary":
        run_legendary_mode()
    else:
        main()
