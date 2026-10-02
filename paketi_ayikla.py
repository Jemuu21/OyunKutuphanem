# -*- coding: utf-8 -*-
"""
Paketten programın kullanmadığı Qt parçalarını siler (web tarayıcı motoru, 3B, grafikler, video...).
setup_yap.bat bunu kendisi çalıştırır:  py paketi_ayikla.py dist\\OyunKutuphanem
"""
import shutil
import sys
from pathlib import Path

# Bu adla birebir eşleşen klasörler silinir
DIRS = {
    "qt3d", "qtquick3d", "qtcharts", "qtdatavisualization",
    "qtgraphs", "qtmultimedia", "qtlocation", "qtpositioning", "qtsensors", "qtwebview",
    "qtwebchannel", "qtwebsockets", "qtremoteobjects", "qtscxml", "qttexttospeech", "qttest",
    "qt5compat", "qtwayland", "virtualkeyboard", "pdf", "scene3d", "scene2d",
    # Qt eklenti klasörleri
    "multimedia", "sensors", "position", "geoservices", "texttospeech", "sceneparsers",
    "renderers", "geometryloaders", "renderplugins", "webview", "designer", "qmltooling",
}
# Adında bunlardan biri geçen dosyalar silinir
# Not: uygulama içi giriş penceresi tarayıcı motorunu kullanır; "webengine", "webchannel" ve
# "positioning" parçaları ona gerekli, silinmez.
FILE_PARTS = (
    "qt63d", "qt3d", "quick3d", "qt6charts", "qtcharts", "datavisualization",
    "qt6graphs", "qtgraphs", "multimedia", "qt6location", "qtlocation",
    "qt6sensors", "qtsensors", "webview", "websockets", "remoteobjects",
    "scxml", "texttospeech", "virtualkeyboard", "qt6pdf", "qtpdf", "spatialaudio",
    "avcodec", "avformat", "avutil", "swresample", "swscale",
    "devtools_resources",      # tarayıcının geliştirici araçları, giriş penceresinde gerekmez
)


def prune(root):
    root = Path(root)
    removed = 0
    for p in sorted(root.rglob("*"), key=lambda x: len(x.parts), reverse=True):
        if not p.exists():
            continue
        name = p.name.casefold()
        try:
            if p.is_file() and p.parent.name.casefold() == "qtwebengine_locales" and p.suffix == ".pak" \
                    and p.stem not in ("en-US", "tr"):
                removed += p.stat().st_size      # tarayıcının diğer dil dosyaları
                p.unlink()
                continue
            if p.is_dir() and name in DIRS and p != root:
                removed += sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
                shutil.rmtree(p)
            elif p.is_file() and any(part in name for part in FILE_PARTS):
                removed += p.stat().st_size
                p.unlink()
        except Exception as e:
            print(f"  atlandı: {p.name} ({e})")
    return removed


if __name__ == "__main__":
    # Windows konsolu Türkçe karakterleri yazamazsa çökmesin
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    target = sys.argv[1] if len(sys.argv) > 1 else "dist/OyunKutuphanem"
    mb = prune(target) / 1024 / 1024
    print(f"  Kullanılmayan parçalar silindi: {mb:.0f} MB")
