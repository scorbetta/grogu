`timescale 1ns/100ps

`include "REGPOOL.svh"

// The Out-of-The-Box-Test-Bench tests grogu generated files for the  REGPOOL  example
module ootbtb;
    // Clock and reset
    logic                       aclk;
    logic                       aresetn;
    logic [31:0]                axi_readout [1];
    logic [31:0]                axi_writein [1];
    logic [63:0]                timestamp;
    // Bundles to/from the pool
    regpool_pkg::regpool__in_t  regpool_bundle_in;
    regpool_pkg::regpool__out_t regpool_bundle_out;

    // AXI interface
    axi4l_if #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32)
    )
    axil (
        .aclk       (aclk),
        .aresetn    (aresetn)
    );

    // DUT
    REGPOOL DUT (
        .ACLK       (aclk),
        .ARESETN    (aresetn),
        .AXIL       (axil),
        .hwif_in    (regpool_bundle_in),
        .hwif_out   (regpool_bundle_out)
    );

    // Clock and reset
    initial begin
        aclk = 1'b0;
        forever begin
            #2.0 aclk = ~aclk;
        end
    end

    initial begin
        aresetn <= 1'b0;
        repeat(10) @(posedge aclk);
        aresetn <= 1'b1;
    end

    // Dump signals to VCD
    initial begin
        $dumpfile("ootbtb.vcd");
        $dumpvars(0, ootbtb);
    end

    // Keep updating status registers
    always_ff @(posedge aclk) begin
        if(!aresetn) begin
            timestamp <= 32'd0;
        end
        else begin
            timestamp <= timestamp + 1;
        end
    end

    assign regpool_bundle_in.TIMESTAMP_HIGHER.data.next = timestamp[63:32];
    assign regpool_bundle_in.TIMESTAMP_LOWER.data.next = timestamp[31:0];

    // Stimuli
    initial begin
        regpool_bundle_in.DELTA_TEST.irq.next <= 1'b0;
        regpool_bundle_in.DELTA_TEST.rsv.next <= 31'd0;
        axil.set_idle();
        @(posedge aresetn);
        repeat(10) @(posedge aclk);

        // Read value from registers declared as array of registers
        for(int rdx = 0; rdx < 4; rdx++) begin
            axil.read_data(`DEBUG_REG_0_OFFSET + (rdx * 4), axi_readout);
            repeat(10) @(posedge aclk);
        end

        // Read value from status register
        axil.read_data(`TIMESTAMP_HIGHER_OFFSET, axi_readout);
        repeat(10) @(posedge aclk);
        axil.read_data(`TIMESTAMP_LOWER_OFFSET, axi_readout);
        repeat(10) @(posedge aclk);
        axil.read_data(`FIRMWARE_BUILD_OFFSET, axi_readout);
        repeat(10) @(posedge aclk);
        axil.read_data(`ACCESS_STATISTICS_OFFSET, axi_readout);
        repeat(10) @(posedge aclk);

        // Overwrite from Hardware once
        regpool_bundle_in.FIRMWARE_BUILD.data.next <= 32'h20230918;
        repeat(10) @(posedge aclk);
        axil.read_data(`FIRMWARE_BUILD_OFFSET, axi_readout);

        // Keep reading from status register
        repeat(10) begin
            repeat(25) @(posedge aclk);
            axil.read_data(`TIMESTAMP_HIGHER_OFFSET, axi_readout);
            axil.read_data(`TIMESTAMP_LOWER_OFFSET, axi_readout);
        end

        // Write new value
        axil.read_data(`CORE_CONFIGURATION_OFFSET, axi_readout);
        repeat(10) @(posedge aclk);
        axi_writein[0] = 32'hdeadbeef;
        axil.write_data(`CORE_CONFIGURATION_OFFSET, axi_writein);
        repeat(10) @(posedge aclk);
        axil.read_data(`CORE_CONFIGURATION_OFFSET, axi_readout);
        repeat(10) @(posedge aclk);

        // Test delta register
        @(posedge aclk);
        regpool_bundle_in.DELTA_TEST.irq.next <= 1'b1;
        repeat(20) @(posedge aclk);
        axil.read_data(`DELTA_TEST_OFFSET, axi_readout);

        repeat(1e2) @(posedge aclk);
        $finish;
    end
endmodule
