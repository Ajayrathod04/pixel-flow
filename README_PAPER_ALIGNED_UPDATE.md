
# PixelFlow — Paper-aligned update

This version addresses the three implementation gaps :

1. **General K/L architecture**
   - `K` and `L` are parameters.
   - The row and column FIR coefficient sets are exposed as `H0..H10` and `V0..V10`.
   - The supplied demonstration remains the paper-style separable 3x3 filter:
     `H=[1 2 1]`, `V=[1 2 1]^T`.

2. **Multiple rows per clock**
   - `ROWS_PER_CYCLE` is now a parameter.
   - The supplied project uses `ROWS_PER_CYCLE=2`.
   - One valid clock accepts two complete image rows (2 × 32 pixels).
   - No artificial low-valid gap is inserted between consecutive row batches.
   - The CConv stage processes the two consecutive rows in the same clock and returns two row results.

3. **Vivado synthesis/resource measurement**
   - `vivado/run_synthesis.tcl` synthesizes `image_filter_top`.
   - It writes:
       `vivado/reports/utilization.txt`
       `vivado/reports/timing_summary.txt`
   - These are actual measurements for the selected Artix-7 part and this implementation.
   - They must not be confused with the paper's Virtex-7 results.

## Paper mapping

`X -> RConv -> Z -> CConv -> Y`

- RConv: direct-form FIR across a row.
- CConv: transpose-form FIR state update across the row stream.
- Row-level parallelism: `N=32` pixels are processed in parallel; with `ROWS_PER_CYCLE=2`, two rows are accepted per clock.
- For the 3x3 case, `K=L=3`.
- Paper latency convention: `K+L-1 = 5` cycles, and the top-level explicitly registers the CConv output so the measured window-to-output latency is 5 cycles for K=L=3.
- Throughput after pipeline fill: one row-batch per clock; with P=2, two rows per clock.

## Why `row_in` and `row_out` are 512 bits now

The old design had one row:
`N * PW = 32 * 8 = 256 bits`.

The new default has two rows per clock:
`ROWS_PER_CYCLE * N * PW = 2 * 32 * 8 = 512 bits`.

Therefore:
- `row_in[511:0]` = two input rows.
- `row_out[511:0]` = two output rows.
- Each row is still 256 bits.

## Exact ModelSim command

From the `modelsim` directory:

```bat
vsim -c -do "do run_real_image.do 32 32 2 ../data/input/original.mem ../data/output/original_output.mem"
```

## Exact one-command demo

From project root:

```bat
python scripts\run_demo.py
```

## Exact Vivado project creation

From Vivado Tcl Console:

```tcl
cd D:/PixelFlow_Analysis_Only
source D:/PixelFlow_Analysis_Only/vivado/create_project.tcl
```

Then the project is:

```text
D:/PixelFlow_Analysis_Only/vivado_project/pixelflow_vivado.xpr
```

## Vivado behavioral simulation

```tcl
source D:/PixelFlow_Analysis_Only/vivado/run_simulation.tcl
```

## Vivado synthesis/resource report

```tcl
source D:/PixelFlow_Analysis_Only/vivado/run_synthesis.tcl
```

The report values are implementation-specific and should be read from the generated files.

## Important scope statement for the viva

The research paper's reported FPGA results use a Xilinx Virtex-7 2000T at 100 MHz and include larger image/filter configurations. This project implements the core architecture and additionally provides a parameterized multiple-row-per-cycle version. Its own LUT/FF/timing values must come from the included Vivado synthesis run; do not claim the paper's numerical results as project measurements.
