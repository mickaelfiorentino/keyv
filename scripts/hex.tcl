#!/bin/tclsh
#-----------------------------------------------------------------------------
# Project : Key-V
# File    : hex.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : grm@polymtl
# Date    : <2020-02-26 Wed>
# Brief   : Converts Verilog memory hex format to VHDL memory hex format
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh
# [tcsh]% ./scripts/hex.tcl <ver>.hex <vhd>.hex
#-----------------------------------------------------------------------------
package require Tcl 8.5

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------
if { ![info exist ::env(KEYV_HOME)] } {
    error "ERROR: Setup the environment with setup.csh prior to running this script"
}

global auto_path

if { [lsearch ${auto_path} $::env(KEYV_SCRIPTS)] < 0 } {
    lappend auto_path $::env(KEYV_SCRIPTS)
}
package require kVutils

#-----------------------------------------------------------------------------
# GET ARGUMENTS
#-----------------------------------------------------------------------------
if { $argc != 2 } {
    error "Wrong number of arguments ($argc) - should be 2."
}
set ver_hex_file [lindex $argv 0]
set vhd_hex_file [lindex $argv 1]

#-----------------------------------------------------------------------------
# PARSE INPUT & CONVERT
#-----------------------------------------------------------------------------
::kVutils::file_init ${vhd_hex_file}

set ver_lines [split [::kVutils::file_read ${ver_hex_file}] \n]
foreach line $ver_lines {

    # Address
    if { [string range $line 0 0] == "@" } {
        set addr "0x[string range $line 1 end]"
        set effaddr [format %08X [expr $addr >> 2]]
        ::kVutils::file_write ${vhd_hex_file} "@$effaddr"

    # Data
    } else {
        set data  [split [string trim $line] " "]
        for { set i 1 } { $i <= [expr [llength $data] / 4] } { incr i } {
            set w [lrange $data [expr 4*($i-1)] [expr 4*$i-1]]
            set word [format "%s%s%s%s" [lindex $w 3] [lindex $w 2] [lindex $w 1] [lindex $w 0]]
            ::kVutils::file_write ${vhd_hex_file} $word
        }
    }
}
