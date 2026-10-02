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
    "qtwebengine", "qtwebengine_locales", "qt3d", "qtquick3d", "qtcharts", "qtdatavisualization",
    "qtgraphs", "qtmultimedia", "qtlocation", "qtpositioning", "qtsensors", "qtwebview",
    "qtwebchannel", "qtwebsockets", "qtremoteobjects", "qtscxml", "qttexttospeech", "qttest",
    "qt5compat", "qtwayland", "virtualkeyboard", "pdf", "scene3d", "scene2d",
    # Qt eklenti klasörleri
    "multimedia", "sensors", "position", "geoservices", "texttospeech", "sceneparsers",
    "renderers", "geometryloaders", "renderplugins", "webview", "designer", "qmltooling",
}
# Adında bunlardan biri geçen dosyalar silinir
FILE_PARTS = (
    "webengine", "qt63d", "qt3d", "quick3d", "qt6charts", "qtcharts", "datavisualization",
    "qt6graphs", "qtgraphs", "multimedia", "qt6location", "qtlocation", "positioning",
    "qt6sensors", "qtsensors", "webview", "webchannel", "websockets", "remoteobjects",
    "scxml", "texttospeech", "virtualkeyboard", "qt6pdf", "qtpdf", "spatialaudio",
    "avcodec", "avformat", "avutil", "swresample", "swscale",
)


def prune(root):
    root = Path(root)
    removed = 0
    for p in sorted(root.rglob("*"), key=lambda x: len(x.parts), reverse=True):
        if not p.exists():
            continue
        name = p.name.casefold()
        try:
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
    target = sys.argv[1] if len(sys.argv) > 1 else "dist/OyunKutuphanem"
    mb = prune(target) / 1024 / 1024
    print(f"  Kullanılmayan parçalar silindi: {mb:.0f} MB")
