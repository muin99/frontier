@echo off
cd /d "%~dp0"
if not exist "tools\godot\Godot_v4.7.2-stable_win64.exe" python tools\setup.py
start "Godot Editor" "tools\godot\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0game"
