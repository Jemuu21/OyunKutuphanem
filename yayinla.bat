@echo off
chcp 65001 >nul
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Oyun Kutuphanem - Yeni surumu yayinla
set /p VER=<"%~dp0SURUM.txt"
echo.
echo  Oyun Kutuphanem %VER% yayinlaniyor.
echo  Bu islem kurulum dosyasini olusturur ve GitHub'a yukler.
echo  Arkadaslarinin programi yeni surumu kendiliginden gorur.
echo.

rem ---- 1) GitHub araci (gh) ----
call :gh_bul
if not defined GH (
  echo  [1/5] GitHub araci kuruluyor...
  winget install --id GitHub.cli -e --silent --accept-package-agreements --accept-source-agreements
  call :gh_bul
)
if not defined GH (
  echo  GitHub araci kurulamadi. https://cli.github.com adresinden kurup tekrar dene.
  pause
  exit /b 1
)

rem ---- 2) GitHub girisi (ilk seferde tarayici acilir) ----
"%GH%" auth status >nul 2>nul
if errorlevel 1 (
  echo  [2/5] GitHub hesabina giris. Ekrandaki kodu kopyala, acilan sayfaya yapistir.
  "%GH%" auth login --web --git-protocol https --hostname github.com
  "%GH%" auth status >nul 2>nul
  if errorlevel 1 (
    echo  Giris yapilamadi.
    pause
    exit /b 1
  )
)

rem ---- 3) Depo adi: guncelleme.txt bossa kullanici adindan olustur ----
set "REPO="
for /f "usebackq eol=# tokens=*" %%a in ("%~dp0guncelleme.txt") do if not defined REPO set "REPO=%%a"
if not defined REPO (
  for /f "tokens=*" %%u in ('call "%GH%" api user --jq .login') do set "GHUSER=%%u"
  set "REPO=!GHUSER!/OyunKutuphanem"
  >>"%~dp0guncelleme.txt" echo !REPO!
  echo  Guncelleme kaynagi ayarlandi: !REPO!
)
"%GH%" repo view "!REPO!" >nul 2>nul
if errorlevel 1 (
  echo  [3/5] GitHub'da !REPO! deposu olusturuluyor...
  "%GH%" repo create "!REPO!" --public --add-readme --description "Oyun Kutuphanem kurulum dosyalari"
  if errorlevel 1 (
    echo  Depo olusturulamadi.
    pause
    exit /b 1
  )
)

rem ---- 4) Bu surum daha once yayinlandi mi? ----
"%GH%" release view "v%VER%" --repo "!REPO!" >nul 2>nul
if not errorlevel 1 (
  echo.
  echo  v%VER% zaten yayinlanmis. Once SURUM.txt dosyasindaki numarayi artir
  echo  ^(ornegin 3.4 ise 3.5 yap^), sonra bu dosyayi tekrar calistir.
  pause
  exit /b 1
)

rem ---- 5) Kurulum dosyasini olustur ve yukle ----
echo  [4/5] Kurulum dosyasi olusturuluyor...
call "%~dp0setup_yap.bat" --sessiz
if errorlevel 1 (
  echo  Kurulum dosyasi olusturulamadi.
  pause
  exit /b 1
)
echo.
set "NOTLAR="
set /p NOTLAR= Bu surumde neler degisti? Kisaca yaz ve Enter'a bas: 
if not defined NOTLAR set "NOTLAR=Yeni surum"
echo  [5/5] GitHub'a yukleniyor...
"%GH%" release create "v%VER%" "%~dp0OyunKutuphanemKurulum.exe" --repo "!REPO!" --title "Oyun Kutuphanem %VER%" --notes "!NOTLAR!"
if errorlevel 1 (
  echo  Yukleme basarisiz oldu.
  pause
  exit /b 1
)
echo.
echo  ===============================================================
echo   Tamam! Surum %VER% yayinlandi.
echo   Arkadaslarinin programi en gec yarim gun icinde yeni surumu gorur.
echo   Yeni bir arkadasina program vereceksen yine bu kurulum dosyasini ver.
echo  ===============================================================
pause
exit /b 0

:gh_bul
set "GH="
where gh >nul 2>nul && set "GH=gh"
if not defined GH if exist "%LOCALAPPDATA%\Programs\GitHub CLI\gh.exe" set "GH=%LOCALAPPDATA%\Programs\GitHub CLI\gh.exe"
if not defined GH if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GH=%ProgramFiles%\GitHub CLI\gh.exe"
exit /b
