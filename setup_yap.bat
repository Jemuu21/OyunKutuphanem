@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Oyun Kutuphanem - Kurulum dosyasi hazirlaniyor
echo.
set /p VER=<"%~dp0SURUM.txt"
echo  OyunKutuphanemKurulum.exe hazirlaniyor (surum %VER%). 5-10 dakika surebilir, pencereyi kapatma.
echo.

where py >nul 2>nul
if errorlevel 1 (
  echo  HATA: Python bulunamadi. Once python.org adresinden Python'u kur.
  pause
  exit /b
)

echo  [1/4] Gerekli parcalar guncelleniyor...
py -m pip install --upgrade --quiet pip pyinstaller PySide6 requests legendary-gl psutil
if errorlevel 1 goto hata

echo  [2/4] Eski ayarlarin yeni yerine kopyalaniyor (varsa)...
set "VERI=%APPDATA%\OyunKutuphanem"
set "ONBELLEK=%LOCALAPPDATA%\OyunKutuphanem"
if not exist "%VERI%" mkdir "%VERI%"
if not exist "%ONBELLEK%\kapak_onbellek" mkdir "%ONBELLEK%\kapak_onbellek"
if exist "%~dp0ayarlar.json" if not exist "%VERI%\ayarlar.json" copy /Y "%~dp0ayarlar.json" "%VERI%\" >nul
if exist "%~dp0kutuphane_verisi.json" if not exist "%VERI%\kutuphane_verisi.json" copy /Y "%~dp0kutuphane_verisi.json" "%VERI%\" >nul
if exist "%~dp0kutuphane_onbellek.json" if not exist "%ONBELLEK%\kutuphane_onbellek.json" copy /Y "%~dp0kutuphane_onbellek.json" "%ONBELLEK%\" >nul
if exist "%~dp0kapak_onbellek\*.jpg" copy /Y "%~dp0kapak_onbellek\*.jpg" "%ONBELLEK%\kapak_onbellek\" >nul

echo  [3/4] Program paketleniyor...
py -m PyInstaller --noconfirm --clean --onedir --windowed --name OyunKutuphanem --icon "%~dp0icon.ico" --add-data "%~dp0qml;qml" --add-data "%~dp0fonts;fonts" --add-data "%~dp0icon.ico;." --add-data "%~dp0SURUM.txt;." --add-data "%~dp0guncelleme.txt;." --collect-all legendary --hidden-import psutil --hidden-import PySide6.QtQuickControls2 --hidden-import PySide6.QtWebEngineWidgets --hidden-import PySide6.QtWebEngineCore "%~dp0oyun_kutuphanem.py"
if not exist "%~dp0dist\OyunKutuphanem\OyunKutuphanem.exe" goto hata
echo  Kullanilmayan Qt parcalari ayiklaniyor...
py "%~dp0paketi_ayikla.py" "%~dp0dist\OyunKutuphanem"

echo  [4/4] Kurulum dosyasi olusturuluyor...
call :iscc_bul
if not defined ISCC (
  echo  Inno Setup bulunamadi, kuruluyor...
  winget install --id JRSoftware.InnoSetup -e --scope user --silent --accept-package-agreements --accept-source-agreements
  call :iscc_bul
)
if not defined ISCC (
  winget install --id JRSoftware.InnoSetup -e --silent --accept-package-agreements --accept-source-agreements
  call :iscc_bul
)
if not defined ISCC (
  echo.
  echo  Inno Setup kurulamadi. Su adresten indirip kur, sonra bu dosyayi tekrar calistir:
  echo  https://jrsoftware.org/isdl.php
  start "" "https://jrsoftware.org/isdl.php"
  pause
  exit /b
)
"%ISCC%" /Q "/DAppVersion=%VER%" "%~dp0OyunKutuphanem.iss"
if not exist "%~dp0OyunKutuphanemKurulum.exe" goto hata

rmdir /s /q "%~dp0build" 2>nul
rmdir /s /q "%~dp0dist" 2>nul
del /q "%~dp0OyunKutuphanem.spec" 2>nul
echo.
echo  ===============================================================
echo   Tamam! Klasorde OyunKutuphanemKurulum.exe olustu (surum %VER%).
echo   Cift tiklayip kurabilirsin. Windows uyari verirse:
echo   "Ek bilgi" ve sonra "Yine de calistir" de.
echo  ===============================================================
echo.
if not "%~1"=="--sessiz" pause
exit /b 0

:iscc_bul
set "ISCC="
for %%P in ("%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" "%ProgramFiles%\Inno Setup 6\ISCC.exe") do (
  if exist %%P set "ISCC=%%~P"
)
exit /b

:hata
echo.
echo  Bir seyler ters gitti. Bu pencerenin ekran goruntusunu alip Claude'a gonder.
if not "%~1"=="--sessiz" pause
exit /b 1
