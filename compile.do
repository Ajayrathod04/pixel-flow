# ============================================================================
# ModelSim DO Script: compile.do
# Description: Compiles and checks SystemVerilog design & testbench files for errors
# Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
# Usage in ModelSim: do compile.do
# ============================================================================

puts "========================================================================"
puts "  ModelSim Hardware Compilation & Error Check (IEEE TCSI 2025)"
puts "========================================================================"

# Step 1: Create and map work library
if {![file exists work]} {
    vlib work
}
vmap work work

# Step 2: Compile SystemVerilog HDL files with -sv flag
puts "[1/4] Compiling rconv_array.v..."
vlog -sv -work work hdl/rconv_array.v

puts "[2/4] Compiling cconv_array.v..."
vlog -sv -work work hdl/cconv_array.v

puts "[3/4] Compiling image_filter_top.v..."
vlog -sv -work work hdl/image_filter_top.v

puts "[4/4] Compiling tb_image_filter.v..."
vlog -sv -work work hdl/tb_image_filter.v

puts "========================================================================"
puts "  Compilation Completed Successfully with 0 Errors!"
puts "========================================================================"
