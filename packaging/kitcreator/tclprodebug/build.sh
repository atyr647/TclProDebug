#! /usr/bin/env bash

# BuildCompatible: KitCreator
#
# "Builds" the debugger application itself.  There is nothing to compile: the
# files that make up the application are copied into ./buildsrc by
# build-starpack.sh (driven by starkit.manifest) and are installed at the root
# of the kit's virtual file system, which makes main.tcl the program that the
# kit runs at startup.

version='1'

function configure() { return 0; }
function build() { return 0; }
function install() { return 0; }

function createruntime() {
	cp -R "${buildsrcdir}"/. "${runtimedir}"/ || return 1
	test -f "${runtimedir}/main.tcl" || return 1
	return 0
}
