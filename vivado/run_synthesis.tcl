# PixelFlow - synthesis/resource report
# This is synthesis only; no board I/O constraints are required.
set HERE [file normalize [file dirname [info script]]]
set ROOT [file normalize [file join $HERE ..]]
set XPR [file join $ROOT vivado_project pixelflow_vivado.xpr]

if {![file exists $XPR]} {
    source [file join $HERE create_project.tcl]
} else {
    open_project $XPR
}

set_property top image_filter_top [get_filesets sources_1]
set_property generic "ROWS_PER_CYCLE=2 K=3 L=3" [get_filesets sources_1]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1

file mkdir [file join $ROOT vivado reports]
report_utilization -file [file join $ROOT vivado reports utilization.txt]
report_timing_summary -file [file join $ROOT vivado reports timing_summary.txt]

puts "==============================================="
puts "PixelFlow synthesis completed."
puts "Reports:"
puts "  vivado/reports/utilization.txt"
puts "  vivado/reports/timing_summary.txt"
puts "==============================================="
