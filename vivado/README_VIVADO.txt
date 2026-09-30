PIXELFLOW - VIVADO 2018.1 READY
================================

This ZIP is prepared for Vivado behavioral simulation (XSim).
The actual filtering remains in:
  hdl/row_convolver.sv
  hdl/column_convolver.sv
  hdl/image_filter_top.sv

Testbench:
  hdl/tb_image_filter.sv

FASTEST METHOD
--------------
1. Extract this folder to any location.
2. Make sure Vivado 2018.1 is installed.
3. Double-click:
      vivado/create_and_run.bat
4. The Tcl script creates the Vivado project automatically and runs XSim.
5. Look for:
      PASS: REAL IMAGE row + column convolution verified, 0 mismatches

GUI METHOD
----------
Double-click:
      vivado/open_project.bat
Then in Vivado:
  Flow -> Simulation -> Run Simulation -> Run Behavioral Simulation

INPUT/OUTPUT
------------
Input:
  data/input/input.mem
Output:
  data/output/output.mem

IMPORTANT
---------
This source ZIP has no board-specific XDC constraints or FPGA I/O wrapper.
Therefore this package is ready for Vivado compilation/behavioral simulation,
not for generating a physical board bitstream. The HDL top is a datapath,
not a board-level top module.
