@echo off
chcp 65001 >nul
echo ====================================================
echo    SOEM 라이브러리 재빌드 + 프로젝트 동기화
echo ====================================================
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0lib_make_run.ps1"
echo.
pause
