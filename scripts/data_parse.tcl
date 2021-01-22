#!/usr/local/opt/tcl8.6.10/bin/tclsh8.6
#-----------------------------------------------------------------------------
# Project : KeyV
# File    : data_parse.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-04-27 Mon>
# Brief   : Converts post-synthesis + simulation results into csv tables
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh
# [tcsh]% ./scripts/data_parse.tcl
#-----------------------------------------------------------------------------
package require Tcl 8.6

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
source $::env(KEYV_SCRIPTS)/KeyRing.tcl

#-------------------------------------------------------------------------
# PARSE STA
#
#  Parse *KeyV* STA reports and produce csv summaries
#-------------------------------------------------------------------------
proc parse_sta core {

    global keyring
    global MODULES
    global CORES
    global STA_RPT
    global STA_CSV

    #---------------------------------------------------------------------
    # Init CSV & RPT files
    #---------------------------------------------------------------------
    if { [lsearch $CORES $core] < 0 } {
        error "parse_sta:: core $core is not in the processor list ($CORES)"
    }
    set rpt [::kVutils::file_read $STA_RPT($core)]
    set csv $STA_CSV($core)
    ::kVutils::file_init $csv 1

    #---------------------------------------------------------------------
    # KeyRing
    #---------------------------------------------------------------------
    if { [info exist keyring] } {
        $keyring destroy
    }
    if { $core == "keyv362" } {
        set keyring [KeyRing create "main" 3 6 2]

    } elseif { $core == "keyv661" } {
        set keyring [KeyRing create "main" 6 6 1]

    } else {
        error "parse_sta:: core $core cannot be parsed (keyv362 or keyv661 only)"
    }

    #---------------------------------------------------------------------
    # Parse timing report to find clocks timing (delay + sta)
    #---------------------------------------------------------------------
    set click_re [subst -nocommands -nobackslashes {C_main_[0-9][0-9]}]
    set val_re   [subst -nocommands -nobackslashes {\|\s+-?[0-9]+\.?[0-9]*e?-?[0-9]*\s+}]
    set clk_re   [subst -nocommands -nobackslashes {\|\s+C_main_[0-9][0-9]_\w+_\w+\s+}]
    set sta_re   [subst -nocommands -nobackslashes {${clk_re}${clk_re}${val_re}${val_re}}]
    set sta      [regexp -all -inline $sta_re $rpt]

    # Return a formatted version of XU stages: F0 instead of C_main_00
    proc keyv_click_to_stages click {
        array set stages {
            0 F
            1 D
            2 R
            3 E
            4 M
            5 W
        }
        set e [string index [lindex [split $click _] end] 0]
        set s [string index [lindex [split $click _] end] 1]
        return "$stages($s)$e"
    }

    # Parse each line of clocks timing information
    foreach l $sta {

        set dat     [split $l |]
        set launch  [string trim [lindex $dat 1]]
        set capture [string trim [lindex $dat 2]]
        set delay   [string trim [lindex $dat 3]]
        set slack   [string trim [lindex $dat 4]]

        set click [regexp -inline $click_re $capture]
        set click_s [keyv_click_to_stages $click]

        set parent_launch  [regexp -inline {_right_|_left_|_up_|_down_} $launch]
        set parent_capture [regexp -inline {_right_|_left_|_up_|_down_} $capture]

        if { $parent_launch == $parent_capture } {
            if { [regexp {left|down} $parent_launch] } {
                set from [$keyring get_parent $click -left]
            }
            if { [regexp {up|right} $parent_launch] } {
                set from [$keyring get_parent $click -up]
            }
            set from_s [keyv_click_to_stages $from]

            if { [string match *setup* $launch] } {
                dict set csv_d $click_s $from_s setup delay $delay
                dict set csv_d $click_s $from_s setup slack $slack
            }
            if { [string match *hold* $launch] } {
                dict set csv_d $click_s $from_s hold delay $delay
                dict set csv_d $click_s $from_s hold slack $slack
            }
        }
    }

    #---------------------------------------------------------------------
    # Write data to CSV
    #---------------------------------------------------------------------
    set head    "%s,%s,%s,%s,%s,%s"
    set content "%s,%s,%.2f,%.2f,%.2f,%.2f"
    set header  [format $head "LAUNCH" "CAPTURE" "SETUP DELAY" "SETUP SLACK" "HOLD DELAY" "HOLD SLACK"]

    ::kVutils::file_init $csv
    ::kVutils::file_write $csv $header

    dict for {capture c} [dict get $csv_d] {
        dict for {launch l} [dict get $c] {
            ::kVutils::file_write $csv [format $content                  \
                                               $launch                   \
                                               $capture                  \
                                               [dict get $l setup delay] \
                                               [dict get $l setup slack] \
                                               [dict get $l hold delay]  \
                                               [dict get $l hold slack]]
        }
    }
}

#-------------------------------------------------------------------------
# PARSE_AREA
#
#   Parse area reports and produce csv summaries
#-------------------------------------------------------------------------
proc parse_area core {

    global MODULES
    global CORES
    global AREA_RPT
    global AREA_CSV

    #---------------------------------------------------------------------
    # Init CSV & RPT files
    #---------------------------------------------------------------------
    if { [lsearch $CORES $core] < 0 } {
        error "parse_area:: $core is not in the core list ($CORES)"
    }
    if { ![file exists $AREA_RPT($core)] } {
        error "parse_area:: file $AREA_RPT($core) not found"
    }
    set rpt [::kVutils::file_read $AREA_RPT($core)]
    set csv $AREA_CSV($core)
    ::kVutils::file_init $csv 1

    #---------------------------------------------------------------------
    # Parse area report
    #---------------------------------------------------------------------
    set val_re          [subst -nocommands -nobackslashes {([0-9]+\.[0-9]+e?-?[0-9]+\s+)}]
    set glob_re(cmb)    [subst -nocommands -nobackslashes {(Combinational area:\s+)${val_re}}]
    set glob_re(inv)    [subst -nocommands -nobackslashes {(Buf/Inv area:\s+)${val_re}}]
    set glob_re(seq)    [subst -nocommands -nobackslashes {(Noncombinational area:\s+)${val_re}}]
    set glob_re(tot)    [subst -nocommands -nobackslashes {(Total cell area:\s+)${val_re}}]
    foreach m $MODULES($core) {
        set module_re($m) [subst -nocommands -nobackslashes {(u_${m}\s+\w+\s+)${val_re}}]
    }

    # create dict with parsed area values
    foreach {m re} [array get glob_re] {
        if { [regexp $re $rpt all tmp area] } {
            dict set csv_glob $m [string trim $area]
        } else {
            error "parse_area:: module $m not found in $AREA_RPT($core)"
        }
    }
    foreach {m re} [array get module_re] {
        if { [regexp $re $rpt all tmp area] } {
            dict set csv_mod $m [string trim $area]
        } else {
            error "parse_area:: module $m not found in $AREA_RPT($core)"
        }
    }
    # core area is total-sum(modules)
    dict set csv_core core [expr [dict get $csv_glob tot] - [::tcl::mathop::+ {*}[dict values $csv_mod]]]

    #---------------------------------------------------------------------
    # Write data to CSV
    #---------------------------------------------------------------------

    set header  "CORE";
    set content [format "%.6e" [dict get $csv_core core]]
    dict for {m a} [dict get $csv_mod] {
        append header  [format ",%s" [string toupper $m]]
        append content [format ",%.6e" $a]
    }
    dict for {m a} [dict get $csv_glob] {
        append header  [format ",%s" [string toupper $m]]
        append content [format ",%.6e" $a]
    }
    ::kVutils::file_write $csv $header
    ::kVutils::file_write $csv $content
}

#-------------------------------------------------------------------------
# PARSE_BENCHMARKS
#
#   Parse simulation & power reports and produce a benchmark csv summary
#-------------------------------------------------------------------------
proc parse_benchmarks core {

    global CORES
    global MODULES
    global PWR_RPT
    global SIM_RPT
    global BENCH_CSV

    set PERIOD     [expr 2e-09]
    set BENCHMARKS [list dhrystone coremark]

    set SIM_ADDR_CYCLE(dhrystone) 2
    set SIM_ADDR_INST(dhrystone)  3
    set SIM_ADDR_CYCLE(coremark)  8
    set SIM_ADDR_INST(coremark)   6

    if { [lsearch $CORES $core] < 0 } {
        error "parse_bechmarks:: $core is not in the core list ($CORES)"
    }

    #-------------------------------------------------------------------------
    # Parse simulation reports
    #-------------------------------------------------------------------------
    foreach bench $BENCHMARKS {

        regsub -all {<B>} $SIM_RPT($core) $bench sim_rpt
        if { ![file exists $sim_rpt] } {
            error "parse_benchmarks:: file $sim_rpt not found"
        }
        set simrpt [::kVutils::file_read $sim_rpt]

        # Cycles
        set cycle_re [subst -nocommands -nobackslashes {($SIM_ADDR_CYCLE($bench):\s+)(\w+)}]
        regexp $cycle_re $simrpt all addr cycles
        dict set csv_sim $bench cycles [format %u 0x$cycles]

        # Insts
        set inst_re [subst -nocommands -nobackslashes {($SIM_ADDR_INST($bench):\s+)(\w+)}]
        regexp $inst_re $simrpt all addr insts
        dict set csv_sim $bench insts [format %u 0x$insts]
    }

    #-------------------------------------------------------------------------
    # Parse power reports
    #-------------------------------------------------------------------------
    set val_re          [subst -nocommands -nobackslashes {([0-9]+\.[0-9]+e?-?[0-9]+\s+)}]
    set glob_re(ct)     [subst -nocommands -nobackslashes {(clock_network\s+)${val_re}+}]
    set glob_re(reg)    [subst -nocommands -nobackslashes {(register\s+)${val_re}+}]
    set glob_re(cmb)    [subst -nocommands -nobackslashes {(combinational\s+)${val_re}+}]
    set glob_re(seq)    [subst -nocommands -nobackslashes {(sequential\s+)${val_re}+}]
    set glob_re(sw)     [subst -nocommands -nobackslashes {(Net Switching Power\s+=\s+)${val_re}}]
    set glob_re(int)    [subst -nocommands -nobackslashes {(Cell Internal Power\s+=\s+)${val_re}}]
    set glob_re(lk)     [subst -nocommands -nobackslashes {(Cell Leakage Power\s+=\s+)${val_re}}]
    set glob_re(tot)    [subst -nocommands -nobackslashes {(Total Power\s+=\s+)${val_re}}]
    foreach m $MODULES($core) {
        set module_re($m) [subst -nocommands -nobackslashes {(u_${m}\s+\(\w+\)\s+)${val_re}+}]
    }

    foreach bench $BENCHMARKS {

        # Parse power report only if simulation result successfully parsed
        if { [dict exist [dict get $csv_sim] $bench] } {

            regsub -all {<B>} $PWR_RPT($core) $bench pwr_rpt
            if { ![file exists $pwr_rpt] } {
                error "parse_benchmarks:: file $pwr_rpt not found"
            }
            set pwrpt [::kVutils::file_read $pwr_rpt]

            foreach {m re} [array get glob_re] {
                if { [regexp $re $pwrpt all] } {
                    dict set csv_glob $bench $m [string trim [lindex $all end]]
                } else {
                    error "parse_benchmarks:: module $m not found in $pwr_rpt"
                }
            }
            foreach {m re} [array get module_re] {
                if { [regexp $re $pwrpt all] } {
                    dict set csv_mod $bench $m [string trim [lindex $all end]]
                } else {
                    error "parse_benchmarks:: module $m not found in $pwr_rpt"
                }
            }
            # core power is total-sum(modules)
            set tmod 0
            dict for {m p} [dict get $csv_mod $bench] {
                set tmod [expr $tmod + $p]
            }
            dict set csv_core $bench core [expr [dict get $csv_glob $bench tot] - $tmod]
        }
    }

    #-------------------------------------------------------------------------
    # Write data to CSV
    #-------------------------------------------------------------------------
    set csv $BENCH_CSV($core)
    ::kVutils::file_init $csv 1

    # Header
    set header "BENCH,CORE";
    dict for {m c} [dict get $csv_mod $bench] {
        append header  [format ",%s" [string toupper $m]]
    }
    dict for {m c} [dict get $csv_glob $bench] {
        append header  [format ",%s" [string toupper $m]]
    }
    dict for {m c} [dict get $csv_sim $bench] {
        append header  [format ",%s" [string toupper $m]]
    }
    ::kVutils::file_write $csv $header

    # Content
    foreach bench $BENCHMARKS {
        set content [format "%s" $bench]
        append content [format ",%.6e" [dict get $csv_core $bench core]]
        dict for {m c} [dict get $csv_mod $bench] {
            append content [format ",%.6e" $c]
        }
        dict for {m c} [dict get $csv_glob $bench] {
            append content [format ",%.6e" $c]
        }
        dict for {m c} [dict get $csv_sim $bench] {
            append content [format ",%.6e" $c]
        }
        ::kVutils::file_write $csv $content
    }
}

#-------------------------------------------------------------------------
#
#                                MAIN
#
#-------------------------------------------------------------------------
set CORES [list keyv362 keyv661 synv synvcg]

set MODULES(synv)    [list idecode pc rf alu lsu sys perf clock_and_reset]
set MODULES(synvcg)  [list idecode pc rf alu lsu sys perf clock_and_reset]
set MODULES(keyv362) [list idecode pc rf alu lsu sys perf keyring xbs cycle_sync xu_0 xu_1 xu_2]
set MODULES(keyv661) [list idecode pc rf alu lsu sys perf keyring xbs cycle_sync xu_0 xu_1 xu_2 xu_3 xu_4 xu_5]

# INPUTS
set STA_RPT(keyv362)  $::env(KEYV_DATA)/keyv362/keyv362.timing.rpt
set STA_RPT(keyv661)  $::env(KEYV_DATA)/keyv661/keyv661.timing.rpt
set STA_RPT(synv)     $::env(KEYV_DATA)/synv/synv.timing.rpt
set STA_RPT(synvcg)   $::env(KEYV_DATA)/synvcg/synvcg.timing.rpt
set AREA_RPT(keyv362) $::env(KEYV_DATA)/keyv362/keyv362.area.rpt
set AREA_RPT(keyv661) $::env(KEYV_DATA)/keyv661/keyv661.area.rpt
set AREA_RPT(synv)    $::env(KEYV_DATA)/synv/synv.area.rpt
set AREA_RPT(synvcg)  $::env(KEYV_DATA)/synvcg/synvcg.area.rpt
set PWR_RPT(keyv362)  $::env(KEYV_DATA)/keyv362/keyv362.pwr.<B>.rpt
set PWR_RPT(keyv661)  $::env(KEYV_DATA)/keyv661/keyv661.pwr.<B>.rpt
set PWR_RPT(synv)     $::env(KEYV_DATA)/synv/synv.pwr.<B>.rpt
set PWR_RPT(synvcg)   $::env(KEYV_DATA)/synvcg/synvcg.pwr.<B>.rpt
set SIM_RPT(keyv362)  $::env(KEYV_DATA)/keyv362/keyv362.sim.<B>.rpt
set SIM_RPT(keyv661)  $::env(KEYV_DATA)/keyv661/keyv661.sim.<B>.rpt
set SIM_RPT(synv)     $::env(KEYV_DATA)/synv/synv.sim.<B>.rpt
set SIM_RPT(synvcg)   $::env(KEYV_DATA)/synvcg/synvcg.sim.<B>.rpt

# OUTPUTS
set BENCH_CSV(keyv362) $::env(KEYV_DATA)/keyv362/keyv362.benchmarks.csv
set BENCH_CSV(keyv661) $::env(KEYV_DATA)/keyv661/keyv661.benchmarks.csv
set BENCH_CSV(synv)    $::env(KEYV_DATA)/synv/synv.benchmarks.csv
set BENCH_CSV(synvcg)  $::env(KEYV_DATA)/synvcg/synvcg.benchmarks.csv
set AREA_CSV(keyv362)  $::env(KEYV_DATA)/keyv362/keyv362.area.csv
set AREA_CSV(keyv661)  $::env(KEYV_DATA)/keyv661/keyv661.area.csv
set AREA_CSV(synv)     $::env(KEYV_DATA)/synv/synv.area.csv
set AREA_CSV(synvcg)   $::env(KEYV_DATA)/synvcg/synvcg.area.csv
set STA_CSV(keyv362)   $::env(KEYV_DATA)/keyv362/keyv362.timing.csv
set STA_CSV(keyv661)   $::env(KEYV_DATA)/keyv661/keyv661.timing.csv
set STA_CSV(synv)      $::env(KEYV_DATA)/synv/synv.timing.csv
set STA_CSV(synvcg)    $::env(KEYV_DATA)/synvcg/synvcg.timing.csv

parse_area synv
parse_area synvcg
parse_area keyv362
parse_area keyv661

parse_sta keyv661
parse_sta keyv362

parse_benchmarks synv
parse_benchmarks synvcg
parse_benchmarks keyv362
parse_benchmarks keyv661
