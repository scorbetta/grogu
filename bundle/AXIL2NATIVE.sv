`timescale 1ns/100ps

// A simple AXI4 Lite to Native interface bridge.
module AXIL2NATIVE #(
    // Data width
    parameter DATA_WIDTH    = 32,
    // Address width
    parameter ADDR_WIDTH    = 32
)
(
    // AXI4 Lite interface
    input                       AXI_ACLK,
    input                       AXI_ARESETN,
    input [ADDR_WIDTH-1:0]      AXI_AWADDR,
    input [2:0]                 AXI_AWPROT,
    input                       AXI_AWVALID,
    output                      AXI_AWREADY,
    input [DATA_WIDTH-1:0]      AXI_WDATA,
    input [(DATA_WIDTH/8)-1:0]  AXI_WSTRB,
    input                       AXI_WVALID,
    output                      AXI_WREADY,
    output [1:0]                AXI_BRESP,
    output                      AXI_BVALID,
    input                       AXI_BREADY,
    input [ADDR_WIDTH-1:0]      AXI_ARADDR,
    input [2:0]                 AXI_ARPROT,
    input                       AXI_ARVALID,
    output                      AXI_ARREADY,
    output [DATA_WIDTH-1:0]     AXI_RDATA,
    output [1:0]                AXI_RRESP,
    output                      AXI_RVALID,
    input                       AXI_RREADY,
    // Native interface
    output                      WEN,
    output [ADDR_WIDTH-1:0]     WADDR,
    output [DATA_WIDTH-1:0]     WDATA,
    output                      WACK,
    output                      REN,
    output [ADDR_WIDTH-1:0]     RADDR,
    input [DATA_WIDTH-1:0]      RDATA,
    input                       RVALID
);

    // Internal connections
    typedef enum { READ, WRITE_RESP, WRITE, IDLE } state_t;
    state_t                 curr_state;
    logic                   axi_awready;
    logic                   axi_wready;
    logic [1:0]             axi_bresp;
    logic                   axi_bvalid;
    logic                   axi_arready;
    logic [DATA_WIDTH-1:0]  axi_rdata;
    logic [1:0]             axi_rresp;
    logic                   axi_rvalid;
    logic                   wen;
    logic [ADDR_WIDTH-1:0]  waddr;
    logic [DATA_WIDTH-1:0]  wdata;
    logic                   wack;
    logic                   ren;
    logic [ADDR_WIDTH-1:0]  raddr;

    // A single FSM simplifies design and verification
    always_ff @(posedge AXI_ACLK) begin
        if(AXI_ARESETN == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready <= 1'b0;
            wen <= 1'b0;
            wack <= 1'b0;
            axi_bvalid <= 1'b0;
            axi_arready <= 1'b0;
            axi_rvalid <= 1'b0;
            ren <= 1'b0;
            curr_state <= IDLE;
        end
        else begin
            axi_awready <= 1'b0;
            axi_wready <= 1'b0;
            wen <= 1'b0;
            wack <= 1'b0;
            axi_arready <= 1'b0;
            ren <= 1'b0;

            case(curr_state)
                IDLE : begin
                    if(AXI_AWVALID == 1'b1) begin
                        axi_awready <= 1'b1;
                        curr_state <= WRITE;
                    end
                    else if(AXI_ARVALID == 1'b1) begin
                        axi_arready <= 1'b1;
                        ren <= 1'b1;
                        raddr <= AXI_ARADDR;
                        curr_state <= READ;
                    end
                end

                WRITE : begin
                    if(AXI_WVALID == 1'b1 && axi_wready == 1'b0) begin
                        wen <= 1'b1;
                        wdata <= AXI_WDATA;
                        waddr <= AXI_AWADDR;
                        axi_wready <= 1'b1;
                    end
                    else if(AXI_WVALID == 1'b1 && axi_wready == 1'b1) begin
                        axi_bvalid <= 1'b1;
                        axi_bresp <= 2'b00;
                        curr_state <= WRITE_RESP;
                    end
                    else begin
                        axi_wready <= 1'b1;
                    end
                end

                WRITE_RESP : begin
                    if(axi_bvalid == 1'b1 && AXI_BREADY == 1'b1) begin
                        axi_bvalid <= 1'b0;
                        wack <= 1'b1;
                        curr_state <= IDLE;
                    end
                end

                READ : begin
                    if(RVALID == 1'b1 && axi_rvalid == 1'b0) begin
                        axi_rvalid <= 1'b1;
                        axi_rdata <= RDATA;
                        axi_rresp <= 2'b00;
                    end
                    else if(axi_rvalid == 1'b1 && AXI_RREADY == 1'b1) begin
                        axi_rvalid <= 1'b0;
                        curr_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Pinout assignments
    assign AXI_AWREADY  = axi_awready;
    assign AXI_WREADY   = axi_wready;
    assign AXI_BRESP    = axi_bresp;
    assign AXI_BVALID   = axi_bvalid;
    assign AXI_ARREADY  = axi_arready;
    assign AXI_RDATA    = axi_rdata;
    assign AXI_RRESP    = axi_rresp;
    assign AXI_RVALID   = axi_rvalid;
    assign WEN          = wen;
    assign WADDR        = waddr;
    assign WDATA        = wdata;
    assign WACK         = wack;
    assign REN          = ren;
    assign RADDR        = raddr;
endmodule
