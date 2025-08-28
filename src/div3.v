`ifndef DIV3_ROM_H
`define DIV3_ROM_H

`timescale 1ns / 1ps

// Division-by-3

module div3 (
    input  wire [6:0] in, // dividend
    output wire [5:0] out // quotient (in / 3)
);

    wire [12:0] shift6 = {in, 6'd0};
    wire [12:0] shift4 = {2'd0, in, 4'd0};
    wire [ 8:0] shift2 = {in, 2'b0};
	wire [13:0] sum1 = shift6 + shift4;
	wire [ 9:0] sum2 = shift2 + {2'd0, in};
	wire [10:0] sum3 = sum2 + 10'd85;
    wire [14:0] sum = sum1 + {3'd0, sum3};


    assign out = sum[13:8];

endmodule

`endif
