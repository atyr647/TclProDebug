#! /usr/bin/env bash

# BuildCompatible: KitCreator
#
# Builds the "parser" Tcl extension (lib/tclparser) so that it can be linked
# statically into the kit.  The sources are not downloaded: build-starpack.sh
# copies lib/tclparser into ./buildsrc, which KitCreator's common build system
# then uses in place of a downloaded tarball.

version='1.8'
tclpkg='parser'
tclpkgversion='1.8'
# The init function is Tclparser_Init (not Parser_Init, which is what
# KitCreator would otherwise guess from the package name).
tclpkg_initfunc='Tclparser_Init'
