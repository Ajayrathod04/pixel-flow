//=================================================
// Testbench: pixel_th
//=================================================

module pixel_th;

reg clk;
reg rst;
reg [7:0] pixel_in;
wire [15:0] pixel_out;

pixel uut (
    .clk(clk),
    .rst(rst),
    .pixel_in(pixel_in),
    .pixel_out(pixel_out)
);

//---------------- CLOCK ----------------
always #5 clk = ~clk;

//---------------- IMAGE DATA ----------------
reg [7:0] image [0:15];
integer i;

initial
begin
    clk = 0;
    rst = 1;

    // 4x4 image
    image[0]=10;  image[1]=20;  image[2]=30;  image[3]=40;
    image[4]=50;  image[5]=60;  image[6]=70;  image[7]=80;
    image[8]=90;  image[9]=100; image[10]=110; image[11]=120;
    image[12]=130; image[13]=140; image[14]=150; image[15]=160;

    #10 rst = 0;

    for(i=0; i<16; i=i+1)
    begin
        pixel_in = image[i];
        #10;
    end

    #100 $finish;
end

//---------------- MONITOR ----------------
initial
begin
    $monitor("Time=%0t | Input=%d | Output=%d", $time, pixel_in, pixel_out);
end

endmodule