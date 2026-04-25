@echo off
REM From PowerShell in this folder run:  .\run_android.cmd
REM Optional: .\run_android.cmd -DeviceId emulator-5554 -ApiBaseUrl http://10.0.2.2:8080
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_android.ps1" %*
