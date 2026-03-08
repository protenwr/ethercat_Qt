@echo off
chcp 65001 >nul
echo ====================================================
echo    Qt Creator (jetson_ecat_engine) 재시작
echo ====================================================
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Qt_run.ps1"
echo.
pause
