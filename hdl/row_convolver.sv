`timescale 1ns/1ps
// PixelFlow RConv Array
// Paper-aligned concept:
//   - direct-form FIR across each image row
//   - processes ROWS_PER_CYCLE complete rows in parallel
//   - one batch of rows can be accepted every clock
//   - L-1 registered pipeline stages are used for the row-convolution path
//
// For the supplied default filter:
//   L=3, H=[1 2 1]
//
// The coefficient parameters H0..H10 make the datapath configurable without
// relying on SystemVerilog parameter arrays (useful for older ModelSim).

module row_convolver #(
    parameter integer N = 32,
    parameter integer PIXEL_WIDTH = 8,
    parameter integer OUT_WIDTH = 20,
    parameter integer L = 3,
    parameter integer ROWS_PER_CYCLE = 1,
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
    parameter integer H10 = 0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,
    input  logic [ROWS_PER_CYCLE*N*PIXEL_WIDTH-1:0] row_in,
    output logic out_valid,
    output logic signed [ROWS_PER_CYCLE*N*OUT_WIDTH-1:0] row_out
);

    localparam integer LP = (L > 1) ? (L-1) : 1;
    localparam integer CENTER = L/2;

    logic signed [ROWS_PER_CYCLE*N*OUT_WIDTH-1:0] calc_row;
    logic signed [ROWS_PER_CYCLE*N*OUT_WIDTH-1:0] pipe_data [0:LP-1];
    logic pipe_valid [0:LP-1];

    integer lane, c, k, idx, s, i;

    function automatic integer hcoef(input integer t);
        begin
            case (t)
                0:  hcoef = H0;
                1:  hcoef = H1;
                2:  hcoef = H2;
                3:  hcoef = H3;
                4:  hcoef = H4;
                5:  hcoef = H5;
                6:  hcoef = H6;
                7:  hcoef = H7;
                8:  hcoef = H8;
                9:  hcoef = H9;
                10: hcoef = H10;
                default: hcoef = 0;
            endcase
        end
    endfunction

    // Direct-form FIR across each row.
    always_comb begin
        calc_row = '0;
        for (lane = 0; lane < ROWS_PER_CYCLE; lane = lane + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                s = 0;
                for (k = 0; k < L; k = k + 1) begin
                    idx = c + k - CENTER;
                    if ((idx >= 0) && (idx < N))
                        s = s + hcoef(k) * $unsigned(row_in[(lane*N+idx)*PIXEL_WIDTH +: PIXEL_WIDTH]);
                end
                calc_row[(lane*N+c)*OUT_WIDTH +: OUT_WIDTH] = s;
            end
        end
    end

    // L-1 pipeline stages.  Throughput remains one complete row-batch/clock.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            row_out   <= '0;
            for (i = 0; i < LP; i = i + 1) begin
                pipe_valid[i] <= 1'b0;
                pipe_data[i]  <= '0;
            end
        end else begin
            pipe_valid[0] <= in_valid;
            if (in_valid)
                pipe_data[0] <= calc_row;

            for (i = 1; i < LP; i = i + 1) begin
                pipe_valid[i] <= pipe_valid[i-1];
                pipe_data[i]  <= pipe_data[i-1];
            end

            out_valid <= pipe_valid[LP-1];
            if (pipe_valid[LP-1])
                row_out <= pipe_data[LP-1];
        end
    end
endmodule
