# PixelFlow - Vivado project generator
# Compatible with Vivado 2025.1 and similar versions.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set PROJ_DIR [file join $ROOT vivado_project]
set PROJ_NAME pixelflow_vivado

set preferred_parts {xc7a35ticsg324-1L xc7a35ticsg324-1 xc7a35tcpg236-1}
set PART ""
foreach p $preferred_parts {
    if {[llength [get_parts -quiet $p]] > 0} {
        set PART $p
        break
    }
}
if {$PART eq ""} {
    set candidates [get_parts -quiet *xc7a35t*]
    if {[llength $candidates] == 0} {
        error "No XC7A35T Artix-7 part is installed in this Vivado installation."
    }
    set PART [lindex $candidates 0]
}

puts "PixelFlow root: $ROOT"
puts "Vivado part:    $PART"

close_project -quiet
if {[file exists $PROJ_DIR]} {
    file delete -force $PROJ_DIR
}

create_project $PROJ_NAME $PROJ_DIR -part $PART -force
set_property target_language SystemVerilog [current_project]

add_files [list \
    [file join $ROOT hdl row_convolver.sv] \
    [file join $ROOT hdl column_convolver.sv] \
    [file join $ROOT hdl image_filter_top.sv]]

add_files -fileset sim_1 [file join $ROOT hdl tb_image_filter.sv]

set_property top image_filter_top [get_filesets sources_1]
set_property top tb_image_filter [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set IN_MEM [string map {\\ /} [file normalize [file join $ROOT data input input.mem]]]
set OUT_MEM [string map {\\ /} [file normalize [file join $ROOT data output output.mem]]]
set_property generic "INPUT_MEM=\"$IN_MEM\" OUTPUT_MEM=\"$OUT_MEM\" ROWS_PER_CYCLE=2 K=3 L=3" [get_filesets sim_1]

save_project_as $PROJ_NAME [file join $PROJ_DIR ${PROJ_NAME}.xpr] -force

puts "==============================================="
puts "PixelFlow Vivado project created successfully."
puts "Project: [file join $PROJ_DIR ${PROJ_NAME}.xpr]"
puts "Configuration: N=32, K=L=3, ROWS_PER_CYCLE=2"
puts "==============================================="
