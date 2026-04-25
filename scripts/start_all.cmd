@echo off
setlocal
cd /d "%~dp0"

set TARGET=%~1
if /I "%TARGET%"=="" set TARGET=web

echo.
echo ============================================
echo   Scan System - One Click Starter
echo ============================================
echo Mode: %TARGET%
echo.

echo [1/2] Starting server in new terminal...
start "Scan Server" cmd /k "%~dp0start_server.cmd"

echo Waiting 6 seconds for server warm-up...
timeout /t 6 /nobreak >nul

if /I "%TARGET%"=="android" goto START_ANDROID
if /I "%TARGET%"=="web" goto START_WEB
if /I "%TARGET%"=="both" goto START_BOTH

echo Unknown mode: %TARGET%
echo Use one of: web ^| android ^| both
exit /b 1

:START_WEB
echo [2/2] Starting web app in new terminal...
start "Scan Web" cmd /k "%~dp0run_web.cmd"
echo.
echo Done. Open terminals:
echo   - Scan Server
echo   - Scan Web
goto END

:START_ANDROID
echo [2/2] Starting Android app in new terminal...
start "Scan Android" cmd /k "%~dp0run_android.cmd"
echo.
echo Done. Open terminals:
echo   - Scan Server
echo   - Scan Android
goto END

:START_BOTH
echo [2/2] Starting Android and Web in new terminals...
start "Scan Android" cmd /k "%~dp0run_android.cmd"
start "Scan Web" cmd /k "%~dp0run_web.cmd"
echo.
echo Done. Open terminals:
echo   - Scan Server
echo   - Scan Android
echo   - Scan Web

:END
echo.
echo Tip:
echo   start_all.cmd web
echo   start_all.cmd android
echo   start_all.cmd both
echo.
