#!/usr/bin/env python3

from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
src = vu.add_library("lib")

# Add all files ending in .vhd to library
src.add_source_files("src/*.vhd")

# Add testbenches
src.add_source_files("testbench/*.vhd")

# Run vunit function
vu.main()
