set HERE [file normalize [file dirname [info script]]]
set ROOT [file normalize [file join $HERE ..]]
set XPR [file join $ROOT vivado_project PixelFlow_Vivado.xpr]
if {![file exists $XPR]} {
    source [file join $HERE create_project.tcl]
}
open_project $XPR
puts "PixelFlow Vivado project is open."
