@echo off
REM Нэг товчлуураар өгөгдлийн сан + серверийг асаадаг товчлуур
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_server.ps1" %*
