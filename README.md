# grogu
`grogu` is (yet another) convenient tool to generate synthesizable register maps starting from an
RDL description file.

It simplifies the adoption of the RDL formalism in a digital design flow. It revolves around the
`SystemRDL` compiler and `PeakRDL` command line tool.

`grogu` is designed with simplicity in mind.  For this reason, it does not in any way use all the
features of `PeakRDL`, nor all the specs from `SystemRDL`. It is not meant as a replacement of
`PeakRDL`. It is just a simplified use-case. Y'all be warned!

With `grogu` you will:
- Generate synthesizable SystemVerilog code of a register map;
- Generate HTML-based documentation;
- Generate C header files for Software development.

## Assumptions
The release version of `grogu` works well in the following cases. Any deviation from these
assumptions must be explicitely supported; this is in charge of the user.

- Target language is SytemVerilog;
- The register map interface is AXI4 Lite with 32-bit data and 32-bit addresses;
- The interface supports one single access at a time, either Write or Read;
- There are 3 (three) types of registers: Read/Write registers can be written and read by the
  Software, Read-only register can only be read by the Software and Delta registers are Read-only
registers with an additional level interrupt line.

## Bundle
`grogu` comes bundled with pre-verified design support files:

- A simple AXI4 Lite to Native Interface bridge (`bundle/AXIL2NATIVE.sv`) that allows to convert
  AXI4 Lite Write and Read accesses to Native Interface signals;
- An AXI4 Lite SystemVerilog interface definition with Write and Read tasks ready to use for
  simulation (`bundle/AXI4.sv`);
- A set of synthesizable registers (`bundle/*_REG.sv`);
- A full example with testbench (`example/*`);
- A set of JINJA templates that can be modified at ease or used as is (`templates/*`).

# Example
The `example/` folder contains an example of a register map consisting of the following 32-bit
registers:

|NAME|TYPE|CONTENTS|
|-|-|-|
|DEBUG_REG_0|Status|Debug register 1/4|
|DEBUG_REG_1|Status|Debug register 2/4|
|DEBUG_REG_2|Status|Debug register 3/4|
|DEBUG_REG_3|Status|Debug register 4/4|
|TIMESTAMP_HIGHER|Status|Absolute timestamp, higher half bits [63:32]|
|TIMESTAMP_LOWER|Status|Absolute timestamp, lower half bits [31:0]|
|FIRMWARE_BUILD|Status|Firmware build SHA, lower 4 Bytes|
|ACCESS_STATISTICS|Status|Access statistics (number of Writes and Reads)|
|CORE_CONFIGURATION|Control|Core-level configuration|
|DELTA_TEST|Delta|Interrupt test|

The RDL description is spread into three files:

- `example/common.rdl` contains RTL macros for the definition of the three types of supported
  registers;
- `example/regs.rdl` contains the definition of multi-field registers. Single-field registers are
  always treated as general-purpose, i.e. an instance of `*REG_GP`;
- `example/regpool.rdl` contains the definition of the register pool, i.e. the collection of
  register instances.

`grogu` makes use of a configuration file called `grogu.ini`, whose items are:

|NAME|CONTENTS|
|-|-|
|`prefix`|A prefix name can be prepended to the output names (module, instances, etc...)|
|`tfolder`|The relative path where the templates are stored|
|`package_template`|The template file for the SystemVerilog package|
|`module_template`|The template file for the SystemVerilog module (i.e., top-level register pool)|
|`rtl_offset_template`|The template file for the SystemVerilog header containing offsets|
|`sw_offset_template`|The template file for the C header containing offsets|
|`sw_defines_template`|The template file for the C header containing structured data|

## How-to
Proceed with the following steps to test the example provided.

Create a virtual environment with Python, and activate it:

```
$> python3 -m venv venv
$> source venv/bin/activate
```

Surf to the cloned repository and install Python dependencies:

```
$> cd grogu
$> pip install -r requirements.txt
```

Surf to the `example/` folder. If you have Xilinx Vivado installed, just launch the tool. If you
have other SystemVerilog compilers/simulators modify the `sourceme` script accordingly. And if you
don't want any simulation at all just comment the script past line 12. Then launch the tool:

```
$> source sourceme
```

Generated files will be stored beneath `grogu.gen/`. Output consists of:

|FILE|CONTENTS|
|-|-|
|`REGPOOL/csr.tree`|A tree representation of the register in the register map|
|`REGPOOL/html/index.html`|Entry point of the HTML documentation|
|`REGPOOL/rtl/regpool_pkg.sv`|The SystemVerilog structured definition of the registers|
|`REGPOOL/rtl/REGPOOL.sv`|The register pool top-level module|
|`REGPOOL/rtl/REGPOOL.svh`|Register offsets macros|
|`REGPOOL/sw/regpool_reg_defines.h`|C structured definition of the registers|
|`REGPOOL/sw/regpool_reg_offsets.h`|C macros of the register offsets|

The structured definitions in the SystemVerilog and C headers allow the user to access register
fields using the dot notation, withtout any need to compute the position of the field within a
register! For instance, the following SystemVerilog and C snippets are compiler-valid:

```verilog
    // Import package
    `import regpool_pkg::*;

    // Declare register configuration bundle
    regpool_pkg::regpool__out_t config_bundle;

    // Access configuration values from user code
    always_ff @(posedge ACLK) begin
        if(config_bundle.CORE_CONFIGURATION.write_access_count_en.value) begin
            // ...
        end
    end
```

```c
    // Include offsets
    #include "regpool_reg_offsets.h"

    // Declare register
    CORE_CONFIGURATION_reg_t core_config_regvalue;

    // Read in current value
    core_config_regvalue.value = *((uint32_t *)CORE_CONFIGURATION_OFFSET);

    // Enable Write access count only
    core_config_regvalue.fields.write_access_count_en = 1;
    *((uint32_t *)CORE_CONFIGURATION_OFFSET) = core_config_regvalue.value;
```
