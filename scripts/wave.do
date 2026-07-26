# ============================================================================
# ModelSim Waveform Format Script: scripts/wave.do
# Description: Configures waveform signals, continuous clock force, dividers, radixes
# Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
# ============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

# --- Force Continuous 100 MHz Clock (10 ns Period: 5 ns HIGH, 5 ns LOW) ---
force -freeze /tb_image_filter/clk 1 0, 0 {5 ns} -repeat 10ns

# --- Group 1: Global Clock & Reset Controls ---
add wave -divider "GLOBAL CLOCK AND RESET"
add wave -color Yellow /tb_image_filter/clk
add wave -color Red /tb_image_filter/rst_n
add wave -color Cyan /tb_image_filter/start
add wave -color Magenta -radix unsigned /tb_image_filter/cycle_count

# --- Group 2: Streaming Input Row Interfaces ---
add wave -divider "STREAMING INPUT ROW INTERFACE"
add wave -color Green /tb_image_filter/row_valid_in
add wave -color Green -radix hexadecimal /tb_image_filter/row_in
add wave -color Blue -radix decimal /tb_image_filter/row_weights
add wave -color Blue -radix decimal /tb_image_filter/col_weights

# --- Group 3: RConv Array Internal Pipeline ---
add wave -divider "RCONV ARRAY PIPELINE"
add wave -color Lime /tb_image_filter/uut/u_rconv/in_valid
add wave -color Lime -radix hexadecimal /tb_image_filter/uut/u_rconv/row_in
add wave -color SpringGreen /tb_image_filter/uut/u_rconv/out_valid
add wave -color SpringGreen -radix decimal /tb_image_filter/uut/u_rconv/row_out

# --- Group 4: CConv Array Internal Line Delays ---
add wave -divider "CCONV ARRAY LINE DELAYS"
add wave -color Orange /tb_image_filter/uut/u_cconv/cconv_en
add wave -color Orange -radix hexadecimal /tb_image_filter/uut/u_cconv/delay_regs

# --- Group 5: Streaming Output Row Interfaces ---
add wave -divider "STREAMING OUTPUT ROW INTERFACE"
add wave -color Yellow /tb_image_filter/row_valid_out
add wave -color Yellow -radix decimal /tb_image_filter/row_out
add wave -color White -radix unsigned /tb_image_filter/out_row_cnt
add wave -color Red -radix unsigned /tb_image_filter/errors

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
wave zoomfull
