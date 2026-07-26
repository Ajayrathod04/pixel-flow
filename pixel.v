//================================================
//Authpr : AJAY RATHOD
//PROJECT : Pixelflow 
// Module: pixel
// Low Latency Feed Forward Architecture for Image Filter
// Row FIR (Direct) + Column FIR (Transpose)
//=================================================

module pixel(
    input clk,
    input rst,
    input [7:0] pixel_in,
    output reg [15:0] pixel_out
);

//---------------- ROW FIR (Direct Form) ----------------
reg [7:0] r0, r1, r2, r3;
reg [15:0] row_out;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        r0 <= 0; 
        r1 <= 0; 
        r2 <= 0; 
        r3 <= 0;
    end
    else
    begin
        r3 <= r2;
        r2 <= r1;
        r1 <= r0;
        r0 <= pixel_in;
    end
end

// FIR: y = x0 + 2x1 + 2x2 + x3
always @(posedge clk)
begin
    row_out <= r0 + (r1 << 1) + (r2 << 1) + r3;
end

//---------------- COLUMN FIR (Transpose Form) ----------------
reg [15:0] t0, t1, t2, t3;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        t0 <= 0;
        t1 <= 0;
        t2 <= 0;
        t3 <= 0;
    end
    else
    begin
        t0 <= row_out;
        t1 <= t0 + (row_out << 1);
        t2 <= t1 + (row_out << 1);
        t3 <= t2 + row_out;
    end
end

//---------------- OUTPUT ----------------
always @(posedge clk)
begin
    pixel_out <= t3;
end

endmodule
