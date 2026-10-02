@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Oyun Kutuphanem - Kurulum
echo.
echo  Oyun Kutuphanem icin gerekli parcalar kuruluyor...
echo  (Internet hizina gore 1-3 dakika surebilir)
echo.
where py >nul 2>nul
if errorlevel 1 (
  echo  HATA: Python bulunamadi!
  echo  Once python.org adresinden Python'u kur, sonra bu dosyayi tekrar calistir.
  echo.
  pause
  exit /b
)
py -m pip install --upgrade pip
py -m pip install --upgrade PySide6 requests legendary-gl psutil
if errorlevel 1 (
  echo.
  echo  Bir seyler ters gitti. Bu pencerenin ekran goruntusunu alip Claude'a gonder.
  pause
  exit /b
)
echo.
echo  ===============================================
echo   Kurulum tamam! Artik baslat.bat ile acabilirsin.
echo  ===============================================
echo.
pause
