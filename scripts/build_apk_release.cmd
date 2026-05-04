@echo off
REM Release APK — Windows дээр хэрэглэгчийн замд хоосон зай байвал
REM (жишээ: C:\Users\ACER PREDATOR\...) Dart native hook алдаа өгч болно.
REM build_apk_release.ps1 нь PUB_CACHE=C:\PubCache тохируулж build хийнэ.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apk_release.ps1"
pause
