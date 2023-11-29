`default_nettype none

// A simple AXI4 Lite to Native interface bridge.
module AXIL2NATIVE #(
    // Data width
    parameter DATA_WIDTH    = 32,
    // Address width
    parameter ADDR_WIDTH    = 32
)
(
    // AXI4 Lite interface
    input wire                      AXI_ACLK,
    input wire                      AXI_ARESETN,
    input wire [ADDR_WIDTH-1:0]     AXI_AWADDR,
    input wire [2:0]                AXI_AWPROT,
    input wire                      AXI_AWVALID,
    output wire                     AXI_AWREADY,
    input wire [DATA_WIDTH-1:0]     AXI_WDATA,
    input wire [(DATA_WIDTH/8)-1:0] AXI_WSTRB,
    input wire                      AXI_WVALID,
    output wire                     AXI_WREADY,
    output wire [1:0]               AXI_BRESP,
    output wire                     AXI_BVALID,
    input wire                      AXI_BREADY,
    input wire [ADDR_WIDTH-1:0]     AXI_ARADDR,
    input wire [2:0]                AXI_ARPROT,
    input wire                      AXI_ARVALID,
    output wire                     AXI_ARREADY,
    output wire [DATA_WIDTH-1:0]    AXI_RDATA,
    output wire [1:0]               AXI_RRESP,
    output wire                     AXI_RVALID,
    input wire                      AXI_RREADY,
    // Native interface
    output wire                     WEN,
    output wire [ADDR_WIDTH-1:0]    WADDR,
    output wire [DATA_WIDTH-1:0]    WDATA,
    output wire                     WACK,
    output wire                     REN,
    output wire [ADDR_WIDTH-1:0]    RADDR,
    input wire [DATA_WIDTH-1:0]     RDATA,
    input wire                      RVALID
);

    // clog2
    `include "clog2.vh"

    // States encoding
    localparam READ         = 0;
    localparam WRITE_RESP   = 1;
    localparam WRITE        = 2;
    localparam IDLE         = 3;

    // Internal connections
    reg [clog2(IDLE)-1:0]   curr_state;
    reg                     axi_awready;
    reg                     axi_wready;
    reg                     axi_bvalid;
    reg                     axi_arready;
    reg [DATA_WIDTH-1:0]    axi_rdata;
    reg                     axi_rvalid;
    reg                     wen;
    reg [ADDR_WIDTH-1:0]    waddr;
    reg [DATA_WIDTH-1:0]    wdata;
    reg                     wack;
    reg                     ren;
    reg [ADDR_WIDTH-1:0]    raddr;

    // A single FSM simplifies design and verification
    always @(posedge AXI_ACLK) begin
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
    assign AXI_BRESP    = 2'b00;
    assign AXI_BVALID   = axi_bvalid;
    assign AXI_ARREADY  = axi_arready;
    assign AXI_RDATA    = axi_rdata;
    assign AXI_RRESP    = 2'b00;
    assign AXI_RVALID   = axi_rvalid;
    assign WEN          = wen;
    assign WADDR        = waddr;
    assign WDATA        = wdata;
    assign WACK         = wack;
    assign REN          = ren;
    assign RADDR        = raddr;
endmodule

`default_nettype wire
