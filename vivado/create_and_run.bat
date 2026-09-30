@echo off
cd /d "%~dp0.."
vivado -mode batch -source vivado\create_project.tcl
echo.
echo Project created at:
echo %CD%\vivado_project\pixelflow_vivado.xpr
pause
