#-----------------------------------------------------------------------------
# Project : KeyV
# File    : kVsim.tcl
# Authors : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-03-13 Fri>
# Brief   : Package containing procedures to be used with Modelsim
#-----------------------------------------------------------------------------
package provide kVsim 1.0
package require Tcl 8.5
package require kVutils

namespace eval ::kVsim {

    namespace export *
}

#-----------------------------------------------------------------------------
# READ_MEMDUMP
#
#    Parse a memory file <mem> that contains a memory dump from Modelsim (mti)
#    Print formated memory info
#-----------------------------------------------------------------------------
proc ::kVsim::read_memdump { mem } {

    set memdump   ""
    set mem_data  [::kVutils::file_read $mem]
    set mem_lines [split [::kVutils::strip_comments ${mem_data} "//"] \n]

    # Table properties
    set c 10
    set s [string repeat - $c]

    # Print Table header
    append memdump [format "+-%*s-+-%*s-+-%*s-+-%*s-+\n" $c $s $c $s $c $s $c $s]
    append memdump [format "| %*s | %*s | %*s | %*s |\n" $c "ADDRESS" $c "HEX" $c "DEC" $c "ASCII"]
    append memdump [format "+-%*s-+-%*s-+-%*s-+-%*s-+\n" $c $s $c $s $c $s $c $s]

    # Print Memory table
    set nz 0
    foreach line $mem_lines {

        # Split Address and Data
        set addr [format %03X 0x[string trim [lindex [split $line ":"] 0]]]
        set hex  [string trim [lindex [split $line ":"] end]]

        # Stop after 5 zeros
        if { $nz > 4 } { break }
        if { [string match "00000000" $hex] } { incr nz }

        # Convert to Decimal
        set dec [format %u 0x$hex]

        # Convert to ASCII
        set ascii ""
        for { set i 0 } { $i < 4 } { incr i } {
            set char [format %c 0x[string range $hex [expr 2 * $i] [expr 2 * $i + 1]]]
            if { [string is print $char] } {
                append ascii $char
            }
        }
        # Reverse ASCII string
        set asciiR ""
        for { set i 0 } { $i < [string length $ascii] } { incr i } {
            append asciiR [string index $ascii [expr [string length $ascii]-$i-1]]
        }

        # Format values in Tables
        append memdump [format "| %*s | %*s | %*s | %*s |\n" $c $addr $c $hex $c $dec $c $asciiR]
    }
    append memdump [format "+-%*s-+-%*s-+-%*s-+-%*s-+\n" $c $s $c $s $c $s $c $s]
    return $memdump
}
