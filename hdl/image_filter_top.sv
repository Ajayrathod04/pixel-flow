`timescale 1ns/1ps

// PixelFlow paper-aligned separable 2-D convolution top level.
//
// X -> RConv (direct-form FIR) -> Z -> CConv (transpose-form FIR) -> Y
//
// Parameters:
//   M/N               image dimensions are handled by the testbench
//   K                 vertical filter length
//   L                 horizontal filter length
//   ROWS_PER_CYCLE    number of complete image rows accepted per clock
//
// Default project configuration:
//   M=N=32, K=L=3, ROWS_PER_CYCLE=2
//
// For K=L=3 the architecture-level latency is described as K+L-1=5 cycles
// in the paper's latency convention. The testbench reports the measured
// first-valid-row timing separately.

module image_filter_top #(
    parameter integer N = 32,
    parameter integer PIXEL_WIDTH = 8,
    parameter integer RCONV_WIDTH = 20,
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
    parameter integer V10 = 0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic row_valid_in,

    input  logic [ROWS_PER_CYCLE*N*PIXEL_WIDTH-1:0] row_in,

    output logic [ROWS_PER_CYCLE-1:0] rconv_valid,
    output logic [ROWS_PER_CYCLE-1:0] row_valid_out,

    output logic [ROWS_PER_CYCLE*N*PIXEL_WIDTH-1:0] row_out
);

    // ------------------------------------------------------------
    // Row convolution stage
    // ------------------------------------------------------------

    logic signed [ROWS_PER_CYCLE*N*RCONV_WIDTH-1:0] rconv_row;
    logic rconv_valid_scalar;

    row_convolver #(
        .N(N),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .OUT_WIDTH(RCONV_WIDTH),
        .L(L),
        .ROWS_PER_CYCLE(ROWS_PER_CYCLE),

        .H0(H0),
        .H1(H1),
        .H2(H2),
        .H3(H3),
        .H4(H4),
        .H5(H5),
        .H6(H6),
        .H7(H7),
        .H8(H8),
        .H9(H9),
        .H10(H10)
    ) u_rconv (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(row_valid_in),
        .row_in(row_in),
        .out_valid(rconv_valid_scalar),
        .row_out(rconv_row)
    );

    // RConv produces one valid bit for the complete row batch.
    assign rconv_valid = {
        ROWS_PER_CYCLE{rconv_valid_scalar}
    };


    // ------------------------------------------------------------
    // Column convolution stage
    // ------------------------------------------------------------

    logic [ROWS_PER_CYCLE-1:0] cconv_valid;

    logic [ROWS_PER_CYCLE*N*PIXEL_WIDTH-1:0] cconv_row;

    column_convolver #(
        .N(N),
        .IN_WIDTH(RCONV_WIDTH),
        .OUT_WIDTH(PIXEL_WIDTH),
        .K(K),
        .ROWS_PER_CYCLE(ROWS_PER_CYCLE),
        .NORMALIZE_SHIFT(NORMALIZE_SHIFT),

        .V0(V0),
        .V1(V1),
        .V2(V2),
        .V3(V3),
        .V4(V4),
        .V5(V5),
        .V6(V6),
        .V7(V7),
        .V8(V8),
        .V9(V9),
        .V10(V10)
    ) u_cconv (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(rconv_valid_scalar),
        .row_in(rconv_row),
        .out_valid(cconv_valid),
        .row_out(cconv_row)
    );


    // ------------------------------------------------------------
    // Explicit output delay
    //
    // For K=L=3:
    //   architecture latency convention = K+L-1 = 5 cycles
    // ------------------------------------------------------------

    localparam integer KP = (K > 1) ? (K - 1) : 1;

    logic [ROWS_PER_CYCLE-1:0] delay_valid [0:KP-1];

    logic [ROWS_PER_CYCLE*N*PIXEL_WIDTH-1:0]
        delay_data [0:KP-1];

    integer di;


    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            row_valid_out <= '0;
            row_out       <= '0;

            for (di = 0; di < KP; di = di + 1) begin
                delay_valid[di] <= '0;
                delay_data[di]  <= '0;
            end

        end
        else begin

            // First output-delay stage
            delay_valid[0] <= cconv_valid;

            if (|cconv_valid)
                delay_data[0] <= cconv_row;


            // Remaining delay stages
            for (di = 1; di < KP; di = di + 1) begin
                delay_valid[di] <= delay_valid[di-1];
                delay_data[di]  <= delay_data[di-1];
            end


            // Final output
            row_valid_out <= delay_valid[KP-1];

            if (|delay_valid[KP-1])
                row_out <= delay_data[KP-1];

        end

    end

endmodule