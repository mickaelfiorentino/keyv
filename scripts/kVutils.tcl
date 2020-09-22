#-----------------------------------------------------------------------------
# File    : kVutils.tcl
# Authors : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-01-30 Thu>
#
#   This package contains generic procedures to be used with TCL-based EDA tools
#   (Mentor, Synopsys, Cadence).
#
#-----------------------------------------------------------------------------
package provide kVutils 1.0
package require Tcl 8.5

#-----------------------------------------------------------------------------
# NAMESPACE
#
#   Global variables & procedures
#-----------------------------------------------------------------------------
namespace eval ::kVutils {

    namespace export *
}

#-----------------------------------------------------------------------------
# LREMOVE
#
#   Remove element <elmt> from list <lvar>
#-----------------------------------------------------------------------------
proc ::kVutils::lremove { lvar elmt } {

    upvar 1 $lvar var
    set idx [lsearch -exact $var $elmt]
    set var [lreplace $var $idx $idx]
}

#-----------------------------------------------------------------------------
# PKG_ADD
#
#   Add <dir> to auto_path global variable (if not already present)
#   Allows to run 'package require <pkg>' if <pkg> is in directory <dir>
#-----------------------------------------------------------------------------
proc ::kVutils::pkg_add { dir } {

    global auto_path

    if { ![info exists auto_path] } {
        error "auto_path global varibale does not exist, check your tcl environment"
    } else {
        if { [lsearch ${auto_path} $dir] < 0 } {
            lappend auto_path $dir
        }
    }
}

#-----------------------------------------------------------------------------
# RM_SPACE
#
#   Removes spaces in string <str>
#-----------------------------------------------------------------------------
proc ::kVutils::rm_space { str } {

    set s ""
    foreach c [split $str " "] {
        append s $c
    }
    return $s
}

#-----------------------------------------------------------------------------
# FORMAT_PATH
#
#   Truncates path name <path> by a specified number of subdirectories [max].
#   Intended to convert full paths to relative paths
#-----------------------------------------------------------------------------
proc ::kVutils::format_path { path {max 1} } {

    return [join [lrange [split $path /] end-$max end] /]
}

#-----------------------------------------------------------------------------
# FORMAT_OUT
#
#   Format a string to be printed on screen. Truncates the string with a limited
#   number of characters. The remaining is replaced by '...'
#   + str : The input string
#   + max : The maximum length of the string (default to 150)
#-----------------------------------------------------------------------------
proc ::kVutils::format_out { str {max 150} } {

    if { [string length $str] > $max } {
        return [format "  > %s" [concat [string range $str 0 $max] "..."]]
    } else {
        return [format "  > %s" $str]
    }
}

#-----------------------------------------------------------------------------
# FORMAT_TITLE
#
#   Format a string <str> to be printed on screen with emphasis (box of <char>)
#-----------------------------------------------------------------------------
proc ::kVutils::format_title { str {char "#"} } {

    set str [string trim $str]
    set sep [string repeat $char [expr [string length $str] + 4]]
    return [format "\n%s\n%s %s %s\n%s\n" $sep $char $str $char $sep]
}

#-----------------------------------------------------------------------------
# GET_TIME
#
#   Returns the time with the format <fmt>
#-----------------------------------------------------------------------------
proc ::kVutils::get_time { {fmt "%D - %H:%M:%S"} } {

    return [clock format [clock seconds] -format $fmt]
}

#-----------------------------------------------------------------------------
# STRIP_COMMENTS
#
#   Remove comments (line starting with [chars]) from string <str>, and
#   strip leading/trailing spaces.
#-----------------------------------------------------------------------------
proc ::kVutils::strip_comments { str {chars "//"} } {

    regsub -all -line "\[$chars\].*$" $str "" stripped
    return [string trim $stripped]
}

#-----------------------------------------------------------------------------
# TO_RE
#
#   Converts <str> string into a regular-expression friendly pattern
#   Replace [ by \[ ; ] by \] ; . by \.
#-----------------------------------------------------------------------------
proc ::kVutils::to_re { str } {

    regsub -all {\[} $str [subst -nocommands -nobackslashes {\[} ] re
    regsub -all {\]} $re  [subst -nocommands -nobackslashes {\]} ] re
    regsub -all {\.} $re  [subst -nocommands -nobackslashes {\.} ] re
    regsub -all {\+} $re  [subst -nocommands -nobackslashes {\+} ] re
    return [string trim $re]
}

#-----------------------------------------------------------------------------
# STACK_CREATE
#
#   Create a stack based on [lstack] list (default is empty)
#-----------------------------------------------------------------------------
proc ::kVutils::stack_create { {lstack ""} } {

    return $lstack
}

#-----------------------------------------------------------------------------
# STACK_PUSH
#
#   Push <val> at the bottom of the stack <stack_name>
#-----------------------------------------------------------------------------
proc ::kVutils::stack_push { stack_name val } {

    upvar 1 $stack_name stack
    lappend stack $val
}

#-----------------------------------------------------------------------------
# STACK_POP
#
#   Pop value on top of stack <stack_name>
#-----------------------------------------------------------------------------
proc ::kVutils::stack_pop { stack_name } {

    upvar 1 $stack_name stack
    set val [lindex $stack 0]
    set stack [lreplace $stack 0 0]
    return $val
}

#-----------------------------------------------------------------------------
# TO_THERMOMETER
#
#   Converts <val> to thermometer code string of size <size>
#-----------------------------------------------------------------------------
proc ::kVutils::to_thermometer { val size } {

    set code [string repeat 0 $size]
    set code [string replace $code $val $size [string repeat 1 [expr $size - $val]]]
    return $code
}

#-----------------------------------------------------------------------------
# FILE_READ
#
#   Open file <fname> channel, read and return its data, close the channel
#-----------------------------------------------------------------------------
proc ::kVutils::file_read { fname } {

    if { ! [file exist $fname] } {
        error "file $fname does not exist"
    }
    set chan [open $fname r]
    set data [read $chan]
    close $chan

    return $data
}

#-----------------------------------------------------------------------------
# FILE_WRITE
#
#   Open file <fname> channel in mode [mode], write string <str> into it,
#   and close the channel
#-----------------------------------------------------------------------------
proc ::kVutils::file_write { fname str {mode "a"} } {

    set chan [open $fname $mode]
    puts $chan $str
    close $chan
}

#-----------------------------------------------------------------------------
# FILE_INIT
#
#   Create file <fname> directory if it does not exist & clear file
#-----------------------------------------------------------------------------
proc ::kVutils::file_init { fname } {

    set file_dir [join [lrange [split $fname /] 0 end-1] /]
    if { ![file exists $file_dir] } {
        file mkdir $file_dir
    }
    close [open $fname "w"]
}

#-----------------------------------------------------------------------------
# GET_SRC
#
#   Parse a prj file that contains VHDL and Verilog files to be compiled
#   Returns a tcl list with the files name
#   + prj  : prj file path name
#   + type : type of the list of files ("vhd", "v", "sv")
#-----------------------------------------------------------------------------
proc ::kVutils::get_src { prj {type "vhd"} } {

    if { !([string match $type "vhd"] || [string match $type "v"] || [string match $type "sv"]) } {
        error "::kVutils::get_src : Wrong type ($type)"
    }

    set data  [::kVutils::file_read $prj]
    set lines [split [::kVutils::strip_comments $data "#"] \n]

    set src ""
    foreach line $lines {
        set sline [string trim $line]
        if { [lindex [split $sline .] 1] == $type } {
            lappend src $sline
        }
    }
    return $src
}

#-----------------------------------------------------------------------------
# GET_PLUSARG
#
#   Parse <args> (+arg) of a command and return <item> if found
#   + <args> : Arguments of a tool command containing +args
#   + <item> : Element to find in the +args string
#-----------------------------------------------------------------------------
proc ::kVutils::get_plusargs { args item } {

    # Extract simulation arguments "+args"
    set plusargs [regexp -all -inline -- {\+\w+=[^\s]+?} $args]

    # Parse +args
    set re [subst -nocommands -nobackslashes {\+${item}=([^\s]+)}]
    if { ![regexp -- $re $plusargs tmp plusarg] } {
        error "Unable to find $item in $plusargs"
    }
    return $plusarg
}

#-----------------------------------------------------------------------------
# GET_MINARG
#
#   Parse <args> (-arg) of a command and return <item> if found
#   + <args> : Arguments of a tool command containing -args
#   + <item> : Element to find in the -args string
#-----------------------------------------------------------------------------
proc ::kVutils::get_minargs { args item } {

    # Extract simulation arguments "+args"
    set minargs [regexp -all -inline -- {\-\w+\s+\.+?[^\s]+?} $args]

    # Parse -args
    set re [subst -nocommands -nobackslashes {\-${item}\s+([^\s]+)}]
    if { ![regexp -- $re [lindex $minargs 0] tmp minarg] } {
        error "Unable to find $item in $minargs"
    }
    return $minarg
}

#-----------------------------------------------------------------------------
# HAS_FLAG
#
#   Parse <args> of a command and return true if <flag> is found
#   + <args> : Arguments of a tool command
#   + <flag> : Element to find in the args string
#-----------------------------------------------------------------------------
proc ::kVutils::has_flag { args flag } {

    return [regexp -- [::kVutils::to_re $flag] $args]
}

#-----------------------------------------------------------------------------
# EVAL_CMD
#
#   Converts nested string <cmd> into a flat string.
#   Evaluate the flattened string from the tool
#-----------------------------------------------------------------------------
proc ::kVutils::eval_cmd { cmd } {

    set len 0
    while { [llength $cmd] > $len } {
        set len [llength $cmd]
        set cmd [join $cmd]
    }
    uplevel #0 $cmd
}

#-----------------------------------------------------------------------------
# PARSE_ARGS
#
#   Basic parsing of procedures arguments:
#   - argList format: { <arg> [val] }
#   - optList format: { {<arg> bool|val <default> <definition> } {...} ...}
#-----------------------------------------------------------------------------
proc ::kVutils::parse_args { argList optList {usage ""} } {

    set help [::kVutils::parse_usage $optList $usage]

    if { [lsearch -exact $argList -help] > -1 } {
        error $help
    }

    array set arguments [list ]

    # Arguments list
    for {set i 0} {$i < [llength $argList]} {incr i} {
        set arg [lindex $argList $i]
        set opt [lsearch -exact -index 0 -all -inline $optList $arg]
        if { [llength $opt] } {
            if { [string match "bool" [lindex $opt 0 1]] } {
                set arguments($arg) 1
            } elseif { [string match "val" [lindex $opt 0 1]] } {
                set arguments($arg) [lindex $argList $i+1]
                incr i
            } else {
                error "::kVutils::parse_args: options have a wrong format\n$help"
            }
        } else {
            error "::kVutils::parse_args: $arg is not a valid option\n$help"
        }
    }

    # Default values
    foreach opt $optList {
        set arg [lindex $opt 0]
        if { [array names arguments $arg] == "" } {
            set arguments($arg) [lindex $opt 2]
        }
    }

    return [array get arguments]
}

#-----------------------------------------------------------------------------
# PARSE_USAGE
#
#   Returns a string detailing options in <optList>
#-----------------------------------------------------------------------------
proc ::kVutils::parse_usage { {optList ""} {usage ""} } {

    set msg ""

    foreach u $usage {
        append msg "$u\n"
    }
    if { [llength $optList] > 0 } {
        append msg "options:\n"
    }

    set header [subst "%10s : %s\n"]

    foreach opt $optList {
        append msg [format $header [lindex $opt 0] [lindex $opt 3]]
    }

    return $msg
}
