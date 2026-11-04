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

# The extension's own makefile installs a pkgIndex.tcl that loads the
# libtclparser1.8.a archive by file name.  That is wrong for a statically linked
# package (and the archive is not shipped), so remove it and let KitCreator write
# the right one: "load {} parser".
function postinstall() {
	rm -f "${installdir}"/lib/*/pkgIndex.tcl
	return 0
}
