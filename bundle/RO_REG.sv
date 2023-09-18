`timescale 1ns/100ps

// A Read-only register doesn't have accessible Write signal. It just mirrors input value driven by
// the Hardware logic. Software can only read this value through the bridge that samples  VALUE_OUT  
module RO_REG #(
    parameter DATA_WIDTH    = 32,
    parameter HAS_RESET     = 1
)
(
    input                   CLK,
    input                   RSTN,
    input [DATA_WIDTH-1:0]  VALUE_IN,
    output [DATA_WIDTH-1:0] VALUE_OUT
);

    RW_REG #(
        .DATA_WIDTH (DATA_WIDTH),
        .HAS_RESET  (HAS_RESET)
    )
    REG (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .WEN        (1'b1),
        .VALUE_IN   (VALUE_IN),
        .VALUE_OUT  (VALUE_OUT)
    );
endmodule
