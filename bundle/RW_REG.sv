`timescale 1ns/100ps

// A simple register with an accessible Write signal. The  WEN  signal can be connected to an
// external bridge, so that Software can overwrite this register via AXI bus
module RW_REG #(
    // Data width
    parameter DATA_WIDTH    = 32,
    // Does it have reset signal?
    parameter HAS_RESET     = 1
)
(
    input                   CLK,
    input                   RSTN,
    input                   WEN,
    input [DATA_WIDTH-1:0]  VALUE_IN,
    output [DATA_WIDTH-1:0] VALUE_OUT
);

    logic [DATA_WIDTH-1:0]  reg_value;
    logic                   reg_rstn;

    // Filter input reset when  HAS_RESET  is cleared
    generate
        if(HAS_RESET == 1) begin
            assign reg_rstn = RSTN;
        end
        else begin
            assign reg_rstn = 1'b1;
        end
    endgenerate

    always_ff @(posedge CLK) begin
        if(!reg_rstn) begin
            reg_value <= {DATA_WIDTH{1'b0}};
        end
        else if(WEN) begin
            reg_value <= VALUE_IN;
        end
    end

    // Pinout
    assign VALUE_OUT = reg_value;
endmodule
