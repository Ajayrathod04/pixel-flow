@echo off
REM ============================================================================
REM Windows Batch Script: run_vivado.bat
REM Description: Automated Vivado execution script with error checking
REM ============================================================================

echo ========================================================================
echo   Starting Vivado XSIM Simulation for IEEE 2025 Row-by-Row Image Filter
echo ========================================================================

cd /d "%~dp0\.."

echo [1/3] Compiling HDL design files with xvlog -sv...
xvlog -sv hdl/rconv_array.v hdl/cconv_array.v hdl/image_filter_top.v hdl/tb_image_filter.v
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Vivado xvlog compilation failed! Check syntax or SystemVerilog flags.
    exit /b %ERRORLEVEL%
)

echo [2/3] Elaborating simulation snapshot with xelab...
xelab tb_image_filter -s top_sim
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Vivado xelab elaboration failed!
    exit /b %ERRORLEVEL%
)

echo [3/3] Running Vivado XSIM simulation...
xsim top_sim -runall
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Vivado xsim simulation failed!
    exit /b %ERRORLEVEL%
)

echo ========================================================================
echo   Vivado XSIM Execution Completed Successfully with 0 Errors!
echo ========================================================================
