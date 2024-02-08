{%- set ns = namespace(temp1 = "") -%}
{%- set ns = namespace(temp2 = "") -%}
// Generated by  grogu  starting from JINJA templated  {{template_file}}  file

`default_nettype none

`include "{{module_name}}.vh"

// Native interface based design for large and distributed register files (used in conjunction with
// the SCI configuration ring)
module {{module_name}} (
    // Clock and reset
    input wire CLK,
    input wire RSTN,
    // Register interface
    input wire WREQ,
    input wire [{{addr_width-1}}:0] WADDR,
    input wire [{{data_width-1}}:0] WDATA,
    output wire WACK,
    input wire RREQ,
    input wire [{{addr_width-1}}:0] RADDR,
    output wire [{{data_width-1}}:0] RDATA,
    output wire RVALID,
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

    reg rvalid;
    reg [{{data_width-1}}:0] rdata;

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
    wire [{{reg_inst.size * 8 - 1}}:0] {{ns.temp1.lower()}}_value_out;
    RW_REG #(
        .DATA_WIDTH ({{reg_inst.size * 8}}),
        .HAS_RESET  ({{reg_inst.get_property('resetreg')}})
    )
    {{ns.temp1}}_REG (
        .CLK        (CLK),
        .RSTN       (RSTN),
        .WEN        ({{ns.temp1.lower()}}_wreq),
        .VALUE_IN   (WDATA),
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
        .CLK            (CLK),
        .RSTN           (RSTN),
        .READ_EVENT     ({{ns.temp1.lower()}}_read_event),
        .VALUE_IN       ({{ns.temp1.lower()}}_value_in),
        .VALUE_CHANGE   ({{ns.temp1.lower()}}_value_change),
        .VALUE_OUT      ({{ns.temp1.lower()}}_value_out)
    );
        {% if reg.is_array %}
    assign {{ns.temp1.lower()}}_read_event = rvalid & (RADDR == `{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET);
        {%- else %}
    assign {{ns.temp1.lower()}}_read_event = rvalid & (RADDR == `{{reg_inst.inst_name}}_OFFSET);
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
        .CLK        (CLK),
        .RSTN       (RSTN),
        .VALUE_IN   ({{ns.temp1.lower()}}_value_in),
        .VALUE_OUT  ({{ns.temp1.lower()}}_value_out)
    );
        {% endif %}
    {%- endfor %}
{%- endfor %}
    // Write decoder
    always @(posedge CLK) begin
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

        if(WREQ) begin
            case(WADDR)
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
    end

    // Create Read strobe from Read request edge
    always @(posedge CLK) begin
        rvalid <= RREQ;
    end

    // Read decoder
    always @(RADDR) begin
        case(RADDR)
{%- for reg in regs %}
    {%- for reg_inst in reg.unrolled() %}
        {%- if reg.has_sw_readable %}
            {%- if reg.is_array %}
            `{{prefix}}{{reg_inst.inst_name}}_{{reg_inst.current_idx[0]}}_OFFSET : begin rdata = {{reg_inst.inst_name.lower()}}_{{reg_inst.current_idx[0]}}_value_out; end
            {%- else %}
            `{{prefix}}{{reg_inst.inst_name}}_OFFSET : begin rdata = {{reg_inst.inst_name.lower()}}_value_out; end
            {%- endif %}
        {%- endif %}
    {%- endfor %}
{%- endfor %}
            default : begin rdata = {%raw%}{{%endraw%}{{data_width}}{1'b1}}; end
        endcase
    end

    // Pinout
    assign RVALID   = rvalid;
    assign RDATA    = rdata;

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
