# PixelFlow - run behavioral XSim
set HERE [file normalize [file dirname [info script]]]
set ROOT [file normalize [file join $HERE ..]]
set XPR [file join $ROOT vivado_project pixelflow_vivado.xpr]

if {![file exists $XPR]} {
    source [file join $HERE create_project.tcl]
} else {
    open_project $XPR
}

set IN_MEM [string map {\\ /} [file normalize [file join $ROOT data input input.mem]]]
set OUT_MEM [string map {\\ /} [file normalize [file join $ROOT data output output.mem]]]

set_property generic "INPUT_MEM=\"$IN_MEM\" OUTPUT_MEM=\"$OUT_MEM\" ROWS_PER_CYCLE=2 K=3 L=3" [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral
run all

puts "==============================================="
puts "PixelFlow XSim simulation finished."
puts "Expected: PASS ... 0 MISMATCHES"
puts "Output: $OUT_MEM"
puts "==============================================="
