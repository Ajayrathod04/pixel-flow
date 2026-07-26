// ============================================================================
// Module: rconv_array
// Description: Direct-Form 1D Row Convolution Systolic Array
// Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
// Authors: Joe Gould, Ryan K. Nelson, Keshab K. Parhi (IEEE TCSI 2025)
// ============================================================================

`timescale 1ns / 1ps

module rconv_array #(
    parameter N            = 16, // Image Width
    parameter L            = 3,  // Filter Width (odd integer, e.g. 3, 5, 11)
    parameter PIXEL_WIDTH  = 8,  // Input pixel bit width
    parameter WEIGHT_WIDTH = 8,  // Filter weight bit width
    parameter OUT_WIDTH    = 24  // Partial sum output bit width
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               in_valid,
    input  wire [N*PIXEL_WIDTH-1:0]           row_in,
    input  wire [L*WEIGHT_WIDTH-1:0]          weights_in, // L weights for separable / row-1D
    output reg                                out_valid,
    output reg  [N*OUT_WIDTH-1:0]             row_out
);

    localparam HALF_L = (L - 1) / 2;
    localparam PAD_N  = N + 2 * HALF_L;

    // Unpack input row elements
    wire signed [PIXEL_WIDTH-1:0] in_pixels [0:N-1];
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : UNPACK_IN
            assign in_pixels[i] = row_in[i*PIXEL_WIDTH +: PIXEL_WIDTH];
        end
    endgenerate

    // Padded input row array (0-padded on left and right)
    wire signed [PIXEL_WIDTH-1:0] padded_pixels [0:PAD_N-1];
    generate
        for (i = 0; i < PAD_N; i = i + 1) begin : PAD_LOGIC
            if (i < HALF_L) begin
                assign padded_pixels[i] = {PIXEL_WIDTH{1'b0}};
            end else if (i >= HALF_L + N) begin
                assign padded_pixels[i] = {PIXEL_WIDTH{1'b0}};
            end else begin
                assign padded_pixels[i] = in_pixels[i - HALF_L];
            end
        end
    endgenerate

    // Unpack filter weights
    wire signed [WEIGHT_WIDTH-1:0] w [0:L-1];
    generate
        for (i = 0; i < L; i = i + 1) begin : UNPACK_WEIGHTS
            assign w[i] = weights_in[i*WEIGHT_WIDTH +: WEIGHT_WIDTH];
        end
    endgenerate

    // Direct-form 1D Horizontal Convolution Computation
    // Computes dot product across horizontal filter window for each output column n in [0..N-1]
    reg signed [OUT_WIDTH-1:0] comb_out [0:N-1];
    integer col, tap;

    always @(*) begin
        for (col = 0; col < N; col = col + 1) begin
            comb_out[col] = {OUT_WIDTH{1'b0}};
            for (tap = 0; tap < L; tap = tap + 1) begin
                comb_out[col] = comb_out[col] + ($signed(padded_pixels[col + tap]) * $signed(w[tap]));
            end
        end
    end

    // Pipeline Output Register (1 clock cycle latency for RConv)
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            row_out   <= {(N*OUT_WIDTH){1'b0}};
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                for (k = 0; k < N; k = k + 1) begin
                    row_out[k*OUT_WIDTH +: OUT_WIDTH] <= comb_out[k];
                end
            end
        end
    end

endmodule
