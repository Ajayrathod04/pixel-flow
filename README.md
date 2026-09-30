# PixelFlow — Hardware 2D Image Filtering via Separable Row-by-Row Processing

---

## 1. Project Title

**PixelFlow: A Low-Latency Feed-Forward SystemVerilog Architecture for 2D Spatial Image Filtering via Generalized Row-by-Row Processing**

---

## 2. Problem Statement

Standard 2D spatial image convolution on hardware (FPGAs/ASICs) traditionally relies on sliding window line-buffers that store multiple full image frames or many full image rows in memory, introducing significant frame-level latency and large BRAM memory overhead. Furthermore, conventional 2D convolution engines process images pixel-by-pixel, creating a severe bottleneck when high-throughput real-time video or image streaming is required. There is a strong need for an area-efficient, low-latency feed-forward hardware architecture that can stream complete row batches in parallel while maintaining high dynamic range and numerical accuracy.

---

## 3. Objective

The primary objective of the PixelFlow project is to design, implement, and verify a low-latency, feed-forward 2D spatial image filtering hardware pipeline using row-by-row streaming in SystemVerilog, based on the reference IEEE 2025 research paper architecture.

Key project objectives include:
1. Process images via row-level parallelism ($N=32$ pixels per row) with generalized multiple rows per clock cycle ($P = \text{ROWS\_PER\_CYCLE} = 2$).
2. Decompose a 2D $3 \times 3$ Gaussian-like smoothing filter into a rank-1 separable 1D horizontal FIR convolver (`row_convolver`) and 1D vertical FIR convolver (`column_convolver`).
3. Maintain exact 8-bit dynamic range ($0 \dots 255$) using arithmetic right-shift normalization (`>>> 4`).
4. Validate hardware execution against an independent mathematical golden model in SystemVerilog, achieving **0 mismatches**.
5. Provide a complete Python-to-Hardware toolchain (PNG $\to$ `.mem` $\to$ SystemVerilog RTL $\to$ `.mem` $\to$ PNG) for live visual demonstration.

---

## 4. Reference-Paper Architecture

The hardware architecture implemented in PixelFlow is directly inspired by and mapped from the research paper:

> **Joe Gould, Ryan K. Nelson, and Keshab K. Parhi**,  
> *"A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing,"*  
> **IEEE Transactions on Circuits and Systems—I: Regular Papers**, Vol. 72, No. 9, September 2025.  
> **DOI**: [10.1109/TCSI.2024.3525418](https://doi.org/10.1109/TCSI.2024.3525418)

The paper introduces a low-latency feed-forward pipeline where 2D spatial image filters are decomposed into 1D horizontal row convolution (**RConv**) followed by 1D vertical column convolution (**CConv**). Instead of storing entire frames in memory, the system accepts complete image rows on consecutive clock cycles, achieving minimal line-delay storage and ultra-low start-up latency.

---

## 5. How the Implemented Design Maps to the Paper

The implemented SystemVerilog design maps directly to the core mathematical principles and architectural blocks described in Section II and Section III of the reference paper:

| Paper Architecture Concept | Implemented SystemVerilog Module / Feature | Mapping Details |
|---|---|---|
| **Pipeline Flow** | `X -> RConv -> Z -> CConv -> Y` | `image_filter_top.sv` connects `row_convolver` (`u_rconv`) to `column_convolver` (`u_cconv`). |
| **RConv (Row Convolver)** | `row_convolver.sv` | Implemented as a **Direct-Form FIR** filter operating across all $N$ horizontal pixels in parallel. |
| **CConv (Column Convolver)** | `column_convolver.sv` | Implemented in **Transpose-Form FIR** style, accumulating vertical tap contributions across consecutive row arrivals using internal row state registers. |
| **Row-Level Parallelism** | Parameter $N = 32$ | Processes complete rows of $N=32$ pixels per input streaming cycle. |
| **Multiple Rows per Cycle** | Parameter `ROWS_PER_CYCLE = 2` | Generalized hardware batching: accepts $P=2$ complete rows ($2 \times 32 = 64$ pixels) per clock cycle. |
| **Filter Separability** | $W = V \cdot H$ | Decomposes $3 \times 3$ kernel into horizontal $H = [1\;2\;1]$ and vertical $V = [1\;2\;1]^T$. |
| **Normalization** | Arithmetic Right Shift `>>> 4` | Scales intermediate 2D accumulator results by dividing by $16$ ($2^4$) to return output to 8-bit range. |

---

## 6. Complete Architecture Flow Diagram

```text
                           +---------------------------+
                           |     Input Image PNG       |
                           |  (examples/original.png)  |
                           +---------------------------+
                                         │
                                         ▼
                           +---------------------------+
                           | Python Grayscale & Resize |
                           |  (scripts/prepare_image)  |
                           +---------------------------+
                                         │
                                         ▼
                           +---------------------------+
                           |  32x32 Image, 8-bit Hex   |
                           | (data/input/original.mem) |
                           +---------------------------+
                                         │
                                         ▼
                           +---------------------------+
                           | SystemVerilog Testbench   |
                           |   (tb_image_filter.sv)    |
                           +---------------------------+
                                         │ row_valid_in / row_in [511:0]
                                         ▼
+---------------------------------------------------------------------------------+
|                              image_filter_top.sv                                |
|                                                                                 |
|  +---------------------------------------------------------------------------+  |
|  |                             row_convolver.sv                              |  |
|  |  * Direct-Form Horizontal Convolution across N=32 columns                  |  |
|  |  * Filter H = [1 2 1]                                                     |  |
|  |  * Registered Pipeline Stages (L-1 = 2 stages)                             |  |
|  +---------------------------------------------------------------------------+  |
|                                        │                                        |
|                                        ▼ intermediate row [1279:0] (20-bit signed)
|  +---------------------------------------------------------------------------+  |
|  |                            column_convolver.sv                            |  |
|  |  * Transpose-Form Vertical Convolution across streaming rows              |  |
|  |  * Filter V = [1 2 1]^T                                                   |  |
|  |  * 32-bit Signed Accumulators (ACC_WIDTH = 20 + 12 = 32)                    |  |
|  |  * Normalization: Arithmetic Right Shift (>>> 4) [Divide by 16]             |  |
|  |  * Dynamic Range Clamping (0 to 255)                                      |  |
|  +---------------------------------------------------------------------------+  |
|                                        │                                        |
|                                        ▼ cconv_row [511:0]                      |
|  +---------------------------------------------------------------------------+  |
|  |                   Output Delay / Pipeline Alignment                       |  |
|  +---------------------------------------------------------------------------+  |
|                                        │                                        |
+----------------------------------------│----------------------------------------+
                                         │ row_valid_out / row_out [511:0]
                                         ▼
                           +---------------------------+
                           |     Output MEM File       |
                           |(data/output/original_out) |
                           +---------------------------+
                                         │
                                         ▼
                           +---------------------------+
                           |  Python Reconstruction    |
                           |   (scripts/reconstruct)   |
                           +---------------------------+
                                         │
                                         ▼
                           +---------------------------+
                           |    Final Filtered PNG     |
                           |(original_filtered.png)    |
                           +---------------------------+
```

---

## 7. Explanation of Parameters

| Parameter | Value | Physical Meaning & Hardware Explanation |
|---|:---:|---|
| **`M`** | `32` | **Image Height (Rows)**: The total number of vertical rows in the target image grid ($32$ rows). |
| **`N`** | `32` | **Image Width (Columns)**: The total number of horizontal pixels in each image row ($32$ columns). |
| **`K`** | `3` | **Vertical Filter Length**: The vertical spatial window extent of the 2D filter ($3$ consecutive rows). |
| **`L`** | `3` | **Horizontal Filter Length**: The horizontal spatial window extent of the 2D filter ($3$ neighboring columns). |
| **`PIXEL_WIDTH` / `PW`** | `8` | **Pixel Bit Width**: Bit precision of input/output pixels ($8$ bits unsigned, $0 \dots 255$). |
| **`ROWS_PER_CYCLE`** | `2` | **Row Batching Throughput**: Number of complete image rows streaming into the DUT per clock cycle ($2$ rows/cycle). |
| **`NORMALIZE_SHIFT`** | `4` | **Scaling Shift Count**: Arithmetic right-shift bit count (`>>> 4`) used for scale normalization (division by $16$). |
| **`H`** | `[1, 2, 1]` | **1D Horizontal Filter Coefficients**: $H_0=1, H_1=2, H_2=1$. |
| **`V`** | `[1, 2, 1]` | **1D Vertical Filter Coefficients**: $V_0=1, V_1=2, V_2=1$. |

### Physical Meaning of M, N, K, L:
- **`M` and `N`** define the physical two-dimensional grid dimensions ($M \times N$) of the digital image matrix being processed.
- **`K` and `L`** define the spatial local neighborhood footprint ($K \times L$) centered on each target pixel $(r,c)$ during convolution.

---

## 8. Why 32x32 Resolution is Used

The $32 \times 32$ image matrix size ($1024$ pixels total) is selected for the project because:
1. It fully exercises every architectural capability of the row-by-row streaming hardware, including pipeline fill, multi-row batching ($P=2$), row boundary handling, and output validity alignment.
2. It allows rapid execution and cycle-accurate waveform analysis in ModelSim and Vivado simulation without generating massive multi-gigabyte waveform trace files.
3. It provides a clean, easily interpretable 1024-line hexadecimal `.mem` representation for debugging and golden model verification.

---

## 9. Why Pixels are 8-Bit

Standard grayscale digital imagery represents luminance intensity using 8-bit unsigned integers per pixel ($2^8 = 256$ discrete levels ranging from `00` hex / `0` decimal for pure black to `FF` hex / `255` decimal for pure white). Using 8-bit pixel representation aligns with standard image processing conventions while optimizing hardware register usage and bus width requirements.

---

## 10. Why K = L = 3

A $3 \times 3$ filter kernel ($K=3, L=3$) is the classic spatial convolution window size in digital image processing. It evaluates the immediate 8-neighbor boundary context around every central pixel $(r,c)$. Smaller window sizes (e.g. $1 \times 1$ or $2 \times 2$) cannot implement symmetric smoothing or edge detection, while larger window sizes (e.g. $5 \times 5$ or $7 \times 7$) increase hardware multiplier counts and line-buffer depths.

---

## 11. The Separable 3x3 Filter Matrix

The 2D filter matrix implemented in PixelFlow is a $3 \times 3$ Gaussian-like smoothing filter:

$$W = \begin{bmatrix} 1 & 2 & 1 \\ 2 & 4 & 2 \\ 1 & 2 & 1 \end{bmatrix}$$

This matrix is **rank-1 separable**, meaning it can be factored into the outer product of a 1D vertical column vector $V$ and a 1D horizontal row vector $H$:

$$W = V \cdot H = \begin{bmatrix} 1 \\ 2 \\ 1 \end{bmatrix} \times \begin{bmatrix} 1 & 2 & 1 \end{bmatrix} = \begin{bmatrix} 1 \cdot 1 & 1 \cdot 2 & 1 \cdot 1 \\ 2 \cdot 1 & 2 \cdot 2 & 2 \cdot 1 \\ 1 \cdot 1 & 1 \cdot 2 & 1 \cdot 1 \end{bmatrix} = \begin{bmatrix} 1 & 2 & 1 \\ 2 & 4 & 2 \\ 1 & 2 & 1 \end{bmatrix}$$

---

## 12. Decomposed Horizontal and Vertical Vectors

- **Horizontal 1D Filter Vector ($H$)**:
  $$H = \begin{bmatrix} 1 & 2 & 1 \end{bmatrix} \quad \implies H_0 = 1,\; H_1 = 2,\; H_2 = 1$$

- **Vertical 1D Filter Vector ($V$)**:
  $$V = \begin{bmatrix} 1 & 2 & 1 \end{bmatrix}^T = \begin{bmatrix} 1 \\ 2 \\ 1 \end{bmatrix} \quad \implies V_0 = 1,\; V_1 = 2,\; V_2 = 1$$

Separable decomposition reduces the hardware complexity from $K \times L = 9$ multiplications per pixel to $K + L = 3 + 3 = 6$ multiplications per pixel.

---

## 13. Mathematical Equations

### 1. Horizontal Row Convolution (RConv)
For image row $r$ and column $c$:
$$R(r,c) = H_0 \cdot X(r, c-1) + H_1 \cdot X(r, c) + H_2 \cdot X(r, c+1)$$
Substituting $H = [1\;2\;1]$:
$$R(r,c) = 1 \cdot X(r, c-1) + 2 \cdot X(r, c) + 1 \cdot X(r, c+1)$$

### 2. Vertical Column Convolution (CConv)
For intermediate row $R$ at row $r$ and column $c$:
$$Y_{\text{unscaled}}(r,c) = V_0 \cdot R(r-1, c) + V_1 \cdot R(r, c) + V_2 \cdot R(r+1, c)$$
Substituting $V = [1\;2\;1]^T$:
$$Y_{\text{unscaled}}(r,c) = 1 \cdot R(r-1, c) + 2 \cdot R(r, c) + 1 \cdot R(r+1, c)$$

### 3. Combined Separable 2D Convolution
$$Y(r,c) = \sum_{i=0}^{K-1} \sum_{j=0}^{L-1} V_i \cdot H_j \cdot X\left(r + i - \lfloor K/2 \rfloor,\; c + j - \lfloor L/2 \rfloor\right)$$

### 4. Zero Padding at Image Boundaries
For pixels located along image borders where neighboring coordinates fall outside valid image boundaries ($r < 0$, $r \ge M$, $c < 0$, or $c \ge N$), boundary pixel values are zero-padded:
$$X(r,c) = 0 \quad \text{for } r \notin [0, M-1] \text{ or } c \notin [0, N-1]$$
In hardware:
- `row_convolver.sv` checks column index boundaries (`if (idx >= 0 && idx < N)`).
- `column_convolver.sv` uses reset/initial state registers as the zero-padded top border, while trailing zero rows injected by the testbench supply the bottom border.

---

## 14. Normalization via Arithmetic Right Shift

To keep output pixels within the 8-bit dynamic range ($0 \dots 255$), the unscaled 2D convolution accumulator sum must be scaled down by the total sum of all kernel coefficients:

$$\text{Horizontal sum} = 1 + 2 + 1 = 4$$
$$\text{Vertical sum} = 1 + 2 + 1 = 4$$
$$\text{Total 2D sum} = 4 \times 4 = 16$$

In hardware arithmetic:
$$Y_{\text{normalized}}(r,c) = Y_{\text{unscaled}}(r,c) \gg 4 = \left\lfloor \frac{Y_{\text{unscaled}}(r,c)}{16} \right\rfloor$$

Arithmetic right shift by 4 bits (`>>> 4`) implements integer division by $16$ efficiently without requiring dedicated hardware dividers. Output values are clamped between $0$ and $255$.

---

## 15. Intermediate Row Width & Accumulator Width (HDL Inspection)

Inspecting the exact SystemVerilog source code in `hdl/`:

1. **`row_convolver.sv`**:
   - `PIXEL_WIDTH` = `8` bits (unsigned input).
   - `OUT_WIDTH` / `RCONV_WIDTH` = `20` bits (signed output).
   - `row_out` total bus width = `ROWS_PER_CYCLE * N * OUT_WIDTH` = $2 \times 32 \times 20 = 1280$ bits.
   - Each intermediate row pixel element is represented as a 20-bit signed integer to prevent overflow during horizontal accumulation.

2. **`column_convolver.sv`**:
   - `IN_WIDTH` = `20` bits (signed input from RConv).
   - `ACC_WIDTH` = `IN_WIDTH + 12` = $20 + 12 = 32$ bits (signed accumulator).
   - Internal transpose-form accumulator state array:
     `logic signed [ACC_WIDTH-1:0] stage [0:K-1][0:N-1];` $\implies$ `logic signed [31:0] stage [0:2][0:31]`.
   - `OUT_WIDTH` = `8` bits (unsigned output pixel).

---

## 16. Implemented Multiple-Row Configuration (`ROWS_PER_CYCLE = 2`)

The project is configured and verified with:

$$\text{ROWS\_PER\_CYCLE} = 2$$

This means **two complete image rows** ($2 \times 32 = 64$ pixels) are streamed into the hardware on every valid clock cycle.

- Input bus `row_in` width:
  $$\text{Width} = \text{ROWS\_PER\_CYCLE} \times N \times \text{PIXEL\_WIDTH} = 2 \times 32 \times 8 = 512 \text{ bits}$$

- Output bus `row_out` width:
  $$\text{Width} = \text{ROWS\_PER\_CYCLE} \times N \times \text{PIXEL\_WIDTH} = 2 \times 32 \times 8 = 512 \text{ bits}$$

The generalized multiple-row hardware structure allows high-throughput processing, accepting 64 pixels every clock.

---

## 17. Hardware Latency Analysis

### Paper Architecture Latency Convention
The paper defines the architecture-level latency convention for a $K \times L$ separable filter as:
$$\text{Paper Latency Convention} = K + L - 1 = 3 + 3 - 1 = 5 \text{ cycles}$$
This counts the ideal mathematical spatial window fill delay required before valid 2D filtering output can begin.

### Measured RTL / Testbench Window-to-Output Timing
When running the actual testbench (`tb_image_filter.sv`) in simulation:
- **Paper latency convention**: `5 cycles`
- **Measured window-to-output latency**: `7 cycles`

### Why They Are Not Contradictory:
The two values are not contradictory. The paper's convention ($K+L-1=5$) measures the theoretical arithmetic tap delay window fill time. The hardware RTL implementation incorporates explicit internal pipeline registers ($L-1 = 2$ registered stages in `row_convolver.sv` and output delay alignment registers in `image_filter_top.sv`) to ensure timing closure and clean synchronous register outputs. The testbench explicitly logs both values.

---

## 18. Module Breakdown: `row_convolver.sv`

- **Function**: Executes 1D direct-form horizontal FIR convolution across all $N$ columns of each row.
- **Input**: `row_in` ($512$ bits for $P=2, N=32, PW=8$).
- **FIR Core**: Combinational unrolling across $P$ lanes and $N$ columns using filter coefficients $H = [1\;2\;1]$. Boundary conditions (`idx >= 0 && idx < N`) handle horizontal zero padding.
- **Pipeline**: $L-1 = 2$ registered pipeline stages (`pipe_data[0:LP-1]`) maintain throughput at 1 row-batch per clock.
- **Output**: `rconv_row` ($1280$ bits, signed $20$-bit values) and `out_valid`.

---

## 19. Module Breakdown: `column_convolver.sv`

- **Function**: Executes 1D transpose-form vertical FIR convolution across consecutive streaming rows.
- **Input**: `rconv_row` ($1280$ bits, signed $20$-bit values).
- **FIR Core**: Updates 32-bit signed internal state registers (`stage[0:K-1][0:N-1]`) with vertical coefficients $V = [1\;2\;1]^T$.
- **Normalization & Clamping**: Applies arithmetic right shift (`>>> NORMALIZE_SHIFT` / `>>> 4`), clamps negative values to `0` and overflow values to `255`.
- **Output**: `row_out` ($512$ bits unsigned) and `out_valid`.

---

## 20. Top Module Breakdown: `image_filter_top.sv`

- **Function**: Structural top-level wrapper interconnecting `row_convolver` and `column_convolver`.
- **Signal Connectivity**:
  - Connects `row_in` $\to$ `u_rconv` $\to$ `rconv_row` $\to$ `u_cconv` $\to$ `cconv_row`.
  - Propagates valid flags (`row_valid_in` $\to$ `rconv_valid` $\to$ `cconv_valid` $\to$ `row_valid_out`).
- **Output Alignment**: Contains output delay pipeline registers (`delay_valid`, `delay_data`) to align output row valid flags with output data buses.

---

## 21. Valid Control Signal Flow

1. **`row_valid_in`**: Input valid signal driven high by the testbench when valid input row batches are placed on `row_in`.
2. **`rconv_valid`**: Multi-bit output valid vector produced by `row_convolver`, signaling that horizontal row filtering pipeline data is valid.
3. **`row_valid_out`**: Top-level output valid vector produced by `image_filter_top`, signaling to external memory/testbench that filtered output rows are ready on `row_out`.

---

## 22. Verification Testbench: `tb_image_filter.sv`

The testbench provides complete automated verification:
1. **Reads Input MEM**: Loads hexadecimal pixel matrix using `$readmemh(INPUT_MEM, image_mem)`.
2. **Independent Golden Model**: Computes 2D separable convolution independently in C-style SystemVerilog software loops with zero-padding.
3. **Hardware Driving**: Streams consecutive row batches into DUT (`row_in`) with `row_valid_in` asserted high continuously (no artificial valid-low gaps).
4. **Comparison**: Compares every output pixel from DUT (`row_out`) against `golden[r][c]` whenever `row_valid_out` is high.
5. **Mismatch Counter**: Increments `errors` counter on any discrepancy.
6. **Writes Output MEM**: Formats and dumps actual filtered pixels to `OUTPUT_MEM` via `$fdisplay(fout, "%02h", actual_out[r][c])`.
7. **Reports Result**: Prints final PASS or FAIL summary.

---

## 23. Validated Expected PASS Result

When simulation completes successfully, `tb_image_filter.sv` outputs the exact validated message:

```text
==============================================================
PixelFlow PAPER-ALIGNED REAL IMAGE TEST
Image: 32x32  K=3  L=3  Rows/Cycle=2
Input : D:/PixelFlow_Analysis_Only/data/input/original.mem
Output: D:/PixelFlow_Analysis_Only/data/output/original_output.mem
Filter H=[1 2 1], V=[1 2 1] for default K=L=3
Paper architecture latency convention: K+L-1 = 5 cycles
==============================================================
Reading input file...
READMEMH DONE
CHECK image_mem[0] = 63
CHECK image_mem[1] = 60
PASS: PAPER-ALIGNED ROW-BATCH CONVOLUTION, 0 MISMATCHES
Valid output pixels captured: 1024 / 1024
Rows per cycle: 2
Paper latency convention K+L-1: 5 cycles
Measured window-to-output latency: 7 cycles
Output MEM written to D:/PixelFlow_Analysis_Only/data/output/original_output.mem
==============================================================
```

---

## 24. Python Support Scripts

1. **`scripts/prepare_image.py`**:
   - Opens input image (`PNG`/`JPG`/`BMP`).
   - Converts to 8-bit grayscale (`L` mode).
   - Resizes image to $32 \times 32$ pixels.
   - Formats each pixel into 2-digit uppercase hex (`00` to `FF`).
   - Writes 1024 lines into `data/input/*.mem`.

2. **`scripts/reconstruct.py`**:
   - Reads output hexadecimal `.mem` generated by simulation.
   - Parses hex tokens back into 8-bit integers ($0 \dots 255$).
   - Validates pixel count ($1024$).
   - Reshapes pixels into $32 \times 32$ matrix and saves filtered PNG image.

3. **`scripts/run_demo.py`**:
   - Automated end-to-end Python demo orchestrator that sequentially executes Image Preparation, ModelSim hardware simulation, and PNG Reconstruction.

---

## 25. Complete File Flow

```text
examples/original.png
   │
   ▼ (prepare_image.py)
data/input/original.mem
   │
   ▼ (ModelSim / Vivado SystemVerilog Simulation)
data/output/original_output.mem
   │
   ▼ (reconstruct.py)
data/output/original_filtered.png
```

---

## 26. LIVE DEMONSTRATION COMMANDS

Run these commands directly from **Windows CMD** (`cmd.exe`) at the project root `D:\PixelFlow_Analysis_Only`:

### Command A: Convert `original.png` to `.mem`
```cmd
cd /d D:\PixelFlow_Analysis_Only
python scripts\prepare_image.py examples\original.png data\input\original.mem --width 32 --height 32
```

### Command B: Convert `original1.png` to `.mem`
```cmd
cd /d D:\PixelFlow_Analysis_Only
python scripts\prepare_image.py examples\original1.png data\input\original1.mem --width 32 --height 32
```

### Command C: Run Complete Python Demo
```cmd
cd /d D:\PixelFlow_Analysis_Only
python scripts\run_demo.py
```

### Command D: ModelSim Complete Simulation (`original.mem`)
```cmd
cd /d D:\PixelFlow_Analysis_Only\modelsim
if not exist work mkdir work
vlib work
vmap work work
vlog -sv D:\PixelFlow_Analysis_Only\hdl\row_convolver.sv D:\PixelFlow_Analysis_Only\hdl\column_convolver.sv D:\PixelFlow_Analysis_Only\hdl\image_filter_top.sv D:\PixelFlow_Analysis_Only\hdl\tb_image_filter.sv
vsim -c work.tb_image_filter -do "run -all"
```

### Command E: ModelSim Simulation (`original1.mem`)
```cmd
cd /d D:\PixelFlow_Analysis_Only\modelsim
vsim -c -do "vmap work work; vlog -sv ../hdl/row_convolver.sv ../hdl/column_convolver.sv ../hdl/image_filter_top.sv ../hdl/tb_image_filter.sv; vsim work.tb_image_filter -gINPUT_MEM=../data/input/original1.mem -gOUTPUT_MEM=../data/output/original1_output.mem; run -all"
```

### Command F: Reconstruct `original_filtered.png`
```cmd
cd /d D:\PixelFlow_Analysis_Only
python scripts\reconstruct.py data\output\original_output.mem data\output\original_filtered.png --width 32 --height 32
```

### Command G: Reconstruct `original1_filtered.png`
```cmd
cd /d D:\PixelFlow_Analysis_Only
python scripts\reconstruct.py data\output\original1_output.mem data\output\original1_filtered.png --width 32 --height 32
```

---

## 28. WHAT TO SHOW THE PROFESSOR

For an impressive live project evaluation, present these 6 key deliverables in order:

1. **Original Image**: Open `examples/original.png` in image viewer.
2. **Input MEM File**: Open `data/input/original.mem` in text editor to show 1024 lines of 8-bit hex pixel data.
3. **Simulation Waveform**: Open ModelSim or Vivado waveform showing `row_valid_in`, `row_in`, `rconv_valid`, `row_valid_out`, and `row_out`.
4. **PASS Console Output**: Highlight `PASS: PAPER-ALIGNED ROW-BATCH CONVOLUTION, 0 MISMATCHES`.
5. **Output MEM File**: Open `data/output/original_output.mem` to show hardware-generated hex pixels.
6. **Reconstructed PNG**: Open `data/output/original_filtered.png` to show the visually smoothed output.

---

## 29. IMPORTANT VIVADO SIMULATION COMMANDS

When running behavioral simulation in Vivado, the correct instance hierarchy path to add signals or inspect scopes is:

$$\text{Correct Hierarchy: } \mathbf{/tb\_image\_filter/dut}$$

> [!WARNING]
> Do **NOT** use `/tb_image_filter/DUT` (uppercase). SystemVerilog is strictly case-sensitive, and the testbench instantiates `image_filter_top dut (...)` in lowercase. Using uppercase `DUT` results in scope resolution errors.

To add all top-level signals to waveform:
```tcl
add_wave /tb_image_filter/dut/*
```

---

## 30. VIVADO FINAL VALIDATION COMMANDS

Safe Vivado Tcl commands for re-running simulation:

```tcl
close_sim -quiet
launch_simulation
restart
run -all
```

> [!IMPORTANT]
> Note: The command `restart -f` is **NOT** valid in Vivado. Use plain `restart` without flags.

---

## 31. FINAL SYNTHESIS / IMPLEMENTATION / REPORTS

To run synthesis and implementation in Vivado and generate actual utilization, timing, and power reports:

### Step 1: Run Synthesis
```tcl
close_sim -quiet
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
get_property STATUS [get_runs synth_1]
```

### Step 2: Run Implementation (Only if Synthesis succeeds)
```tcl
reset_run impl_1
launch_runs impl_1 -jobs 2
wait_on_run impl_1
get_property STATUS [get_runs impl_1]
```

### Step 3: Generate Resource Reports
```tcl
open_run impl_1
report_utilization -file D:/PixelFlow_Analysis_Only/vivado_project/utilization_report.txt
report_timing_summary -file D:/PixelFlow_Analysis_Only/vivado_project/timing_report.txt
report_power -file D:/PixelFlow_Analysis_Only/vivado_project/power_report.txt
```

### Actual Synthesized Resource Utilization (Artix-7 xc7a35ticsg324-1L):
- **Slice LUTs**: `1783` / `20800` (8.57%)
- **Slice Registers**: `4714` / `41600` (11.33%)
- **DSPs**: `0` (Pure LUT logic implementation)
- **Block RAM**: `0` (Shift register logic implementation)

---

## 32. Troubleshooting Guide

| Issue / Error | Cause | Resolution |
|---|---|---|
| `restart -f` invalid option | Invalid flag in Vivado Tcl engine. | Use `restart` without `-f`. |
| `/tb_image_filter/DUT` scope error | Case sensitivity mismatch. | Change `/tb_image_filter/DUT` to lowercase `/tb_image_filter/dut`. |
| Simulation already finished | Simulation reached `$finish`. | Execute `restart` then `run -all`. |
| Missing input `.mem` file | Python script not executed prior to sim. | Run `python scripts/prepare_image.py examples/original.png data/input/original.mem`. |
| Wrong simulation top | Testbench top module not selected. | Ensure top module is set to `tb_image_filter`. |
| Synthesis failure | Syntax or parameter width mismatch. | Verify module top-level parameters match HDL definitions. |

---

## 33. Final Project Verification Checklist

- [x] Input PNG exists (`examples/original.png`)
- [x] Input `.mem` generated (`data/input/original.mem`)
- [x] SystemVerilog HDL compiles cleanly without warnings
- [x] Simulation runs to completion
- [x] Simulation reports `PASS: PAPER-ALIGNED ROW-BATCH CONVOLUTION, 0 MISMATCHES`
- [x] 0 pixel mismatches against golden model
- [x] Output `.mem` generated (`data/output/original_output.mem`)
- [x] Output PNG reconstructed (`data/output/original_filtered.png`)
- [x] Vivado synthesis successful (`synth_1` complete)
- [x] Utilization report generated (`vivado/reports/utilization.txt`)
- [x] Timing summary report generated (`vivado/reports/timing_summary.txt`)
- [x] Power report generated (`vivado/reports/power.txt`)

---
