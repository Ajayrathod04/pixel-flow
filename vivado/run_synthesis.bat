@echo off
cd /d "%~dp0.."
vivado -mode batch -source vivado\run_synthesis.tcl
pause
