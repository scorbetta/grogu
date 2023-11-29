#---- IMPORTS -------------------------------------------------------------------------------------

# Standard imports
import os
from typing import Union, Any, Type, Optional
import sys

# JINJA imports
import jinja2 as jj
from jinja2 import Environment, FileSystemLoader

# SystemRDL imports
from systemrdl.node import AddressableNode, RootNode, Node
from systemrdl.node import AddrmapNode, MemNode
from systemrdl.node import RegNode, RegfileNode, FieldNode
from systemrdl import RDLListener

# PeakRDL imports
from peakrdl_regblock import *
from peakrdl_regblock.addr_decode import AddressDecode
from peakrdl_regblock.field_logic import FieldLogic
from peakrdl_regblock.dereferencer import Dereferencer
from peakrdl_regblock.readback import Readback
from peakrdl_regblock.identifier_filter import kw_filter as kwf
from peakrdl_regblock.scan_design import DesignScanner
from peakrdl_regblock.validate_design import DesignValidator
from peakrdl_regblock.cpuif import CpuifBase
from peakrdl_regblock.cpuif.apb4 import APB4_Cpuif
from peakrdl_regblock.cpuif.axi4lite import AXI4Lite_Cpuif
from peakrdl_regblock.cpuif.base import CpuifBase
from peakrdl_regblock.hwif import Hwif
from peakrdl_regblock.exporter import DesignState


#---- PRINTING LISTENER CLASS ---------------------------------------------------------------------

class gModelPrintingListener(RDLListener):
    def __init__(self, ofile):
        self.indent = 0
        self.ofile = ofile
        self.fid = open(self.ofile, 'w')
        self.original_stdout = sys.stdout
        sys.stdout = self.fid

    def enter_Component(self, node):
        if not isinstance(node, FieldNode):
            print("\t"*self.indent, node.get_path_segment())
            self.indent += 1

    def enter_Field(self, node):
        # Print some stuff about the field
        bit_range_str = "[%d:%d]" % (node.high, node.low)
        sw_access_str = "sw=%s" % node.get_property('sw').name
        print("\t"*self.indent, bit_range_str, node.get_path_segment(), sw_access_str)

    def exit_Component(self, node):
        if not isinstance(node, FieldNode):
            self.indent -= 1

    def __del__(self):
        sys.stdout = self.original_stdout


#---- AXI4 LITE INTERFACE CLASS -------------------------------------------------------------------

# This class assumes we are using SystemVerilog interfaces
class gAXI4LiteInterface(AXI4Lite_Cpuif):
    """
    Returns AXI4 Lite port declaration
    """
    @property
    def port_declaration(self) -> str:
        return "axi4l_if.slave AXIL"

    """
    Returns signal naming
    """
    def signal(self, name:str) -> str:
        return "AXIL." + name.lower()

    """
    Returns maximum number of outstanding transactions. This is force to be 1,
    due to current AXI4 Lite interface bridge design
    """
    @property
    def max_outstanding(self) -> int:
        # Force one outstanding transaction at a time
        return 1


#---- RTL EXPORTERS -------------------------------------------------------------------------------

# PeakRDL class for RTL block design
class gRTLExporter(RegblockExporter):
    """
    Class constructor

    Parameters
    ----------
    tfolder: str
        Folder containing template files
    """
    def __init__(self, tfolder: str):
        # Fill from parent
        super().__init__()

        # Additional fills
        self.tfolder = tfolder
        self.jj_env = jj.Environment(loader=jj.FileSystemLoader(self.tfolder))

    """
    Export method

    Parameters
    ----------
    node: AddrmapNode
        Top-level SystemRDL node to export
    output_dir: str
        Path to the output directory where generated SystemVerilog will be written.
        Output includes two files: a module definition and package definition.
    cpuif_cls: :class:`peakrdl_regblock.cpuif.CpuifBase`
        Specify the class type that implements the CPU interface of your choice.
        Defaults to AMBA APB4.
    module_name: str
        Override the SystemVerilog module name. By default, the module name
        is the top-level node's name.
    package_name: str
        Override the SystemVerilog package name. By default, the package name
        is the top-level node's name with a "_pkg" suffix.
    reuse_hwif_typedefs: bool
        By default, the exporter will attempt to re-use hwif struct definitions for
        nodes that are equivalent. This allows for better modularity and type reuse.
        Struct type names are derived using the SystemRDL component's type
        name and declared lexical scope path.

        If this is not desireable, override this parameter to ``False`` and structs
        will be generated more naively using their hierarchical paths.
    retime_read_fanin: bool
        Set this to ``True`` to enable additional read path retiming.
        For large register blocks that operate at demanding clock rates, this
        may be necessary in order to manage large readback fan-in.

        The retiming flop stage is automatically placed in the most optimal point in the
        readback path so that logic-levels and fanin are minimized.

        Enabling this option will increase read transfer latency by 1 clock cycle.
    retime_read_response: bool
        Set this to ``True`` to enable an additional retiming flop stage between
        the readback mux and the CPU interface response logic.
        This option may be beneficial for some CPU interfaces that implement the
        response logic fully combinationally. Enabling this stage can better
        isolate timing paths in the register file from the rest of your system.

        Enabling this when using CPU interfaces that already implement the
        response path sequentially may not result in any meaningful timing improvement.

        Enabling this option will increase read transfer latency by 1 clock cycle.
    address_width: int
        Override the CPU interface's address width. By default, address width
        is sized to the contents of the regblock.
    """
    def export(self, node: RootNode, odir: str, **kwargs: any) -> None:
        # Sanity checks 
        if not isinstance(node, RootNode):
            raise TypeError(f'Unexpected type of node argument: {type(node).__name__} (expected: RootNode)')

        # Initialize required variables. Taken from the  peakrd_regblock/exporter.py  class
        self.ds = DesignState(node.top, kwargs)

        # Overwrite custom ones
        cpuif_cls = kwargs.pop("cpuif_cls", None) or AXI4Lite_Cpuif # type: Type[CpuifBase]
        module_template = kwargs.pop("module_template", None) # type: str
        package_template = kwargs.pop("package_template", None) # type: str
        target_language = kwargs.pop("target_language", None) # type: str

        # Construct exporter components
        self.cpuif = cpuif_cls(self)
        self.hwif = Hwif(self, None)

        # Validate that there are no unsupported constructs
        validator = DesignValidator(self)
        validator.do_validate()

        # Reuse list of registers in multipe places
        all_regs = list(node.top.registers())

        # Build Jinja template context
        context = {
            "regs" : all_regs,
            "module_name": self.ds.module_name,
            "cpuif": self.cpuif,
            "hwif": self.hwif,
            "field_logic": self.field_logic,
            "readback": self.readback,
            "package_name" : self.ds.package_name,
            # Take register width from first register since most of the cases all registers have the
            # same width...
            "data_width": all_regs[0].size * 8,
            # By default, let the synthesized trim what's not necessary
            "addr_width": 32
        }

        # Package is created only when SystemVerilog is required
        if target_language == "SystemVerilog":
            extension = "sv"
            context['template_file'] = package_template
            package_file_path = os.path.join(odir, self.ds.package_name + "." + extension)
            template = self.jj_env.get_template(package_template)
            stream = template.stream(context)
            stream.dump(package_file_path)
        else:
            extension = "v"

        context['template_file'] = module_template
        module_file_path = os.path.join(odir, self.ds.module_name + "." + extension)
        template = self.jj_env.get_template(module_template)
        stream = template.stream(context)
        stream.dump(module_file_path)

# Utility to export RTL defines
def gRTLHeaderExporter(root, ofolder, basename, tfolder, template, target_language):
    jinja_env = Environment(loader=FileSystemLoader(tfolder))
    jinja_env.add_extension('jinja2.ext.loopcontrols')
    template = jinja_env.get_template(template)

    # Save list of registers, so that can re-iterate over them multiple times
    all_regs = list(root.top.registers())
    context = {
        "regs": all_regs,
        "module_name": basename.upper(),
        "template_file": template.name
    }

    extension = ""
    if target_language == "SystemVerilog":
        extension = "svh"
    else:
        extension = "vh"

    ofile_name = f'{ofolder}/{basename.upper()}.{extension}'
    jinja_render = template.render(context)
    with open(ofile_name, mode="w", encoding="utf-8") as fid:
        fid.write(jinja_render)


#---- SOFTWARE EXPORTERS --------------------------------------------------------------------------

# Utility to export Software defines
def gSoftwareHeaderExporter(root, ofolder, basename, tfolder, offset_template, defines_template, prefix):
    # Create JINJA template environment
    jinja_env = Environment(loader=FileSystemLoader(tfolder))
    jinja_env.add_extension('jinja2.ext.loopcontrols')

    # JINJA render 1: Registers definitions
    template = jinja_env.get_template(defines_template)
    all_regs = list(root.top.registers())
    context = {
        "regs": all_regs,
        "prefix": prefix,
        "template_file": defines_template
    }
    ofile_name = f'{ofolder}/{basename}_reg_defines.h'
    jinja_render = template.render(context)
    with open(ofile_name, mode="w", encoding="utf-8") as fid:
        fid.write(jinja_render)

    # JINJA render 2: Registers offsets
    template = jinja_env.get_template(offset_template)
    context = {
        "regs": all_regs,
        "prefix": prefix,
        "template_file": offset_template
    }
    ofile_name = f'{ofolder}/{basename}_reg_offsets.h'
    jinja_render = template.render(context)
    with open(ofile_name, mode="w", encoding="utf-8") as fid:
        fid.write(jinja_render)
