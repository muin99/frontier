@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Play.ps1" -ForceCompatibility %*
if errorlevel 1 pause
