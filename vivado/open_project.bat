@echo off
setlocal
cd /d "%~dp0.."
where vivado.bat >nul 2>&1
if errorlevel 1 (
  echo ERROR: vivado.bat was not found in PATH.
  pause
  exit /b 1
)
start "PixelFlow Vivado" vivado.bat -mode gui -source vivado\open_project.tcl
