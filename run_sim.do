# ============================================================================
# ModelSim DO Script: run_sim.do
# Description: One-click ModelSim compilation, continuous clock force, waveform & simulation
# Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
# Usage: Open ModelSim and type: do run_sim.do
# ============================================================================

# Step 1: Execute compile.do
if {[file exists compile.do]} {
    do compile.do
} elseif {[file exists scripts/compile.do]} {
    do scripts/compile.do
}

# Step 2: Elaborate and launch simulation with -onfinish stop
puts "------------------------------------------------------------------------"
puts "  Launching ModelSim Simulation (Stopping at finish)...  "
puts "------------------------------------------------------------------------"
vsim -onfinish stop work.tb_image_filter

# Step 3: Force Continuous 100 MHz Clock (10 ns Period: 5 ns HIGH, 5 ns LOW)
force -freeze /tb_image_filter/clk 1 0, 0 {5 ns} -repeat 10ns

# Step 4: Configure Waveform window & auto-zoom if in GUI mode
if {[info exists ::vsimPriv(gui)] && $::vsimPriv(gui)} {
    if {[file exists scripts/wave.do]} {
        do scripts/wave.do
    } elseif {[file exists wave.do]} {
        do wave.do
    }
    run -all
    wave zoomfull
} else {
    run -all
    quit -f
}
