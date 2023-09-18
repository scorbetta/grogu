from typing import TYPE_CHECKING

from peakrdl.plugins.exporter import ExporterSubcommandPlugin

from .GROGUExporter import *

if TYPE_CHECKING:
    import argparse
    from systemrdl.node import AddrmapNode

class Exporter(ExporterSubcommandPlugin):
    short_desc = "Export the register model to grogu and dooku systems"

    def add_exporter_arguments(self, arg_group: 'argparse.ArgumentParser') -> None:
        pass

    def do_export(self, top_node: 'AddrmapNode', options: 'argparse.Namespace') -> None:
        exporter = GROGUExporter()
        exporter.export(top_node, 'test_export_output.sv')
        pass

