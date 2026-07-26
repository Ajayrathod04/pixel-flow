@echo off
REM ============================================================================
REM Windows Batch Script: run_modelsim.bat
REM Description: Automated ModelSim execution script with error checking
REM ============================================================================

echo ========================================================================
echo   Starting ModelSim Simulation for IEEE 2025 Row-by-Row Image Filter
echo ========================================================================

cd /d "%~dp0\.."

if not exist work (
    vlib work
)
vmap work work

echo [1/2] Compiling HDL design files with -sv flag...
vlog -sv -work work hdl/rconv_array.v hdl/cconv_array.v hdl/image_filter_top.v hdl/tb_image_filter.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] ModelSim compilation failed! Ensure -sv flag is specified.
    exit /b %ERRORLEVEL%
)

echo [2/2] Running ModelSim simulation...
vsim -c -do "run -all; quit -f" work.tb_image_filter
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] ModelSim simulation encountered an error!
    exit /b %ERRORLEVEL%
)

echo ========================================================================
echo   ModelSim Execution Completed Successfully with 0 Errors!
echo ========================================================================
