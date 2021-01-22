#-----------------------------------------------------------------------------
# Project : KeyV
# File    : pwr.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-04-22 Wed>
# Brief   : Power analysis from Prime Time
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh && cd synthesis
# [tcsh]% pt -f ../scripts/pwr.tcl -x "set DESIGN <design>; set STEP <STEP>; set BENCH <BENCH>"
#-----------------------------------------------------------------------------
source $::env(KEYV_SCRIPTS)/init_tsmc65.tcl

#----------------------------------------------------------------------------
# PARAMETERS
#----------------------------------------------------------------------------
global DESIGN
global SCRIPTS_D
global REP_D
global SAV_D
global SIM_D
global OPCOND
global CELLS_CK_CELL

# Defaults
if { ![info exists STEP]  } { set STEP  beh   }
if { ![info exists BENCH] } { set BENCH basic }

# Checks
set allowed_step  [list beh syn cg]
set allowed_bench [list basic fibo dhrystone coremark]

if { [lsearch $allowed_step $STEP] < 0 } {
    error "Wrong STEP ($STEP), should be $allowed_step"
}
if { [lsearch $allowed_bench $BENCH] < 0 } {
    error "Wrong BENCH ($BENCH), should be $allowed_bench"
}

set DUT tb/u_top/u_core

# Activity file
set SAIF ${SIM_D}/${STEP}/${BENCH}/${DESIGN}.${STEP}.${BENCH}.saif
if { ![file exists $SAIF] } {
    error "SAIF file $SAIF does not exist"
}

#----------------------------------------------------------------------------
# POWER REPORT
#----------------------------------------------------------------------------
set_app_var power_enable_analysis true
set_app_var power_clock_network_include_clock_gating_network true
set_app_var power_clock_network_include_register_clock_pin_power true

# Load Design
read_ddc ${SAV_D}/${DESIGN}.${STEP}.ddc
set_operating_conditions -max $OPCOND -min $OPCOND

# Read activity from benchmark
read_saif $SAIF -strip_path $DUT

# # Clock tree
# read_sdc ${SAV_D}/${DESIGN}.sdc
# estimate_clock_network_power [get_lib_cells ${TIMING_LIB}/${CELLS_CK_CELL}]

# Report power
::kVsyn::save_report -pwr -top $DESIGN -dir $REP_D -name ${DESIGN}.${STEP}.pwr.${BENCH}
