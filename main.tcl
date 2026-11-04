#!/usr/bin/env tclsh

# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.

# This is the only way to know definitively if a package is available without
# putting "package require" in a catch statement.  Catch statement is bad
# because it hides the errors you don't anticipate as well as the ones you do:
if {"starkit" ni [package names]} {
	eval [package unknown] starkit
}

# Now "package names" holds the definitive answer as to whether the desired
# package is available:
if {"starkit" in [package names]} {
	package require starkit

	# unset existing state vars in case this is a nested starkit and 
	# startup has been done before:
	unset -nocomplain ::starkit::mode ::starkit::topdir

	::starkit::startup

	# Starkits predate Tcl modules.  Starkit boot doesn't anticipate that
	# module paths may lie outside starkit dir, thus losing true
	# encapsulation.
	# In case this is a starpack, strip out module paths outside the vfs,
	# thus ensuring only modules loaded are those within the vfs:
	set tpaths [::tcl::tm::path list]
	if {$::starkit::mode ne {starpack}} {
		set tpaths {}
	}
	foreach tpath $tpaths {
		if {[string first $::starkit::topdir/ $tpath/]} {
			::tcl::tm::path remove $tpath
		}
	}

} else {
	# Should be possible to run an unwrapped starkit even without starkit
	# package.  If missing, do the things ::starkit::startup would do:
	namespace eval ::starkit {
		set topscript [
			file dirname [
				file norm [
					file join [info script] x
				]
			]
		]
		variable topdir [file dirname $topscript]
		variable mode sourced
		if {$topscript eq [
			file dirname [
				file norm [
					file join $::argv0 x
				]
			]
		]} {
			variable mode unwrapped
		}
	}

	if {
		[lsearch -exact $::auto_path $::starkit::topdir/lib] < 0 &&
		[file isdir $::starkit::topdir/lib]
	} {
		lappend ::auto_path $::starkit::topdir/lib
	}
}

unset -nocomplain tpath tpaths topscript

# If this is the first starkit started, save state variables in global space
# so that any nested starkit can access them:
if {![info exists topdir]} {
	set topdir $::starkit::topdir
	set mode $::starkit::mode
}

# Add module path within package lib path:
::tcl::tm::path add [file dirname $::starkit::topdir]//[file tail $::starkit::topdir]/lib/tm

# Interpreter mode: with TCLPRO_RUN_STDIN set, run the script named on the
# command line, or else the one that arrives on standard input (like "tclsh"),
# instead of starting the debugger GUI.
# This lets the Tcl/Tk built into a packaged executable serve as the interpreter
# for the program being debugged, for people who have no Tcl installed.  The
# debugger sets this itself when asked to use the executable as the interpreter
# (see src/selftest.tcl), and it is harmless for every other interpreter.
if {[info exists ::env(TCLPRO_RUN_STDIN)]} {
	unset ::env(TCLPRO_RUN_STDIN)
	if {[llength $::argv] > 0} {
		# "interpreter script ?arg ...?", which is how the debugger starts
		# the application on Windows.
		set argv0 [lindex $::argv 0]
		set argv [lrange $::argv 1 end]
		set argc [llength $argv]
		set code [catch {uplevel #0 [list source $argv0]} result opts]
	} else {
		set code [catch {uplevel #0 [read stdin]} result opts]
	}
	if {$code} {
		puts stderr [dict get $opts -errorinfo]
		exit 1
	}
	exit 0
}

# Used by the build to verify a packaged executable (see src/selftest.tcl):
if {[lindex $::argv 0] eq "--selftest"} {
	source $::starkit::topdir/src/selftest.tcl
}

source $::starkit::topdir/src/startup.tcl

