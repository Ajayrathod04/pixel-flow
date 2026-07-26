// ============================================================================
// Module: image_filter_top
// Description: Top-Level Low-Latency 2D Image Filtering Accelerator
// Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
// Authors: Joe Gould, Ryan K. Nelson, Keshab K. Parhi (IEEE TCSI 2025)
// ============================================================================

`timescale 1ns / 1ps

module image_filter_top #(
    parameter M            = 16, // Image Height (Rows)
    parameter N            = 16, // Image Width (Columns)
    parameter K            = 3,  // Filter Height
    parameter L            = 3,  // Filter Width
    parameter PIXEL_WIDTH  = 8,  // Input pixel width
    parameter WEIGHT_WIDTH = 8,  // Filter weight width
    parameter RCONV_WIDTH  = 24, // Intermediate partial sum width
    parameter OUT_WIDTH    = 32  // Final 2D output pixel width
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               start,
    input  wire                               row_valid_in,
    input  wire [N*PIXEL_WIDTH-1:0]           row_in,
    input  wire [L*WEIGHT_WIDTH-1:0]          row_weights, // L weights for RConv
    input  wire [K*WEIGHT_WIDTH-1:0]          col_weights, // K weights for CConv
    output wire                               row_valid_out,
    output wire [N*OUT_WIDTH-1:0]             row_out
);

    localparam HALF_K = (K - 1) / 2;

    // Row Counter for managing frame boundaries and generating zero-padding enables
    reg [$clog2(M+K):0] row_cnt;
    reg                 processing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_cnt    <= 0;
            processing <= 1'b0;
        end else begin
            if (start) begin
                row_cnt    <= 0;
                processing <= 1'b1;
            end else if (row_valid_in && processing) begin
                if (row_cnt == M - 1) begin
                    row_cnt    <= 0;
                    processing <= 1'b0;
                end else begin
                    row_cnt    <= row_cnt + 1;
                end
            end
        end
    end

    // Boundary enable logic e(k) for CConv stages to handle vertical zero padding
    // For stage k, input row row_cnt contributes to output row (row_cnt - k + HALF_K)
    reg [K-1:0] cconv_en;
    integer tap;
    always @(*) begin
        for (tap = 0; tap < K; tap = tap + 1) begin
            if (($signed({1'b0, row_cnt}) - tap + HALF_K >= 0) &&
                ($signed({1'b0, row_cnt}) - tap + HALF_K < M)) begin
                cconv_en[tap] = 1'b1;
            end else begin
                cconv_en[tap] = 1'b0;
            end
        end
    end

    // Pipeline enable signals by 1 cycle to align with RConv 1-cycle latency
    reg [K-1:0] cconv_en_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cconv_en_r <= {K{1'b0}};
        end else begin
            cconv_en_r <= cconv_en;
        end
    end

    // Inter-module signals between RConv and CConv
    wire                     rconv_valid_out;
    wire [N*RCONV_WIDTH-1:0] rconv_data_out;

    // RConv Array Instance (Direct-Form 1D Row Convolution)
    rconv_array #(
        .N(N),
        .L(L),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .OUT_WIDTH(RCONV_WIDTH)
    ) u_rconv (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(row_valid_in),
        .row_in(row_in),
        .weights_in(row_weights),
        .out_valid(rconv_valid_out),
        .row_out(rconv_data_out)
    );

    // CConv Array Instance (Transpose-Form 1D Column Convolution with Line Delays)
    cconv_array #(
        .N(N),
        .K(K),
        .IN_WIDTH(RCONV_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_cconv (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(rconv_valid_out),
        .row_in(rconv_data_out),
        .weights_in(col_weights),
        .cconv_en(cconv_en_r),
        .out_valid(row_valid_out),
        .row_out(row_out)
    );

endmodule
