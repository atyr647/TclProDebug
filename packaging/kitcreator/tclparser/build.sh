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
# package (and the archive is not shipped), so replace it.
#
# KitCreator registers a static package under the name of its init function
# (Tclparser_Init -> "tclparser"), which is not the name of the package it
# provides ("parser"), so the index has to say so explicitly.
function postinstall() {
	local dir
	for dir in "${installdir}"/lib/tclparser*; do
		[ -d "${dir}" ] || continue
		cat > "${dir}/pkgIndex.tcl" << '_EOF_'
package ifneeded parser 1.8 [list load {} tclparser]
_EOF_
	done
	return 0
}
