{%- set ns = namespace(temp1 = "") -%}
{%- set ns = namespace(temp2 = "") -%}
// Generated by  grogu  starting from JINJA templated  {{template_file}}  file

`timescale 1ns/100ps

`include "{{module_name}}.svh"

module {{module_name}} (
    // Clock and reset
    input ACLK,
    input ARESETN,
    // AXI interface
    axi4l_if.slave AXIL,
    // Register bundles
    {{hwif.port_declaration|indent(4)}}
);

    logic regpool_ren;
    logic [15:0] regpool_raddr;
    logic [31:0] regpool_rdata;
    logic regpool_rvalid;
    logic regpool_wen;
    logic regpool_wen_resampled;
    logic [15:0] regpool_waddr;
    logic [31:0] regpool_wdata;

    // AXI4 Lite to Native bridge
    AXIL2NATIVE #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (16)
    )
    AXIL2NATIVE_0 (
        .AXI_ACLK       (ACLK),
        .AXI_ARESETN    (ARESETN),
        .AXI_AWADDR     (AXIL.awaddr),
        .AXI_AWPROT     (AXIL.awprot),
        .AXI_AWVALID    (AXIL.awvalid),
        .AXI_AWREADY    (AXIL.awready),
        .AXI_WDATA      (AXIL.wdata),
        .AXI_WSTRB      (AXIL.wstrb),
        .AXI_WVALID     (AXIL.wvalid),
        .AXI_WREADY     (AXIL.wready),
        .AXI_BRESP      (AXIL.bresp),
        .AXI_BVALID     (AXIL.bvalid),
        .AXI_BREADY     (AXIL.bready),
        .AXI_ARADDR     (AXIL.araddr),
        .AXI_ARPROT     (AXIL.arprot),
        .AXI_ARVALID    (AXIL.arvalid),
        .AXI_ARREADY    (AXIL.arready),
        .AXI_RDATA      (AXIL.rdata),
        .AXI_RRESP      (AXIL.rresp),
        .AXI_RVALID     (AXIL.rvalid),
        .AXI_RREADY     (AXIL.rready),
        .WEN            (regpool_wen),
        .WADDR          (regpool_waddr),
        .WDATA          (regpool_wdata),
        .WACK           (), // Unused
        .REN            (regpool_ren),
        .RADDR          (regpool_raddr),
        .RDATA          (regpool_rdata),
        .RVALID         (regpool_rvalid)
    );

    // Instantiate registers and declare their own signals. From a Software perspective, i.e. access
    // via the AXI4 Lite interface, Configuration registers are Write-only and Debug registers are
    // Read-only
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.is_array %}
        {%- set ns.temp1 = reg_inst.inst_name ~ "_" ~ reg_inst.current_idx[0] %}
        {%- else %}
        {%- set ns.temp1 = reg_inst.inst_name %}
        {%- endif %}

        {%- if reg_inst.has_sw_writable %}
    // {{ns.temp1}}: {{reg_inst.get_property("desc")}}
    logic {{ns.temp1.lower()}}_wreq;
    logic {{ns.temp1.lower()}}_wreq_filtered;
    logic [31:0] {{ns.temp1.lower()}}_value_out;
    RW_REG #(
        .DATA_WIDTH (32)
    )
    {{ns.temp1}}_REG (
        .CLK    (ACLK),
        .WEN    ({{ns.temp1.lower()}}_wreq_filtered),
        .WDATA  (regpool_wdata),
        .RDATA  ({{ns.temp1.lower()}}_value_out)
    );
        {% else %}
    // {{ns.temp1}}: {{reg_inst.get_property("desc")}}
    logic [31:0] {{ns.temp1.lower()}}_value_in;
    logic [31:0] {{ns.temp1.lower()}}_value_out;
    RO_REG #(
        .DATA_WIDTH (32)
    )
    {{ns.temp1}}_REG (
        .CLK        (ACLK),
        .VALUE_IN   ({{ns.temp1.lower()}}_value_in),
        .VALUE_OUT  ({{ns.temp1.lower()}}_value_out)
    );
        {% endif %}
    {%- endfor %}
{%- endfor %}
    // Write decoder
    always_ff @(posedge ACLK) begin
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
            `{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET : begin {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_wreq <= 1'b1; end
            {%- else %}
            `{{reg_inst.inst_name}}_OFFSET : begin {{reg_inst.inst_name.lower()}}_wreq <= 1'b1; end
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}
        endcase
    end

    // Align Write enable to resampled decoder
    always_ff @(posedge ACLK) begin
        regpool_wen_resampled <= regpool_wen;
    end

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
    always_ff @(posedge ACLK) begin
        regpool_rvalid <= regpool_ren;
    end

    // Read decoder
    always_ff @(posedge ACLK) begin
        case(regpool_raddr)
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.has_sw_readable %}
            {%- if reg.is_array %}
            `{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET : begin regpool_rdata <= {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_value_out; end
            {%- else %}
            `{{reg_inst.inst_name}}_OFFSET : begin regpool_rdata <= {{reg_inst.inst_name.lower()}}_value_out; end
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}
            default : begin regpool_rdata <= 32'hdeadbeef; end
        endcase
    end
 
    // Compose and decompose CSR structured data. Control registers (those written by the Software
    // and read by the Hardware) are put over the  hwif_out  port; Status registers (those written
    // by the Hardware and read by the Software) are get over the  hwif_in  port
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.is_array %}
        {%- set ns.temp1 = reg_inst.inst_name ~ "[" ~ reg_inst.current_idx[0] ~ "]" %}
        {%- set ns.temp2 = reg_inst.inst_name ~ "_" ~ reg_inst.current_idx[0] %}
        {%- else %}
        {%- set ns.temp1 = reg_inst.inst_name %}
        {%- set ns.temp2 = reg_inst.inst_name %}
        {%- endif %}

        {%- if reg_inst.has_sw_writable %}
    assign { {%- for field in reg_inst.fields()|reverse %} hwif_out.{{ns.temp1}}.{{field.inst_name}}.value{%- if not loop.last %},{%- endif -%} {%- endfor %} } = {{ns.temp2.lower()}}_value_out;
        {%- else %}
    assign {{ns.temp2.lower()}}_value_in = { {%- for field in reg_inst.fields()|reverse %} hwif_in.{{ns.temp1}}.{{field.inst_name}}.next{%- if not loop.last %},{%- endif -%} {%- endfor %} };
        {%- endif %}
    {%- endfor %}
{%- endfor %}
endmodule
