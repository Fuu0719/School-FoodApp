@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\database_viewer.ps1"
if errorlevel 1 (
  echo.
  echo Database Viewer failed to start. The error is shown above.
  pause
)
