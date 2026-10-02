@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Oyun Kutuphanem - Hata ayiklama
echo Program acilmazsa bu pencerede cikan yazinin ekran goruntusunu Claude'a gonder.
echo.
py "%~dp0oyun_kutuphanem.py"
pause
