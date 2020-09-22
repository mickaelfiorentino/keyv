#!/bin/tclsh
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

#-------------------------------------------------------------------------
#
#                                     STA
#
#-------------------------------------------------------------------------
proc parse_sta csv {

    global STA_RPT

    # Read timing report
    set rpt [::kVutils::file_read $STA_RPT]

    #---------------------------------------------------------------------
    # Init CSV
    #---------------------------------------------------------------------
    set head    "%s,%s,%s,%s,%s,%s"
    set content "%s,%s,%.2f,%.2f,%.2f,%.2f"
    set header  [format $head "LAUNCH" "CAPTURE" "SETUP DELAY" "SETUP SLACK" "HOLD DELAY" "HOLD SLACK"]

    ::kVutils::file_init $csv
    ::kVutils::file_write $csv $header

    #---------------------------------------------------------------------
    # Parse timing report to find clocks timing (delay + sta)
    #---------------------------------------------------------------------
    set val_re [subst -nocommands -nobackslashes {\|\s+-?[0-9]+\.?[0-9]*e?-?[0-9]*\s+}]
    set clk_re [subst -nocommands -nobackslashes {\|\s+C_main_[0-9][0-9]\w+\s+}]
    set sta_re [subst -nocommands -nobackslashes {${clk_re}${clk_re}${val_re}${val_re}}]
    set sta    [regexp -all -inline $sta_re $rpt]

    #---------------------------------------------------------------------
    # Create data structure from clocks timing (from::to::setup,hold)
    #---------------------------------------------------------------------
    array set keyv_stages {
        0 F
        1 D
        2 R
        3 E
        4 M
        5 W
    }
    array set keyv_eus {
        0 x0
        1 x1
        2 x2
        3 x3
        4 x4
        5 x5
    }
    set S [array size keyv_stages]
    set E [array size keyv_eus]

    # KeyRing dependencies
    foreach {i e} [array get keyv_eus] {
        foreach {j s} [array get keyv_stages] {
            dict set keyv_dep ${s}${e} left  $keyv_stages([expr ($j-1)%$S])$keyv_eus([expr ($i)%$E])
            dict set keyv_dep ${s}${e} right $keyv_stages([expr ($j+1)%$S])$keyv_eus([expr ($i)%$E])
            dict set keyv_dep ${s}${e} up    $keyv_stages([expr ($j+1)%$S])$keyv_eus([expr ($i-1)%$E])
            dict set keyv_dep ${s}${e} down  $keyv_stages([expr ($j-1)%$S])$keyv_eus([expr ($i+1)%$E])
        }
    }

    # Parse each line of clocks timing information assuming clocks are of the form:
    # C_main_00_setup_left_capture
    foreach l $sta {

        set dat     [split $l |]
        set launch  [string trim [lindex $dat 1]]
        set capture [string trim [lindex $dat 2]]
        set delay   [string trim [lindex $dat 3]]
        set slack   [string trim [lindex $dat 4]]

        regexp {[0-9][0-9]} $capture id
        set e $keyv_eus([string range $id 0 0])
        set s $keyv_stages([string range $id 1 1])

        set dep_launch  [lindex [split $launch _] end-1]
        set dep_capture [lindex [split $capture _] end-1]
        set setup_hold  [lindex [split $capture _] end-2]

        if { [string match $dep_launch $dep_capture] } {
            set from [dict get $keyv_dep ${s}${e} $dep_launch]
            if { [string match *setup* $launch] } {
                dict set csv_sta ${s}${e} $from setup delay $delay
                dict set csv_sta ${s}${e} $from setup slack $slack
                dict set csv_sta ${s}${e} $from hold  delay -1
                dict set csv_sta ${s}${e} $from hold  slack -1
            }
            if { [string match *hold* $launch] } {
                dict set csv_sta ${s}${e} $from hold  delay $delay
                dict set csv_sta ${s}${e} $from hold  slack $slack
                dict set csv_sta ${s}${e} $from setup delay -1
                dict set csv_sta ${s}${e} $from setup slack -1
            }
        }
    }

    #---------------------------------------------------------------------
    # Write data to CSV
    #---------------------------------------------------------------------
    dict for {capture c} [dict get $csv_sta] {
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
#
#                                AREA
#
#-------------------------------------------------------------------------
proc parse_area csv {

    global AREA_RPT

    #---------------------------------------------------------------------
    # Init CSV
    #---------------------------------------------------------------------
    set head    "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
    set content "%s,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e"
    set header [format $head "PROCESSOR" "CMB" "BUF" "SEQ" "TOTAL" \
                    "AR-IDECODE" "AR-PC" "AR-RF" "AR-ALU" "AR-LSU" "AR-SYS" "AR-PERF" \
                    "AR-RST-SYNC" "AR-KEYRING" "AR-PERF-SYNC" "AR-XBS" \
                    "AR-XU0" "AR-XU1" "AR-XU2" "AR-XU3" "AR-XU4" "AR-XU5"]

    ::kVutils::file_init $csv
    ::kVutils::file_write $csv $header

    #---------------------------------------------------------------------
    # Regexp to parse area report
    #---------------------------------------------------------------------
    set val_re           [subst -nocommands -nobackslashes {([0-9]+\.[0-9]+e?-?[0-9]+\s+)}]
    set area_re(cmb)     [subst -nocommands -nobackslashes {(Combinational area:\s+)${val_re}}]
    set area_re(inv)     [subst -nocommands -nobackslashes {(Buf/Inv area:\s+)${val_re}}]
    set area_re(seq)     [subst -nocommands -nobackslashes {(Noncombinational area:\s+)${val_re}}]
    set area_re(tot)     [subst -nocommands -nobackslashes {(Total cell area:\s+)${val_re}}]
    set area_re(idecode) [subst -nocommands -nobackslashes {(u_idecode\s+\w+\s+)${val_re}}]
    set area_re(pc)      [subst -nocommands -nobackslashes {(u_pc\s+\w+\s+)${val_re}}]
    set area_re(rf)      [subst -nocommands -nobackslashes {(u_rf\s+\w+\s+)${val_re}}]
    set area_re(alu)     [subst -nocommands -nobackslashes {(u_alu\s+\w+\s+)${val_re}}]
    set area_re(lsu)     [subst -nocommands -nobackslashes {(u_lsu\s+\w+\s+)${val_re}}]
    set area_re(sys)     [subst -nocommands -nobackslashes {(u_sys\s+\w+\s+)${val_re}}]
    set area_re(perf)    [subst -nocommands -nobackslashes {(u_perf\s+\w+\s+)${val_re}}]
    set area_re(clk_rst) [subst -nocommands -nobackslashes {(u_clock_and_reset\s+\w+\s+)${val_re}}]
    set area_re(keyring) [subst -nocommands -nobackslashes {(u_keyring\s+\w+\s+)${val_re}}]
    set area_re(cycle)   [subst -nocommands -nobackslashes {(u_cycle_sync\s+\w+\s+)${val_re}}]
    set area_re(xbs)     [subst -nocommands -nobackslashes {(u_xbs\s+\w+\s+)${val_re}}]
    set area_re(xu_0)    [subst -nocommands -nobackslashes {(u_xu_0\s+\w+\s+)${val_re}}]
    set area_re(xu_1)    [subst -nocommands -nobackslashes {(u_xu_1\s+\w+\s+)${val_re}}]
    set area_re(xu_2)    [subst -nocommands -nobackslashes {(u_xu_2\s+\w+\s+)${val_re}}]
    set area_re(xu_3)    [subst -nocommands -nobackslashes {(u_xu_3\s+\w+\s+)${val_re}}]
    set area_re(xu_4)    [subst -nocommands -nobackslashes {(u_xu_4\s+\w+\s+)${val_re}}]
    set area_re(xu_5)    [subst -nocommands -nobackslashes {(u_xu_5\s+\w+\s+)${val_re}}]

    #---------------------------------------------------------------------
    # Parse each processor report
    #---------------------------------------------------------------------
    foreach {p r} [array get AREA_RPT] {
        if { [file exists $r] } {
            set rpt [::kVutils::file_read $r]
            foreach {g re} [array get area_re] {
                if { [regexp $re $rpt all tmp area] } {
                    dict set csv_area $p $g [string trim $area]
                } else {
                    dict set csv_area $p $g -1
                }
            }
        } else {
            puts "$r not found"
        }
    }

    #---------------------------------------------------------------------
    # Write data to CSV
    #---------------------------------------------------------------------
    dict for {p d} [dict get $csv_area] {
        dict with d {
            ::kVutils::file_write $csv [format $content $p $cmb $inv $seq $tot \
                                               $idecode $pc $rf $alu $lsu $sys $perf $clk_rst \
                                               $keyring $cycle $xbs $xu_0 $xu_1 $xu_2 $xu_3 $xu_4 $xu_5]
        }
    }
}

#-------------------------------------------------------------------------
#
#                              BENCHMARKS
#
#-------------------------------------------------------------------------
proc parse_benchmarks csv {

    global PWR_RPT
    global SIM_RPT
    global SIM_ADDR_INST
    global SIM_ADDR_CYCLE
    global PROCESSORS
    global BENCHMARKS
    global PERIOD

    #-------------------------------------------------------------------------
    # Init CSV
    #-------------------------------------------------------------------------
    set head    "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s"
    set content "%s,%s,%.6e,%d,%d,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e"

    set header [format $head "PROCESSOR" "BENCHMARK" "PERIOD" "CYCLES" "INSTS" "PWR-TOT" \
                    "PWR-INT" "PWR-SWITCH" "PWR-LEAK" "PWR-CT" "PWR-SEQ" "PWR-REG" "PWR-CMB" \
                    "PWR-IDECODE" "PWR-PC" "PWR-RF" "PWR-ALU" "PWR-LSU" "PWR-SYS" "PWR-PERF" \
                    "PWR-RST-SYNC" "PWR-KEYRING" "PWR-PERF-SYNC" "PWR-XBS" \
                    "PWR-XU0" "PWR-XU1" "PWR-XU2" "PWR-XU3" "PWR-XU4" "PWR-XU5"]

    ::kVutils::file_init $csv
    ::kVutils::file_write $csv $header

    #-------------------------------------------------------------------------
    # Regexp to parse power reports
    #-------------------------------------------------------------------------
    set val_re          [subst -nocommands -nobackslashes {([0-9]+\.[0-9]+e?-?[0-9]+\s+)}]
    set pwr_re(ct)      [subst -nocommands -nobackslashes {(clock_network\s+)${val_re}+}]
    set pwr_re(reg)     [subst -nocommands -nobackslashes {(register\s+)${val_re}+}]
    set pwr_re(cmb)     [subst -nocommands -nobackslashes {(combinational\s+)${val_re}+}]
    set pwr_re(seq)     [subst -nocommands -nobackslashes {(sequential\s+)${val_re}+}]
    set pwr_re(sw)      [subst -nocommands -nobackslashes {(Net Switching Power\s+=\s+)${val_re}}]
    set pwr_re(int)     [subst -nocommands -nobackslashes {(Cell Internal Power\s+=\s+)${val_re}}]
    set pwr_re(lk)      [subst -nocommands -nobackslashes {(Cell Leakage Power\s+=\s+)${val_re}}]
    set pwr_re(tot)     [subst -nocommands -nobackslashes {(Total Power\s+=\s+)${val_re}}]
    set pwr_re(idecode) [subst -nocommands -nobackslashes {(u_idecode\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(pc)      [subst -nocommands -nobackslashes {(u_pc\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(rf)      [subst -nocommands -nobackslashes {(u_rf\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(alu)     [subst -nocommands -nobackslashes {(u_alu\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(lsu)     [subst -nocommands -nobackslashes {(u_lsu\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(sys)     [subst -nocommands -nobackslashes {(u_sys\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(perf)    [subst -nocommands -nobackslashes {(u_perf\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(clk_rst) [subst -nocommands -nobackslashes {(u_clock_and_reset\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(keyring) [subst -nocommands -nobackslashes {(u_keyring\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(cycle)   [subst -nocommands -nobackslashes {(u_cycle_sync\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xbs)     [subst -nocommands -nobackslashes {(u_xbs\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xu_0)    [subst -nocommands -nobackslashes {(u_xu_0\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xu_1)    [subst -nocommands -nobackslashes {(u_xu_1\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xu_2)    [subst -nocommands -nobackslashes {(u_xu_2\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xu_3)    [subst -nocommands -nobackslashes {(u_xu_3\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xu_4)    [subst -nocommands -nobackslashes {(u_xu_4\s+\(\w+\)\s+)${val_re}+}]
    set pwr_re(xu_5)    [subst -nocommands -nobackslashes {(u_xu_5\s+\(\w+\)\s+)${val_re}+}]

    #---------------------------------------------------------------------
    # Parse simulation reports for each benchmark,processor
    #---------------------------------------------------------------------
    foreach b $BENCHMARKS {
        foreach p $PROCESSORS {

            regsub -all {<B>} $SIM_RPT($p) $b rpt_name
            if { [file exists $rpt_name] } {
                set rpt [::kVutils::file_read $rpt_name]

                # Cycles
                set cycle_re [subst -nocommands -nobackslashes {($SIM_ADDR_CYCLE($b):\s+)(\w+)}]
                regexp $cycle_re $rpt all addr cycles
                dict set csv_dat $b $p cycles [format %u 0x$cycles]

                # Insts
                set inst_re [subst -nocommands -nobackslashes {($SIM_ADDR_INST($b):\s+)(\w+)}]
                regexp $inst_re $rpt all addr insts
                dict set csv_dat $b $p insts [format %u 0x$insts]

            } else {
                puts "$rpt_name not found"
            }
        }
    }

    #---------------------------------------------------------------------
    # Parse power reports for each benchmark,processor
    #---------------------------------------------------------------------
    foreach b $BENCHMARKS {
        foreach p $PROCESSORS {

            # Parse power report only if simulation result successfully parsed
            if { [dict exist [dict get $csv_dat] $b] } {
                if { [dict exist [dict get $csv_dat $b] $p] } {

                    regsub -all {<B>} $PWR_RPT($p) $b rpt_name
                    if { [file exists $rpt_name] } {
                        set rpt [::kVutils::file_read $rpt_name]

                        foreach {g r} [array get pwr_re] {
                            if { [regexp $r $rpt all] } {
                                dict set csv_dat $b $p $g [string trim [lindex $all end]]
                            } else {
                                dict set csv_dat $b $p $g -1
                            }
                        }
                    # If power report does not exist, remove entry $p from dict
                    } else {
                        puts "$rpt_name not found"
                        dict set csv_dat $b [dict remove [dict get $csv_dat $b] $p]
                    }
                }
            }
        }
        # Remove entry $b from dict if empty
        if { [dict exist [dict get $csv_dat] $b] } {
            if { [dict size [dict get $csv_dat $b]] == 0 } {
                dict set csv_dat [dict remove [dict get $csv_dat] $b]
            }
        }
    }

    #-------------------------------------------------------------------------
    # Write data to CSV
    #-------------------------------------------------------------------------
    dict for {b dat} [dict get $csv_dat] {
        dict for {p d} [dict get $dat] {
            dict with d {
                ::kVutils::file_write $csv                              \
                    [format $content $p $b                              \
                         $PERIOD $cycles $insts                         \
                         $tot $int $sw $lk                              \
                         $ct $seq $reg $cmb                             \
                         $idecode $pc $rf $alu $lsu $sys $perf $clk_rst \
                         $keyring $cycle $xbs $xu_0 $xu_1 $xu_2 $xu_3 $xu_4 $xu_5]
            }
        }
    }
}

#-------------------------------------------------------------------------
#
#                                MAIN
#
#-------------------------------------------------------------------------
set STA_RPT           $::env(KEYV_SYN)/keyv/reports/keyv.syn.timing.rpt
set AREA_RPT(synv)    $::env(KEYV_SYN)/synv/reports/synv.syn.area.rpt
set AREA_RPT(synv_cg) $::env(KEYV_SYN)/synv/reports/synv.cg.area.rpt
set AREA_RPT(keyv)    $::env(KEYV_SYN)/keyv/reports/keyv.syn.area.rpt
set PWR_RPT(synv)     $::env(KEYV_SYN)/synv/reports/synv.syn.pwr.<B>.rpt
set PWR_RPT(synv_cg)  $::env(KEYV_SYN)/synv/reports/synv.cg.pwr.<B>.rpt
set PWR_RPT(keyv)     $::env(KEYV_SYN)/keyv/reports/keyv.syn.pwr.<B>.rpt
set SIM_RPT(synv)     $::env(KEYV_SIM)/synv/syn/<B>/synv.syn.<B>.iopad.mti
set SIM_RPT(synv_cg)  $::env(KEYV_SIM)/synv/cg/<B>/synv.cg.<B>.iopad.mti
set SIM_RPT(keyv)     $::env(KEYV_SIM)/keyv/syn/<B>/keyv.syn.<B>.iopad.mti

set CSV_BENCH  $::env(KEYV_DATA)/benchmarks_summary.csv
set CSV_AREA   $::env(KEYV_DATA)/area_summary.csv
set CSV_STA    $::env(KEYV_DATA)/sta_summary.csv

set BENCHMARKS [list dhrystone coremark]
set PROCESSORS [list synv synv_cg keyv]
set PERIOD     [expr 2e-09]

set SIM_ADDR_CYCLE(dhrystone) 2
set SIM_ADDR_INST(dhrystone)  3
set SIM_ADDR_CYCLE(coremark)  8
set SIM_ADDR_INST(coremark)   6

parse_sta $CSV_STA
parse_area $CSV_AREA
parse_benchmarks $CSV_BENCH
