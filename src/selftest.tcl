# selftest.tcl --
#
#	Verifies that a packaged (or source) copy of the debugger works.  Used by
#	the starpack build to check each binary on the platform it was built for;
#	it can also be run by hand:
#
#	    TclProDebug --selftest report.txt ?debuggee-interpreter?
#
#	The result is written to report.txt (a GUI program on Windows has no
#	console, so nothing is printed) and the process exits with status 0 only
#	if every check passed.  If a debuggee interpreter (e.g. tclsh or wish) is
#	given, a short script is also run under the debugger engine in that
#	interpreter, which exercises the nub, the instrumenter and the parser end
#	to end.
#
# Copyright (c) 2017 Forward Folio LLC
# See the file "license.terms" for information on usage and redistribution of this file.

namespace eval selftest {
    variable report {}
    variable failed 0
    variable out [lindex $::argv 1]
    variable debuggee [lindex $::argv 2]
    # "self" means: debug with this program's own built-in Tcl/Tk.
    if {$debuggee eq "self"} {
	set debuggee [info nameofexecutable]
    }
}

proc selftest::log {msg} {
    variable report
    append report $msg\n
}

proc selftest::check {name script} {
    variable failed
    if {[catch {uplevel #0 $script} result]} {
	incr failed
	log "FAIL  $name: $result"
    } else {
	log "ok    $name: $result"
    }
}

proc selftest::finish {} {
    variable report
    variable failed
    variable out
    log [expr {$failed ? "RESULT: FAILED ($failed)" : "RESULT: PASSED"}]
    if {$out ne ""} {
	set f [open $out w]
	puts -nonewline $f $report
	close $f
    }
    catch {puts -nonewline stderr $report}
    exit [expr {$failed ? 1 : 0}]
}

# Run a debuggee under the real debugger engine and make sure it attaches,
# runs to completion and reports back.

proc selftest::debugSession {interp} {
    variable e2eEvent
    variable e2eOut

    set dir [file normalize [file join [pwd] selftest-[pid]]]
    file mkdir $dir
    set e2eOut [file join $dir result.txt]
    set script [file join $dir debuggee.tcl]
    set f [open $script w]
    puts $f {
	proc square {x} { set y [expr {$x * $x}]; return $y }
	trace add variable ::v write {apply {{args} {}}}
	set ::v [square 7]
	set tk [expr {![catch {package require Tk}]}]
	set f [open $::env(SELFTEST_OUT) w]
	puts $f "v=$::v tk=$tk tcl=[info patchlevel]"
	close $f
	if {$tk} { catch {destroy .} }
	exit 0
    }
    close $f
    set ::env(SELFTEST_OUT) $e2eOut

    proc ::selftest::ev {e args} {
	set ::selftest::e2eEvent $e
    }
    system::init
    dbg::initialize $::debugger::libdir
    foreach e {attach linebreak error exit} {
	dbg::register $e [list ::selftest::ev $e]
    }
    dbg::setServerPort random
    # TCLPRO_RUN_STDIN makes this program's own executable behave like tclsh
    # (see main.tcl); real interpreters ignore it.
    dbg::start $interp $dir $script {} selftest {TCLPRO_RUN_STDIN 1}

    set timer [after 30000 {set ::selftest::e2eEvent timeout}]
    set events {}
    while 1 {
	vwait ::selftest::e2eEvent
	lappend events $::selftest::e2eEvent
	switch -- $::selftest::e2eEvent {
	    attach - linebreak { after 20 dbg::run }
	    error { error "debuggee reported an error" }
	    timeout { error "timed out; events: $events" }
	    exit { break }
	}
    }
    after cancel $timer
    if {![file exists $e2eOut]} {
	error "debuggee did not run to completion; events: $events"
    }
    set f [open $e2eOut]
    set result [string trim [read $f]]
    close $f
    catch {file delete -force $dir}
    if {![string match "v=49 *" $result]} {
	error "unexpected debuggee result: $result"
    }
    return $result
}

selftest::log "executable : [info nameofexecutable]"
selftest::log "platform   : $::tcl_platform(os) $::tcl_platform(osVersion) $::tcl_platform(machine)"
selftest::log "tcl        : [info patchlevel]"
selftest::log "topdir     : $::starkit::topdir"

selftest::check "Tk" {
    package require Tk
    toplevel .selftest
    update
    destroy .selftest
    package present Tk
}

selftest::check "parser" {
    package require parser
    set r [parse command {set a [expr {1 + 2}]} {0 end}]
    if {[llength [lindex $r 3]] != 3} { error "unexpected parse result: $r" }
    package present parser
}

selftest::check "debugger package" {
    package require debugger
    set ::projectInfo::patchLevel
}

if {$selftest::debuggee ne ""} {
    selftest::check "debug session in $selftest::debuggee" {
	selftest::debugSession $selftest::debuggee
    }
}

selftest::finish
