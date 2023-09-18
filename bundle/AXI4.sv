// AXI4 Lite interface
interface axi4l_if
#(
    parameter DATA_WIDTH    = 32,
    parameter ADDR_WIDTH    = 32
)
(
    input   aclk,
    input   aresetn
);

    logic [ADDR_WIDTH-1:0]      awaddr;
    logic [2:0]                 awprot;
    logic                       awvalid;
    logic                       awready;
    logic [DATA_WIDTH-1:0]      wdata;
    logic [(DATA_WIDTH/8)-1:0]  wstrb;
    logic                       wvalid;
    logic                       wready;
    logic [1:0]                 bresp;
    logic                       bvalid;
    logic                       bready;
    logic [ADDR_WIDTH-1:0]      araddr;
    logic [2:0]                 arprot;
    logic                       arvalid;
    logic                       arready;
    logic [DATA_WIDTH-1:0]      rdata;
    logic [1:0]                 rresp;
    logic                       rvalid;
    logic                       rready;

    modport master (
        input   aclk,
        input   aresetn,
        output  awaddr,
        output  awprot,
        output  awvalid,
        input   awready,
        output  wdata,
        output  wstrb,
        output  wvalid,
        input   wready,
        input   bresp,
        input   bvalid,
        output  bready,
        output  araddr,
        output  arprot,
        output  arvalid,
        input   arready,
        input   rdata,
        input   rresp,
        input   rvalid,
        output  rready
    );

    modport slave (
        input   aclk,
        input   aresetn,
        input   awaddr,
        input   awprot,
        input   awvalid,
        output  awready,
        input   wdata,
        input   wstrb,
        input   wvalid,
        output  wready,
        output  bresp,
        output  bvalid,
        input   bready,
        input   araddr,
        input   arprot,
        input   arvalid,
        output  arready,
        output  rdata,
        output  rresp,
        output  rvalid,
        input   rready
    );

    modport monitor (
        input  aclk,
        input  aresetn,
        input  awaddr,
        input  awprot,
        input  awvalid,
        input  awready,
        input  wdata,
        input  wstrb,
        input  wvalid,
        input  wready,
        input  bresp,
        input  bvalid,
        input  bready,
        input  araddr,
        input  arprot,
        input  arvalid,
        input  arready,
        input  rdata,
        input  rresp,
        input  rvalid,
        input  rready
    );

    // Zero out all control signals
    task set_idle();
        @(posedge aclk);
        awvalid <= 1'b0;
        wvalid <= 1'b0;
        bready <= 1'b0;
        arvalid <= 1'b0;
        rready <= 1'b0;
    endtask

    // Write access
    task write_data(
        input logic [ADDR_WIDTH-1:0]    write_addr,
        input logic [DATA_WIDTH-1:0]    write_data []
    );

        // Write address and Write data channels proceed in parallel
        fork
            begin
                awvalid <= 1'b1;
                awaddr <= write_addr;

                // Wait for address to be sampled
                forever begin
                    @(posedge aclk);
                    if(awvalid && awready) break;
                end

                awvalid <= 1'b0;
            end

            begin
                wvalid <= 1'b1;
                wdata <= write_data[0];
                wstrb <= {DATA_WIDTH/8{1'b1}};

                // Wait for data to be sampled
                forever begin
                    @(posedge aclk);
                    if(wvalid && wready) break;
                end

                wvalid <= 1'b0;
            end

            begin
                forever begin
                    @(posedge aclk);
                    if(bvalid && !bready) bready <= 1'b1;
                    else if(bvalid && bready) break;
                end
            end

            bready <= 1'b0;
        join

        // Shim delay
        @(posedge aclk);
    endtask

    // Read access
    task read_data(
        input logic [ADDR_WIDTH-1:0]    read_addr,
        output logic [DATA_WIDTH-1:0]   read_data []
    );

        // Read address and Read data channels proceed in parallel
        fork
            begin
                arvalid <= 1'b1;
                araddr <= read_addr;

                // Wait for address to be sampled
                forever begin
                    @(posedge aclk);
                    if(arvalid && arready) break;
                end

                arvalid <= 1'b0;
            end

            begin
                rready <= 1'b1;

                // Wait for data to be sampled
                forever begin
                    @(posedge aclk);
                    if(rvalid && rready) break;
                end

                read_data = new [1](read_data);
                read_data[0] = rdata;

                rready <= 1'b0;
            end
        join

        // Shim delay
        @(posedge aclk);
    endtask
endinterface
