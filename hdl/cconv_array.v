// ============================================================================
// Module: cconv_array
// Description: Transpose-Form 1D Column Convolution Systolic Array with Line Delays
// Paper: "A Low-Latency Feed-Forward Architecture for Image Filtering via Row-by-Row Processing"
// Authors: Joe Gould, Ryan K. Nelson, Keshab K. Parhi (IEEE TCSI 2025)
// ============================================================================

`timescale 1ns / 1ps

module cconv_array #(
    parameter N            = 16, // Image Width
    parameter K            = 3,  // Filter Height (odd integer, e.g. 3, 5, 11)
    parameter IN_WIDTH     = 24, // RConv partial sum input bit width
    parameter WEIGHT_WIDTH = 8,  // Filter weight bit width
    parameter OUT_WIDTH    = 32  // Final 2D output bit width
)(
    input  wire                               clk,
    input  wire                               rst_n,
    input  wire                               in_valid,
    input  wire [N*IN_WIDTH-1:0]              row_in,
    input  wire [K*WEIGHT_WIDTH-1:0]          weights_in, // K column weights
    input  wire [K-1:0]                       cconv_en,   // Dynamic zero-padding boundary enables
    output reg                                out_valid,
    output reg  [N*OUT_WIDTH-1:0]             row_out
);

    localparam HALF_K = (K - 1) / 2;

    // Unpack input row
    wire signed [IN_WIDTH-1:0] z_in [0:N-1];
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : UNPACK_Z
            assign z_in[i] = row_in[i*IN_WIDTH +: IN_WIDTH];
        end
    endgenerate

    // Unpack column weights u(0)..u(K-1) in reverse order for transpose-form FIR
    wire signed [WEIGHT_WIDTH-1:0] u [0:K-1];
    generate
        for (i = 0; i < K; i = i + 1) begin : UNPACK_U
            assign u[i] = weights_in[(K - 1 - i)*WEIGHT_WIDTH +: WEIGHT_WIDTH];
        end
    endgenerate

    // Stage partial sum line delays: D_stage[0..K-2][0..N-1]
    reg signed [OUT_WIDTH-1:0] delay_regs [0:K-2][0:N-1];
    reg [K:0] valid_pipe;

    // Transpose-form FIR Multiplication per stage
    integer stage, col;
    reg signed [OUT_WIDTH-1:0] stage_prod [0:K-1][0:N-1];

    always @(*) begin
        for (stage = 0; stage < K; stage = stage + 1) begin
            for (col = 0; col < N; col = col + 1) begin
                if (cconv_en[stage]) begin
                    stage_prod[stage][col] = $signed(z_in[col]) * $signed(u[stage]);
                end else begin
                    stage_prod[stage][col] = {OUT_WIDTH{1'b0}};
                end
            end
        end
    end

    // Sequential update of stage line delays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 0;
            for (stage = 0; stage < K-1; stage = stage + 1) begin
                for (col = 0; col < N; col = col + 1) begin
                    delay_regs[stage][col] <= {OUT_WIDTH{1'b0}};
                end
            end
            row_out   <= {(N*OUT_WIDTH){1'b0}};
            out_valid <= 1'b0;
        end else begin
            valid_pipe <= {valid_pipe[K-1:0], in_valid};
            out_valid  <= valid_pipe[HALF_K - 1];

            // Stage 0 to Stage 1 delay line
            for (col = 0; col < N; col = col + 1) begin
                delay_regs[0][col] <= stage_prod[0][col];
            end

            // Intermediate Stage Line Delays (Transpose Form Adders)
            for (stage = 1; stage < K-1; stage = stage + 1) begin
                for (col = 0; col < N; col = col + 1) begin
                    delay_regs[stage][col] <= delay_regs[stage-1][col] + stage_prod[stage][col];
                end
            end

            // Output Row Register
            for (col = 0; col < N; col = col + 1) begin
                if (K == 1) begin
                    row_out[col*OUT_WIDTH +: OUT_WIDTH] <= stage_prod[0][col];
                end else begin
                    row_out[col*OUT_WIDTH +: OUT_WIDTH] <= delay_regs[K-2][col] + stage_prod[K-1][col];
                end
            end
        end
    end

endmodule
