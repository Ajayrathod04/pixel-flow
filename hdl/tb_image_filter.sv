`timescale 1ns/1ps
// PixelFlow paper-aligned verification testbench.
//
// Key points:
//   * M x N grayscale image.
//   * K x L separable filter.
//   * ROWS_PER_CYCLE complete rows are accepted on every clock.
//   * No artificial "valid low" gap exists between consecutive batches.
//   * The reset state provides the zero-padded top border.
//   * Zero rows are appended after the image for the bottom border.
//   * Golden reference is calculated independently and every valid output
//     pixel is compared against it.
//   * Output MEM contains exactly M*N bytes.

module tb_image_filter #(
    parameter integer M = 32,
    parameter integer N = 32,
    parameter integer PW = 8,
    parameter integer RW = 20,
    parameter integer K = 3,
    parameter integer L = 3,
    parameter integer ROWS_PER_CYCLE = 2,
    parameter integer NORMALIZE_SHIFT = 4,
    parameter integer H0 = 1,
    parameter integer H1 = 2,
    parameter integer H2 = 1,
    parameter integer H3 = 0,
    parameter integer H4 = 0,
    parameter integer H5 = 0,
    parameter integer H6 = 0,
    parameter integer H7 = 0,
    parameter integer H8 = 0,
    parameter integer H9 = 0,
    parameter integer H10 = 0,
    parameter integer V0 = 1,
    parameter integer V1 = 2,
    parameter integer V2 = 1,
    parameter integer V3 = 0,
    parameter integer V4 = 0,
    parameter integer V5 = 0,
    parameter integer V6 = 0,
    parameter integer V7 = 0,
    parameter integer V8 = 0,
    parameter integer V9 = 0,
    parameter integer V10 = 0,
    parameter string INPUT_MEM = "D:/PixelFlow_Analysis_Only/data/input/original.mem",
    parameter string OUTPUT_MEM = "D:/PixelFlow_Analysis_Only/data/output/original_output.mem"
);

    localparam integer TOTAL_BATCHES = (M + K/2 + ROWS_PER_CYCLE - 1) / ROWS_PER_CYCLE;
    localparam integer STREAM_ROWS = TOTAL_BATCHES * ROWS_PER_CYCLE;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic row_valid_in = 1'b0;
    logic [ROWS_PER_CYCLE*N*PW-1:0] row_in = '0;
    logic [ROWS_PER_CYCLE-1:0] rconv_valid;
    logic [ROWS_PER_CYCLE-1:0] row_valid_out;
    logic [ROWS_PER_CYCLE*N*PW-1:0] row_out;

    integer image_mem [0:M*N-1];
    integer golden [0:M-1][0:N-1];
    integer actual_out [0:M-1][0:N-1];

    integer r = 0, c = 0, k = 0, l = 0, idx = 0, lane = 0, batch = 0;
integer out_r = 0, out_c = 0;
    integer center_k = 0, center_l = 0, rr = 0, cc = 0;
    integer hsum = 0, vsum = 0, norm_val = 0;
    integer fout = 0;
    integer errors = 0;
    integer cycle_count = 0;
     integer first_input_cycle = -1;
     integer first_window_complete_cycle = -1;
     integer first_output_cycle = -1;
     integer valid_output_count = 0;
      integer stream_row = 0;
      integer center_row = 0;
       integer got = 0;

    function automatic integer hcoef(input integer t);
        begin
            case (t)
                0: hcoef = H0; 1: hcoef = H1; 2: hcoef = H2;
                3: hcoef = H3; 4: hcoef = H4; 5: hcoef = H5;
                6: hcoef = H6; 7: hcoef = H7; 8: hcoef = H8;
                9: hcoef = H9; 10: hcoef = H10;
                default: hcoef = 0;
            endcase
        end
    endfunction

    function automatic integer vcoef(input integer t);
        begin
            case (t)
                0: vcoef = V0; 1: vcoef = V1; 2: vcoef = V2;
                3: vcoef = V3; 4: vcoef = V4; 5: vcoef = V5;
                6: vcoef = V6; 7: vcoef = V7; 8: vcoef = V8;
                9: vcoef = V9; 10: vcoef = V10;
                default: vcoef = 0;
            endcase
        end
    endfunction

    image_filter_top #(
        .N(N), .PIXEL_WIDTH(PW), .RCONV_WIDTH(RW),
        .K(K), .L(L), .ROWS_PER_CYCLE(ROWS_PER_CYCLE),
        .NORMALIZE_SHIFT(NORMALIZE_SHIFT),
        .H0(H0), .H1(H1), .H2(H2), .H3(H3), .H4(H4),
        .H5(H5), .H6(H6), .H7(H7), .H8(H8), .H9(H9), .H10(H10),
        .V0(V0), .V1(V1), .V2(V2), .V3(V3), .V4(V4),
        .V5(V5), .V6(V6), .V7(V7), .V8(V8), .V9(V9), .V10(V10)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .row_valid_in(row_valid_in),
        .row_in(row_in),
        .rconv_valid(rconv_valid),
        .row_valid_out(row_valid_out),
        .row_out(row_out)
    );

    always #5 clk = ~clk;

    // Independent golden reference: separable K x L convolution with zero padding.
    initial begin
        $display("==============================================================");
        $display("PixelFlow PAPER-ALIGNED REAL IMAGE TEST");
        $display("Image: %0dx%0d  K=%0d  L=%0d  Rows/Cycle=%0d",
                 N, M, K, L, ROWS_PER_CYCLE);
        $display("Input : %s", INPUT_MEM);
        $display("Output: %s", OUTPUT_MEM);
        $display("Filter H=[1 2 1], V=[1 2 1] for default K=L=3");
        $display("Paper architecture latency convention: K+L-1 = %0d cycles", K+L-1);
        $display("==============================================================");

      $display("Reading input file...");
$readmemh(INPUT_MEM, image_mem);
$display("READMEMH DONE");  
      // $display("CHECK INPUT_MEM = %s", INPUT_MEM);
       $display("CHECK image_mem[0] = %0d", image_mem[0]);
        $display("CHECK image_mem[1] = %0d", image_mem[1]);
        center_k = K/2;
        center_l = L/2;

        for (r = 0; r < M; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                vsum = 0;
                for (k = 0; k < K; k = k + 1) begin
                    rr = r + k - center_k;
                    hsum = 0;
                    for (l = 0; l < L; l = l + 1) begin
                        cc = c + l - center_l;
                        if ((rr >= 0) && (rr < M) && (cc >= 0) && (cc < N))
                            hsum = hsum + hcoef(l) * image_mem[rr*N+cc];
                    end
                    vsum = vsum + vcoef(k) * hsum;
                end

                norm_val = vsum >>> NORMALIZE_SHIFT;
                if (norm_val < 0)   norm_val = 0;
                if (norm_val > 255) norm_val = 255;
                golden[r][c] = norm_val;
            end
        end

        for (r = 0; r < M; r = r + 1)
            for (c = 0; c < N; c = c + 1)
                actual_out[r][c] = 0;

        errors = 0;
        valid_output_count = 0;
        cycle_count = 0;
        first_input_cycle = -1;
        first_window_complete_cycle = -1;
        first_output_cycle = -1;

        repeat (2) @(posedge clk);
        rst_n <= 1'b1;

        // Consecutive row batches: no idle cycle between batches.
        // The final incomplete batch is automatically zero-padded.
        for (batch = 0; batch < TOTAL_BATCHES; batch = batch + 1) begin
            @(negedge clk);
            for (lane = 0; lane < ROWS_PER_CYCLE; lane = lane + 1) begin
                stream_row = batch*ROWS_PER_CYCLE + lane;
                for (c = 0; c < N; c = c + 1) begin
                    if (stream_row < M)
                        row_in[(lane*N+c)*PW +: PW] = image_mem[stream_row*N+c];
                    else
                        row_in[(lane*N+c)*PW +: PW] = '0;
                end
            end
            row_valid_in = 1'b1;
            if (first_input_cycle < 0)
                first_input_cycle = cycle_count + 1;
            if ((K/2) < M && batch*ROWS_PER_CYCLE + ROWS_PER_CYCLE-1 >= K/2 &&
                first_window_complete_cycle < 0)
                first_window_complete_cycle = cycle_count + 1;
        end

        @(negedge clk);
        row_valid_in = 1'b0;
        row_in = '0;

        repeat (K + L + 6) @(posedge clk);

        fout = $fopen(OUTPUT_MEM, "w");
        if (fout == 0) begin
            $display("ERROR: cannot open output file %s", OUTPUT_MEM);
            $finish;
        end

        for (r = 0; r < M; r = r + 1)
            for (c = 0; c < N; c = c + 1)
                $fdisplay(fout, "%02h", actual_out[r][c]);
        $fclose(fout);

        if (errors == 0)
            $display("PASS: PAPER-ALIGNED ROW-BATCH CONVOLUTION, 0 MISMATCHES");
        else
            $display("FAIL: mismatches=%0d", errors);

        $display("Valid output pixels captured: %0d / %0d", valid_output_count, M*N);
        $display("Rows per cycle: %0d", ROWS_PER_CYCLE);
        $display("Paper latency convention K+L-1: %0d cycles", K+L-1);
        if ((first_output_cycle >= 0) && (first_window_complete_cycle >= 0))
            $display("Measured window-to-output latency: %0d cycles",
                     first_output_cycle - first_window_complete_cycle);
        $display("Output MEM written to %s", OUTPUT_MEM);
        $display("==============================================================");
        $finish;
    end

    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        if (|row_valid_out) begin
            if (first_output_cycle < 0)
                first_output_cycle = cycle_count;

            for (lane = 0; lane < ROWS_PER_CYCLE; lane = lane + 1) begin
                if (row_valid_out[lane]) begin
                    // The CConv stream is causal; for odd K the output is centered
                    // on the current stream row minus K/2.
                    center_row = (lane + ((cycle_count - 1) * ROWS_PER_CYCLE)) - (K/2);
                    // The exact absolute stream row is reconstructed from the
                    // sequence of valid batches below using out_count.
                    // For this fixed-width educational stream, valid outputs are
                    // naturally ordered, so use valid_output_count as the row index.
                   out_r = valid_output_count / N;
                   out_c = 0;

                   for (out_c = 0; out_c < N; out_c = out_c + 1) begin
                        got = row_out[(lane*N+out_c)*PW +: PW];
                       if (out_r < M)
    actual_out[out_r][out_c] = got;

if ((out_r < M) && (got !== golden[out_r][out_c])) begin
    $display("MISMATCH row=%0d col=%0d expected=%0d got=%0d",
             out_r, out_c, golden[out_r][out_c], got);
                            errors = errors + 1;
                        end
                    end

                    valid_output_count = valid_output_count + N;
                end
            end
        end
    end

endmodule
