# PixelFlow ModelSim runner
# Usage:
#   vsim -c -do "do run_real_image.do 32 32 2 ../data/input/original.mem ../data/output/original_output.mem"

set N 32
set M 32
set P 2
set INPUT_MEM "../data/input/original.mem"
set OUTPUT_MEM "../data/output/original_output.mem"

if {[info exists 1] && [string is integer -strict $1]} { set N $1 }
if {[info exists 2] && [string is integer -strict $2]} { set M $2 }
if {[info exists 3] && [string is integer -strict $3]} { set P $3 }
if {[info exists 4] && [string length $4] > 0} { set INPUT_MEM $4 }
if {[info exists 5] && [string length $5] > 0} { set OUTPUT_MEM $5 }

set CWD [pwd]
if {[file exists "$CWD/../hdl/row_convolver.sv"]} {
    set PROJ_DIR [file normalize "$CWD/.."]
} else {
    set PROJ_DIR [file normalize "D:/PixelFlow_Analysis_Only"]
}

cd "$PROJ_DIR/modelsim"

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv "$PROJ_DIR/hdl/row_convolver.sv"
vlog -sv "$PROJ_DIR/hdl/column_convolver.sv"
vlog -sv "$PROJ_DIR/hdl/image_filter_top.sv"
vlog -sv "$PROJ_DIR/hdl/tb_image_filter.sv"

vsim -c -voptargs=+acc work.tb_image_filter \
    -gN=$N -gM=$M -gROWS_PER_CYCLE=$P \
    -gINPUT_MEM=$INPUT_MEM -gOUTPUT_MEM=$OUTPUT_MEM \
    -do "run -all; quit -f"

quit -f
