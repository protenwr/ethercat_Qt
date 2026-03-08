@echo off
chcp 65001 >nul
echo ====================================================
echo    SOEM 젯슨 배포 마법사 (Windows 자동 실행기)
echo ====================================================
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Deploy-SOEM.ps1"
echo.
pause
