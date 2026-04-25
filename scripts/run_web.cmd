@echo off
REM From PowerShell in this folder run:  .\run_web.cmd
REM (PowerShell does not run scripts in the current directory without .\)
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_web.ps1" %*
