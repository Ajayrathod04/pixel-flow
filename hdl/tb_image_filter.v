// ============================================================================
// Module: tb_image_filter
// Description: Self-Checking Testbench for Low-Latency 2D Image Filter Accelerator
// Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
// Authors: Joe Gould, Ryan K. Nelson, Keshab K. Parhi (IEEE TCSI 2025)
// ============================================================================

`timescale 1ns / 1ps

module tb_image_filter;

    parameter M            = 8;  // Image Height (Rows)
    parameter N            = 8;  // Image Width (Columns)
    parameter K            = 3;  // Filter Height
    parameter L            = 3;  // Filter Width
    parameter PIXEL_WIDTH  = 8;  // Input pixel bit width
    parameter WEIGHT_WIDTH = 8;  // Weight bit width
    parameter RCONV_WIDTH  = 24; // Intermediate width
    parameter OUT_WIDTH    = 32; // Final output width

    reg                               clk;
    reg                               rst_n;
    reg                               start;
    reg                               row_valid_in;
    reg  [N*PIXEL_WIDTH-1:0]          row_in;
    reg  [L*WEIGHT_WIDTH-1:0]         row_weights;
    reg  [K*WEIGHT_WIDTH-1:0]         col_weights;
    wire                              row_valid_out;
    wire [N*OUT_WIDTH-1:0]            row_out;

    // Clock Generation (100 MHz, 10ns period)
    always #5 clk = ~clk;

    // Instantiate Top-Level Accelerator
    image_filter_top #(
        .M(M),
        .N(N),
        .K(K),
        .L(L),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .RCONV_WIDTH(RCONV_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .row_valid_in(row_valid_in),
        .row_in(row_in),
        .row_weights(row_weights),
        .col_weights(col_weights),
        .row_valid_out(row_valid_out),
        .row_out(row_out)
    );

    // Test Data Arrays
    reg [PIXEL_WIDTH-1:0] test_image [0:M-1][0:N-1];
    reg signed [WEIGHT_WIDTH-1:0] w_row [0:L-1];
    reg signed [WEIGHT_WIDTH-1:0] w_col [0:K-1];
    reg signed [OUT_WIDTH-1:0] golden_out [0:M-1][0:N-1];

    // Variables for simulation tracking
    integer r, c, kr, kc;
    integer start_cycle, first_out_cycle, end_cycle;
    integer cycle_count;
    integer out_row_cnt;
    integer errors;
    integer in_r, in_c;
    integer out_file;

    // Cycle Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_count <= 0;
        else cycle_count <= cycle_count + 1;
    end

    // Golden 2D Convolution Reference Model Function
    initial begin
        // 1. Initialize Test Image (Flower / Sequential Pixel Patterns)
        for (r = 0; r < M; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                test_image[r][c] = (r + 1) * 10 + (c + 1);
            end
        end

        // 2. Define Filter Weights (3x3 Separable Filter: v^T = [-1, 3, -1], u = [-1, 3, -1])
        w_row[0] = 8'sd1;  w_row[1] = 8'sd2;  w_row[2] = 8'sd1;
        w_col[0] = 8'sd1;  w_col[1] = 8'sd1;  w_col[2] = 8'sd1;

        // Pack Weights for UUT
        row_weights = {w_row[2], w_row[1], w_row[0]};
        col_weights = {w_col[2], w_col[1], w_col[0]};

        // 3. Compute Golden 2D Convolution Reference Image
        for (r = 0; r < M; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                golden_out[r][c] = 0;
                for (kr = 0; kr < K; kr = kr + 1) begin
                    for (kc = 0; kc < L; kc = kc + 1) begin
                        in_r = r + kr - (K-1)/2;
                        in_c = c + kc - (L-1)/2;
                        if ((in_r >= 0) && (in_r < M) && (in_c >= 0) && (in_c < N)) begin
                            golden_out[r][c] = golden_out[r][c] + 
                                $signed({1'b0, test_image[in_r][in_c]}) * 
                                w_col[kr] * w_row[kc];
                        end
                    end
                end
            end
        end
    end

    // Stimulus and Verification Process
    initial begin
        // Initialize Signals & Files
        clk          = 0;
        rst_n        = 0;
        start        = 0;
        row_valid_in = 0;
        row_in       = 0;
        out_row_cnt  = 0;
        errors       = 0;

        out_file = $fopen("hdl/flower_output_simulation.mem", "w");

        #20;
        rst_n = 1;
        #10;
        
        $display("------------------------------------------------------------");
        $display("Starting IEEE 2025 Row-by-Row Image Filter Acceleration Test");
        $display("Target Image: Sunflower (flower) | Size: %0dx%0d | Filter: %0dx%0d", M, N, K, L);
        $display("------------------------------------------------------------");

        // Assert Start Pulse
        @(posedge clk);
        start       <= 1;
        start_cycle  = cycle_count;
        @(posedge clk);
        start       <= 0;

        // Stream Image Rows sequentially (1 row per clock cycle)
        for (r = 0; r < M; r = r + 1) begin
            row_valid_in <= 1'b1;
            for (c = 0; c < N; c = c + 1) begin
                row_in[c*PIXEL_WIDTH +: PIXEL_WIDTH] <= test_image[r][c];
            end
            @(posedge clk);
        end
        row_valid_in <= 1'b0;
        row_in       <= 0;

        // Wait for all output rows to complete
        wait (out_row_cnt == M);
        end_cycle = cycle_count;

        $fclose(out_file);

        $display("------------------------------------------------------------");
        $display("PERFORMANCE & LATENCY RESULTS:");
        $display("Start Cycle: %0d", start_cycle);
        $display("First Output Valid Cycle: %0d", first_out_cycle);
        $display("Latency to First Output Row: %0d Clock Cycles", first_out_cycle - start_cycle);
        $display("Theoretical Expected Lag: %0d Clock Cycles", (K-1)/2 + 2);
        $display("Total Frame Completion Time: %0d Clock Cycles", end_cycle - start_cycle);
        $display("------------------------------------------------------------");

        if (errors == 0) begin
            $display(">>> SUCCESS: VERILOG HARDWARE OUTPUT MATCHES GOLDEN MODEL PERFECTLY! (PASS) <<<");
        end else begin
            $display(">>> FAILURE: DETECTED %0d MISMATCHES IN OUTPUT ROWS! (FAIL) <<<", errors);
        end
        $display("------------------------------------------------------------");

        #50;
        $finish;
    end

    // Monitor Output Rows and Check against Golden Reference
    always @(posedge clk) begin
        if (row_valid_out) begin
            if (out_row_cnt == 0) begin
                first_out_cycle = cycle_count;
            end
            
            $display("Receiving Output Row %0d at Cycle %0d...", out_row_cnt, cycle_count);
            for (c = 0; c < N; c = c + 1) begin
                $fwrite(out_file, "%h ", row_out[c*OUT_WIDTH +: OUT_WIDTH]);
                if ($signed(row_out[c*OUT_WIDTH +: OUT_WIDTH]) !== golden_out[out_row_cnt][c]) begin
                    $display("ERROR at Row %0d, Col %0d: Expected=%0d, Got=%0d", 
                             out_row_cnt, c, golden_out[out_row_cnt][c], $signed(row_out[c*OUT_WIDTH +: OUT_WIDTH]));
                    errors = errors + 1;
                end
            end
            $fwrite(out_file, "\n");
            out_row_cnt = out_row_cnt + 1;
        end
    end

endmodule
