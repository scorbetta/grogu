{%- set ns = namespace(temp1 = "") -%}
{%- set ns = namespace(temp2 = "") -%}
// Generated by  grogu  starting from JINJA templated  {{template_file}}  file

`default_nettype none

`include "{{module_name}}.vh"

// Verilog does support neither interfaces nor typedef'd data. This version flattens all
module {{module_name}} (
    // Clock
    input wire ACLK,
    // Active-low synchronous reset
    input wire ARESETN,
    // AXI interface
    input wire [{{addr_width-1}}:0] AWADDR,
    input wire [2:0] AWPROT,
    input wire AWVALID,
    output wire AWREADY,
    input wire [{{data_width-1}}:0] WDATA,
    input wire [{{(data_width/8-1)|round|int}}:0] WSTRB,
    input wire WVALID,
    output wire WREADY,
    output wire [1:0] BRESP,
    output wire BVALID,
    input wire BREADY,
    input wire [{{addr_width-1}}:0] ARADDR,
    input wire [2:0] ARPROT,
    input wire ARVALID,
    output wire ARREADY,
    output wire [{{data_width-1}}:0] RDATA,
    output wire [1:0] RRESP,
    output wire RVALID,
    input wire RREADY,
    // Register bundles
{%- for reg in regs %}
    {%- if reg.is_array %}
    {%- set ns.temp1 = reg.inst_name %}
    {%- set ns.temp2 = reg.array_dimensions[0] ~ "*" ~ data_width ~ "-1" %}
    {%- else %}
    {%- set ns.temp1 = reg.inst_name %}
    {%- set ns.temp2 = data_width-1 %}
    {%- endif %}
    {%- if reg.has_sw_writable %}
    output wire [{{ns.temp2}}:0] HWIF_OUT_{{ns.temp1}}{%- if not loop.last %},{%- endif -%}
    {%- else %}
    input wire [{{ns.temp2}}:0] HWIF_IN_{{ns.temp1}}{%- if not loop.last %},{%- endif -%}
    {%- endif %}
{%- endfor %}
);

    wire regpool_ren;
    wire [{{addr_width-1}}:0] regpool_raddr;
    reg [{{data_width-1}}:0] regpool_rdata;
    reg regpool_rvalid;
    wire regpool_wen;
    reg regpool_wen_resampled;
    wire regpool_wack;
    wire [{{addr_width-1}}:0] regpool_waddr;
    wire [{{data_width-1}}:0] regpool_wdata;

    // AXI4 Lite to Native bridge
    AXIL2NATIVE #(
        .DATA_WIDTH ({{data_width}}),
        .ADDR_WIDTH ({{addr_width}})
    )
    AXIL2NATIVE_0 (
        .AXI_ACLK       (ACLK),
        .AXI_ARESETN    (ARESETN),
        .AXI_AWADDR     (AWADDR),
        .AXI_AWPROT     (AWPROT),
        .AXI_AWVALID    (AWVALID),
        .AXI_AWREADY    (AWREADY),
        .AXI_WDATA      (WDATA),
        .AXI_WSTRB      (WSTRB),
        .AXI_WVALID     (WVALID),
        .AXI_WREADY     (WREADY),
        .AXI_BRESP      (BRESP),
        .AXI_BVALID     (BVALID),
        .AXI_BREADY     (BREADY),
        .AXI_ARADDR     (ARADDR),
        .AXI_ARPROT     (ARPROT),
        .AXI_ARVALID    (ARVALID),
        .AXI_ARREADY    (ARREADY),
        .AXI_RDATA      (RDATA),
        .AXI_RRESP      (RRESP),
        .AXI_RVALID     (RVALID),
        .AXI_RREADY     (RREADY),
        .WEN            (regpool_wen),
        .WADDR          (regpool_waddr),
        .WDATA          (regpool_wdata),
        .WACK           (regpool_wack),
        .REN            (regpool_ren),
        .RADDR          (regpool_raddr),
        .RDATA          (regpool_rdata),
        .RVALID         (regpool_rvalid)
    );

    // Instantiate registers and declare their own signals. From a Software perspective, i.e. access
    // via the AXI4 Lite interface, Configuration registers are Write-only while Status and Delta
    // registers are Read-only
{% for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.is_array %}
        {%- set ns.temp1 = reg_inst.inst_name ~ "_" ~ reg_inst.current_idx[0] %}
        {%- else %}
        {%- set ns.temp1 = reg_inst.inst_name %}
        {%- endif %}

        {%- if reg_inst.has_sw_writable %}
    // {{ns.temp1}}: {{reg_inst.get_property("desc")}}
    reg {{ns.temp1.lower()}}_wreq;
    wire {{ns.temp1.lower()}}_wreq_filtered;
    wire [{{reg_inst.size * 8 - 1}}:0] {{ns.temp1.lower()}}_value_out;
    RW_REG #(
        .DATA_WIDTH ({{reg_inst.size * 8}}),
        .HAS_RESET  ({{reg_inst.get_property('resetreg')}})
    )
    {{ns.temp1}}_REG (
        .CLK        (ACLK),
        .RSTN       (ARESETN),
        .WEN        ({{ns.temp1.lower()}}_wreq_filtered),
        .VALUE_IN   (regpool_wdata),
        .VALUE_OUT  ({{ns.temp1.lower()}}_value_out)
    );
        {% elif reg_inst.is_interrupt_reg %}
    // {{ns.temp1}}: {{reg_inst.get_property("desc")}}
    wire [{{reg_inst.size * 8 - 1}}:0] {{ns.temp1.lower()}}_value_in;
    wire [{{reg_inst.size * 8 - 1}}:0] {{ns.temp1.lower()}}_value_out;
    wire {{ns.temp1.lower()}}_value_change;
    wire {{ns.temp1.lower()}}_read_event;
    DELTA_REG #(
        .DATA_WIDTH ({{reg_inst.size * 8}}),
        .HAS_RESET  ({{reg_inst.get_property('resetreg')}})
    )
    {{ns.temp1}}_REG (
        .CLK            (ACLK),
        .RSTN           (ARESETN),
        .READ_EVENT     ({{ns.temp1.lower()}}_read_event),
        .VALUE_IN       ({{ns.temp1.lower()}}_value_in),
        .VALUE_CHANGE   ({{ns.temp1.lower()}}_value_change),
        .VALUE_OUT      ({{ns.temp1.lower()}}_value_out)
    );
        {% if reg.is_array %}
    assign {{ns.temp1.lower()}}_read_event = regpool_rvalid & (regpool_raddr == `{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET);
        {%- else %}
    assign {{ns.temp1.lower()}}_read_event = regpool_rvalid & (regpool_raddr == `{{reg_inst.inst_name}}_OFFSET);
        {%- endif %}
    {% else %}
    // {{ns.temp1}}: {{reg_inst.get_property("desc")}}
    wire [{{reg_inst.size * 8 - 1 }}:0] {{ns.temp1.lower()}}_value_in;
    wire [{{reg_inst.size * 8 - 1 }}:0] {{ns.temp1.lower()}}_value_out;
    RO_REG #(
        .DATA_WIDTH ({{reg_inst.size * 8}}),
        .HAS_RESET  ({{reg_inst.get_property('resetreg')}})
    )
    {{ns.temp1}}_REG (
        .CLK        (ACLK),
        .RSTN       (ARESETN),
        .VALUE_IN   ({{ns.temp1.lower()}}_value_in),
        .VALUE_OUT  ({{ns.temp1.lower()}}_value_out)
    );
        {% endif %}
    {%- endfor %}
{%- endfor %}
    // Write decoder
    always @(posedge ACLK) begin
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg_inst.has_sw_writable %}
            {%- if reg.is_array %}
        {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_wreq <= 1'b0;
            {%- else %}
        {{reg_inst.inst_name.lower()}}_wreq <= 1'b0;
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}

        case(regpool_waddr)
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg_inst.has_sw_writable %}
            {%- if reg.is_array %}
            `{{prefix}}{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET : begin {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_wreq <= 1'b1; end
            {%- else %}
            `{{prefix}}{{reg_inst.inst_name}}_OFFSET : begin {{reg_inst.inst_name.lower()}}_wreq <= 1'b1; end
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}
        endcase
    end

    // Align Write enable to resampled decoder
    always @(posedge ACLK) begin
        regpool_wen_resampled <= regpool_wen;
    end

    // Ack as soon as possible
    assign regpool_wack = regpool_wen_resampled;

    // Filter Write enables
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg_inst.has_sw_writable %}
            {%- if reg.is_array %}
    assign {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_wreq_filtered = {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_wreq & regpool_wen_resampled;
            {%- else %}
    assign {{reg_inst.inst_name.lower()}}_wreq_filtered = {{reg_inst.inst_name.lower()}}_wreq & regpool_wen_resampled;
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}

    // Create Read strobe from Read request edge
    always @(posedge ACLK) begin
        regpool_rvalid <= regpool_ren;
    end

    // Read decoder
    always @(posedge ACLK) begin
        case(regpool_raddr)
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.has_sw_readable %}
            {%- if reg.is_array %}
            `{{prefix}}{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET : begin regpool_rdata <= {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_value_out; end
            {%- else %}
            `{{prefix}}{{reg_inst.inst_name}}_OFFSET : begin regpool_rdata <= {{reg_inst.inst_name.lower()}}_value_out; end
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}
            default : begin regpool_rdata <= 32'hdeadbeef; end
        endcase
    end

    // Compose and decompose CSR bundle data. Control registers (those written by the Software and
    // read by the Hardware) are put over the  HWIF_OUT_*  ports; Status registers (those written by
    // the Hardware and read by the Software) are get over the  HWIF_IN_*  ports
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.is_array %}
        {%- set ns.temp1 = reg_inst.inst_name ~ "[" ~ reg_inst.current_idx[0] ~ "*" ~ data_width ~ "+:" ~ data_width ~ "]" %}
        {%- set ns.temp2 = reg_inst.inst_name ~ "_" ~ reg_inst.current_idx[0] %}
        {%- else %}
        {%- set ns.temp1 = reg_inst.inst_name %}
        {%- set ns.temp2 = reg_inst.inst_name %}
        {%- endif %}

        {%- if reg_inst.has_sw_writable %}
    assign HWIF_OUT_{{ns.temp1}} = {{ns.temp2.lower()}}_value_out;
        {%- else %}
    assign {{ns.temp2.lower()}}_value_in = HWIF_IN_{{ns.temp1}};
        {%- endif %}

        {%- if reg_inst.is_interrupt_reg %}
    assign HWIF_OUT_{{ns.temp1}}.intr = {{ns.temp2.lower()}}_value_change;
        {%- endif %}
    {%- endfor %}
{%- endfor %}
endmodule

`default_nettype wire
