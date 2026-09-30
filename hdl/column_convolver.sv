`timescale 1ns/1ps
// PixelFlow CConv Array
// Paper-aligned concept:
//   - vertical FIR is implemented in transpose-form style
//   - internal FIR states carry the previous-row contributions
//   - ROWS_PER_CYCLE consecutive rows are processed in one clock
//   - after the pipeline is filled, output throughput is one row-batch/clock
//
// For the supplied default filter:
//   K=3, V=[1 2 1]^T
//
// The input stream is row 0, row 1, ... .  Because the filter is centered,
// the output corresponding to row r is produced when row r+K/2 arrives.
// The testbench uses the reset state as the zero-padded top border and sends
// one zero row at the end for the bottom border.

module column_convolver #(
    parameter integer N = 32,
    parameter integer IN_WIDTH = 20,
    parameter integer OUT_WIDTH = 8,
    parameter integer K = 3,
    parameter integer ROWS_PER_CYCLE = 1,
    parameter integer NORMALIZE_SHIFT = 4,
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
    parameter integer V10 = 0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,
    input  logic signed [ROWS_PER_CYCLE*N*IN_WIDTH-1:0] row_in,
    output logic [ROWS_PER_CYCLE-1:0] out_valid,
    output logic [ROWS_PER_CYCLE*N*OUT_WIDTH-1:0] row_out
);

    localparam integer CENTER = K/2;
    localparam integer ACC_WIDTH = IN_WIDTH + 12;

    // Transpose-form FIR state: stage 0 is the output accumulator state.
    logic signed [ACC_WIDTH-1:0] stage [0:K-1][0:N-1];
    logic signed [ACC_WIDTH-1:0] tmp_stage [0:K-1][0:N-1];
    logic signed [ACC_WIDTH-1:0] calc_out [0:ROWS_PER_CYCLE-1][0:N-1];
    logic [ROWS_PER_CYCLE-1:0] calc_valid;

    integer lane, c, j, row_index, center_row;
    integer x, y, i;

    function automatic integer vcoef(input integer t);
        begin
            case (t)
                0:  vcoef = V0;
                1:  vcoef = V1;
                2:  vcoef = V2;
                3:  vcoef = V3;
                4:  vcoef = V4;
                5:  vcoef = V5;
                6:  vcoef = V6;
                7:  vcoef = V7;
                8:  vcoef = V8;
                9:  vcoef = V9;
                10: vcoef = V10;
                default: vcoef = 0;
            endcase
        end
    endfunction

    // Combinationally unroll ROWS_PER_CYCLE consecutive row arrivals.
    // This is the generalized multiple-rows-per-cycle form: one clock accepts
    // P rows, with P=ROWS_PER_CYCLE.
    always_comb begin
        for (j = 0; j < K; j = j + 1)
            for (c = 0; c < N; c = c + 1)
                tmp_stage[j][c] = stage[j][c];

        for (lane = 0; lane < ROWS_PER_CYCLE; lane = lane + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                x = $signed(row_in[(lane*N+c)*IN_WIDTH +: IN_WIDTH]);

                // y = V0*x[n] + V1*x[n-1] + ... + V(K-1)*x[n-K+1]
                // implemented as a transpose-form FIR state update.
                for (j = 0; j < K-1; j = j + 1)
                    tmp_stage[j][c] = vcoef(j) * x + tmp_stage[j+1][c];

                tmp_stage[K-1][c] = vcoef(K-1) * x;
                calc_out[lane][c] = tmp_stage[0][c];
            end

            // The causal FIR output is centered on row (current-K/2).
            // Reset/initial states supply the zero-padded top border.
            row_index = lane;
            center_row = row_index - CENTER;
            calc_valid[lane] = (center_row >= 0);
        end
    end

    // A batch's row number is tracked so validity can be aligned correctly.
    integer stream_row_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_out         <= '0;
            out_valid       <= '0;
            stream_row_count <= 0;
            for (j = 0; j < K; j = j + 1)
                for (c = 0; c < N; c = c + 1)
                    stage[j][c] <= '0;
        end else begin
            out_valid <= '0;

            if (in_valid) begin
                // Store the transpose-form FIR state.
                for (j = 0; j < K; j = j + 1)
                    for (c = 0; c < N; c = c + 1)
                        stage[j][c] <= tmp_stage[j][c];

                for (lane = 0; lane < ROWS_PER_CYCLE; lane = lane + 1) begin
                    for (c = 0; c < N; c = c + 1) begin
                        y = calc_out[lane][c];
                        y = y >>> NORMALIZE_SHIFT;
                        if (y < 0)   y = 0;
                        if (y > 255) y = 255;
                        row_out[(lane*N+c)*OUT_WIDTH +: OUT_WIDTH] <= y[OUT_WIDTH-1:0];
                    end

                    // Validity is based on the absolute stream row.
                    row_index = stream_row_count + lane;
                    center_row = row_index - CENTER;
                    if ((center_row >= 0))
                        out_valid[lane] <= 1'b1;
                end

                stream_row_count <= stream_row_count + ROWS_PER_CYCLE;
            end
        end
    end
endmodule
