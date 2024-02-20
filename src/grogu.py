#!/usr/bin/env python3

# Standard includes
import sys
import os
import shutil
import argparse
import configparser
from pathlib import Path

# SystemRDL imports
from systemrdl import RDLCompiler, RDLCompileError, RDLWalker
from systemrdl.node import FieldNode

# PeakRDL imports
from peakrdl_regblock.udps import ALL_UDPS
from peakrdl_html import HTMLExporter

# grogu imports
from gExporters import *

def main(rdl_file, target_language, tfolder, module_template, package_template, rtl_offset_template, sw_offset_template, sw_defines_template, prefix, byte_addresses):
    # Create RDL compiler
    rdlc = RDLCompiler()
    
    # Register all UPDs
    for udp in ALL_UDPS:
        rdlc.register_udp(udp)
    
    try:
        # Compile input description
        rdlc.compile_file(rdl_file)
        root = rdlc.elaborate()
    except RDLCompileError:
        sys.exit(1)

    # Append a  _  to the  prefix  if not empty
    if prefix != "":
        prefix = prefix + "_"

    # Setup exporter
    module_name = root.top.inst_name.upper()
    ofolder = f"grogu.gen/{module_name}"
    sw_package_name = module_name.lower()
    rtl_package_name = module_name.lower() + "_pkg"

    # If folder already exists, create a copy but delete the previous copy
    ofolder_copy = f'{ofolder}.copy'
    shutil.rmtree(ofolder_copy, ignore_errors=True)
    if os.path.exists(ofolder):
        print(f'warn: Renaming previous run \"{ofolder}\" to \"{ofolder_copy}\" folder')
        shutil.move(ofolder, ofolder_copy)
    os.makedirs(f'{ofolder}', exist_ok=True)
    print(f'info: Generated files will be written to \"{ofolder}\" folder')

    # Generate output products 1: Export RTL
    os.mkdir(f'{ofolder}/rtl')
    groguXrtl = gRTLExporter(tfolder)
    groguXrtl.export(root, f'{ofolder}/rtl', cpuif_cls=gAXI4LiteInterface, module_template=module_template, package_template=package_template, module_name=module_name, package_name=rtl_package_name, target_language=target_language, prefix=prefix, byte_addresses=byte_addresses)

    # Generate output products 2: Export SystemVerilog headers
    gRTLHeaderExporter(root, f'{ofolder}/rtl', module_name, tfolder, rtl_offset_template, target_language, prefix, byte_addresses)

    # Generate output products 3: Export Software files
    os.mkdir(f'{ofolder}/sw')
    gSoftwareHeaderExporter(root, f'{ofolder}/sw', sw_package_name, tfolder, sw_offset_template, sw_defines_template, prefix)

    # Generate output products 4: Export HTML
    os.mkdir(f'{ofolder}/html')
    groguXhtml = HTMLExporter()
    groguXhtml.export(root, f'{ofolder}/html')

    # Generate output products 5: Export CSR tree
    walker = RDLWalker(unroll=True)
    listener = gModelPrintingListener(f'{ofolder}/csr.tree')
    walker.walk(root, listener)      

if __name__ == "__main__":
    # Create command line parser and parse command line arguments
    cmd_parser = argparse.ArgumentParser(prog=sys.argv[0], description='grogu is a complete Configuration and Status Register block generation tool')
    cmd_parser.add_argument('-r', '--rdl', type=str, required=True, help='input RDL specification')
    cmd_parser.add_argument('-i', '--ini', type=str, required=False, help='input configuration file (default: grogu.ini)', default="grogu.ini")
    cmd_parser.add_argument('-p', '--prefix', type=str, required=False, help='naming prefix (default: input RDL basename)', default="")
    args = cmd_parser.parse_args()

    # Create INI parser and parse configuration file
    ini_parser = configparser.ConfigParser()
    ini_parser.read(args.ini)

    #@DBUG# Debug output
    #@DBUGprint(f"dbug: grogu run configuration")
    #@DBUGprint(f"dbug:   RDL file: {args.rdl}")
    #@DBUGprint(f"dbug:   Names prefix: {ini_parser['design']['prefix']}")
    #@DBUGprint(f"dbug:   Templates folder: {ini_parser['templates']['tfolder']}")
    #@DBUGprint(f"dbug:   Package template file: {ini_parser['templates']['package_template']}")
    #@DBUGprint(f"dbug:   Module template file: {ini_parser['templates']['module_template']}")
    #@DBUGprint(f"dbug:   RTL offset template file: {ini_parser['templates']['rtl_offset_template']}")
    #@DBUGprint(f"dbug:   Software offset template file: {ini_parser['templates']['sw_offset_template']}")

    # Let's do it!
    main(
        args.rdl,
        ini_parser['design']['language'],
        ini_parser['templates']['tfolder'],
        ini_parser['templates']['module_template'],
        ini_parser['templates']['package_template'],
        ini_parser['templates']['rtl_offset_template'],
        ini_parser['templates']['sw_offset_template'],
        ini_parser['templates']['sw_defines_template'],
        args.prefix,
        ini_parser['templates']['byte_addresses']
    )
