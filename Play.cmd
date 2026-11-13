@echo off
cd /d "%~dp0"
if exist "build\windows-v11\Mohashunnyo.exe" (
  start "Mohashunnyo" "build\windows-v11\Mohashunnyo.exe" %*
  exit /b 0
)
if exist "build\windows-v10\Mohashunnyo.exe" (
  start "Mohashunnyo" "build\windows-v10\Mohashunnyo.exe" %*
  exit /b 0
)
if exist "build\windows-v9\Mohashunnyo.exe" (
  start "Mohashunnyo" "build\windows-v9\Mohashunnyo.exe" %*
  exit /b 0
)
if exist "build\windows-v8\Mohashunnyo.exe" (
  start "Mohashunnyo" "build\windows-v8\Mohashunnyo.exe" %*
  exit /b 0
)
if exist "build\windows-v7\Mohashunnyo.exe" (
  start "Mohashunnyo" "build\windows-v7\Mohashunnyo.exe" %*
  exit /b 0
)
if exist "build\windows\Mohashunnyo.exe" (
  start "Mohashunnyo" "build\windows\Mohashunnyo.exe" %*
  exit /b 0
)
if not exist "tools\godot\Godot_v4.7.2-stable_win64.exe" (
  echo Preparing portable Godot and materials...
  python tools\setup.py
  if errorlevel 1 (
    pause
    exit /b 1
  )
)
"tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" --import --headless --editor --quit
if errorlevel 1 (
  pause
  exit /b 1
)
start "Mohashunnyo" "tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" %*
