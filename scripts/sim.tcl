#-----------------------------------------------------------------------------
# Project : KeyV
# File    : sim.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-25 Tue>
# Brief   : Modelsim compilation and simulation scrip
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh && cd simulation/
# [tcsh]% vsim -do ../scripts/sim.tcl <-c> +DESIGN=<d> +STEP=<s> +BENCH=<b>
# [tcsh]% vsim -view <d>/<s>/<b>/<d>.<s>.<b>.wlf -do <d>/<s>/<d>.<s>.wave.do
# <d> Design
#     + keyv: Key-V self-timed processor
#     + synv: Syn-V synchronous processor
# <s> Simulation step
#     + beh: Simulation of the behavioral model
#     + syn: Simulation of the post-synthesis netlist
#     + cg:  Simulation of the post-clock-gating netlist
# <b> Benchmark
#     + basic, fibo, dhrystone, coremark
#-----------------------------------------------------------------------------
package require Tcl 8.5

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------
if { ![info exist ::env(KEYV_HOME)] } {
    error "ERROR: Setup the environment with setup.csh prior to running this script"
}
if { ![file exists run.do] } {
    error "You should run this script from $::env(KEYV_SIM)"
}

global auto_path

if { [lsearch ${auto_path} $::env(KEYV_SCRIPTS)] < 0 } {
    lappend auto_path $::env(KEYV_SCRIPTS)
}
package require kVutils
package require kVsim

#-----------------------------------------------------------------------------
# SIMULATION FLOW
#-----------------------------------------------------------------------------
set DO_BEH  [expr 0 || [string match [::kVutils::get_plusargs $argv STEP] beh]]; # Behavioral sim
set DO_SYN  [expr 0 || [string match [::kVutils::get_plusargs $argv STEP] syn]]; # Post-synthesis sim
set DO_CG   [expr 0 || [string match [::kVutils::get_plusargs $argv STEP] cg]];  # Post-clock-gated sim
set DO_RUN  [expr 0 || [::kVutils::has_flag $argv +RUN]];                        # Run sim
set DO_SAIF [expr 0 || [::kVutils::has_flag $argv +SAIF]];                       # Save saif file
set DO_CLI  [expr 0 || [::kVutils::has_flag $argv -c]];                          # Run without gui

# Technology Library to use
set NTC        0;               # Lib compiled with +NTC argument
set NTC_RECREM 1;               # lib compiled with +NTC+RECREM argument

# Check if the configuration is correct: Only one true & one must be true
if { !($DO_BEH ^ $DO_SYN ^ $DO_CG)        } { error "Wrong +STEP configuration" }
if { ![::kVutils::has_flag $argv +DESIGN] } { error "Missing +DESIGN argument"  }
if { ![::kVutils::has_flag $argv +BENCH]  } { error "Missing +BENCH argument"   }

#-----------------------------------------------------------------------------
# PARAMETERS
#-----------------------------------------------------------------------------
set design   [::kVutils::get_plusargs $argv DESIGN]
set step     [::kVutils::get_plusargs $argv STEP]
set bench    [::kVutils::get_plusargs $argv BENCH]
set core     core
set top      top
set tb       tb
set work     work
set dut      u_${top}/u_${core}
set pad      /${tb}/u_${top}/u_iopad
set opt      _${design}
set sources  ${design}.src
set lib      tcbn65gplus

if { $DO_BEH } {
    set libD $::env(KEYV_TSMC65GP_SIMLIB)/tcbn65gplus_vital
} else {
    if { $NTC } {
        set libD $::env(KEYV_TSMC65GP_SIMLIB)/tcbn65gplus_ver_ntc
    } elseif { $NTC_RECREM } {
        set libD $::env(KEYV_TSMC65GP_SIMLIB)/tcbn65gplus_ver_ntc_recrem
    } else {
        set libD $::env(KEYV_TSMC65GP_SIMLIB)/tcbn65gplus_ver
    }
}

set simD  $::env(KEYV_SIM)/${design}/${step}/${bench}
set workD $::env(KEYV_SIM)/${design}/${step}/${bench}/${work}
set log   $::env(KEYV_SIM)/${design}/${step}/${bench}/${design}.${step}.${bench}.log
set wlf   $::env(KEYV_SIM)/${design}/${step}/${bench}/${design}.${step}.${bench}.wlf
set saif  $::env(KEYV_SIM)/${design}/${step}/${bench}/${design}.${step}.${bench}.saif
set mem   $::env(KEYV_SIM)/${design}/${step}/${bench}/${design}.${step}.${bench}.iopad.mti
set net   $::env(KEYV_SYN)/${design}/netlist/${design}.${step}.v
set sdf   $::env(KEYV_SYN)/${design}/netlist/${design}.${step}.sdf

# Simulation options
if { [::kVutils::has_flag $argv -c] } {
    set vsim_opt [subst {-c -t ps -voptargs=+acc -L $lib -logfile $log -wlf $wlf -do run.do}]
} else {
    set vsim_opt [subst {-t ps -voptargs=+acc -L $lib -logfile $log -do run.do}]
}

# Plusargs
set pargs ""
dict set plusargs DESIGN  $design
dict set plusargs STEP    $step
dict for {l c} [dict get $plusargs] { append pargs " +$l=$c" }

#-----------------------------------------------------------------------------
# LIBRARIES
#-----------------------------------------------------------------------------
if { ![file exist $simD] } {
    file mkdir $simD
}

if { [file exist "./modelsim.ini"] } {
    file delete "./modelsim.ini"
}
vmap -c

if { [file exist $workD] } {
    vdel -all -lib $workD
}
vlib $workD
vmap $work $workD

if { $DO_BEH } {
    vmap vital $::env(KEYV_TSMC65GP_SIMLIB)/vital
}

vmap $lib $libD

#-----------------------------------------------------------------------------
# COMPILATION
#-----------------------------------------------------------------------------

# Behavioral model
if { $DO_BEH } {
    foreach vhd [::kVutils::get_src $::env(KEYV_SRC)/${sources} "vhd"] {
        vcom -2008 -mixedsvvh -work $work $::env(KEYV_SRC)/$vhd
    }
    foreach ver [::kVutils::get_src $::env(KEYV_SRC)/${sources} "v"] {
        vlog -work $work $::env(KEYV_SRC)/$ver
    }
}

# Netlist
if { $DO_SYN || $DO_CG } {
    vcom -2008 -mixedsvvh -work $work $::env(KEYV_SRC)/generic/rv32_pkg.vhd
    vlog -work $work $net
}

# Top level & Test Bench
vlog -sv -mixedsvvh -work $work $::env(KEYV_SRC)/tb/tb_pkg.sv
vcom -2008 -mixedsvvh -work $work $::env(KEYV_SRC)/tb/dpm.vhd
vcom -2008 -mixedsvvh -work $work $::env(KEYV_SRC)/tb/top.vhd
vlog -sv -work $work $::env(KEYV_SRC)/tb/tb.sv

#-----------------------------------------------------------------------------
# SIMULATION
#-----------------------------------------------------------------------------
if { $DO_RUN } {

    # Functional simulation
    if { $DO_BEH } {
        ::kVutils::eval_cmd [subst {
            vsim $vsim_opt +transport_path_delays +transport_int_delays ${work}.${tb} $pargs
        }]
    }

    # Timing simulation
    if { $DO_SYN || $DO_CG } {
        ::kVutils::eval_cmd [subst {
            vsim $vsim_opt +delayed_timing_checks +ntc_warn -sdfmax ${dut}=${sdf} ${work}.${tb} $pargs
        }]
    }
}

#-----------------------------------------------------------------------------
# VERIFICATIONS
#-----------------------------------------------------------------------------
if { [file exists $mem] } {
    echo [format "MEMORY CONTENTS\n%s" [::kVsim::read_memdump $mem]]
}
