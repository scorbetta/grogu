`timescale 1ns/100ps

// A Delta register is a Read-only register that generates an output signal once its value changes.
// Once read, its state is reset
module DELTA_REG #(
    parameter DATA_WIDTH    = 32,
    parameter HAS_RESET     = 1
)
(
    input                   CLK,
    input                   RSTN,
    input                   READ_EVENT,
    input [DATA_WIDTH-1:0]  VALUE_IN,
    output                  VALUE_CHANGE,
    output [DATA_WIDTH-1:0] VALUE_OUT
);

    logic [DATA_WIDTH-1:0]  value_diff;
    logic                   delta_event;
    logic                   value_change;
    logic [DATA_WIDTH-1:0]  reg_value;

    // Read-only register
    RO_REG #(
        .DATA_WIDTH (DATA_WIDTH),
        .HAS_RESET  (HAS_RESET)
    )
    REG (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_IN   (VALUE_IN),
        .VALUE_OUT  (reg_value)
    );

    // Compute value difference efficiently
    assign value_diff   = VALUE_IN ^ reg_value;
    assign delta_event  = |value_diff;

    // Latch the delta event until next  READ_EVENT  is seen
    always_ff @(posedge CLK) begin
        if(!RSTN) begin
            value_change <= 1'b0;
        end
        else if(!value_change && delta_event) begin
            value_change <= 1'b1;
        end
        else if(value_change && READ_EVENT) begin
            value_change <= 1'b0;
        end
    end

    // Pinout
    assign VALUE_CHANGE = value_change;
    assign VALUE_OUT    = reg_value;
endmodule
