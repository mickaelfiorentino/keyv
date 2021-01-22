#-----------------------------------------------------------------------------
# Project : KeyV
# File    : init_tsmc65.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-27 Thu>
# Brief   : Synopsys initialization script for TSMC65 kit
#-----------------------------------------------------------------------------
package require Tcl 8.6

#-----------------------------------------------------------------------------
# Setup
#-----------------------------------------------------------------------------
if { ![info exist ::env(KEYV_HOME)] } {
    error "Setup the environment with setup.csh prior to running this script"
}
if { ![file exists .synopsys_dc.setup] } {
    error ".synopsys_dc.setup is missing. Make sure to run the script from $::env(KEYV_SYN)"
}

global auto_path
if { [lsearch ${auto_path} $::env(KEYV_SCRIPTS)] < 0 } {
    lappend auto_path $::env(KEYV_SCRIPTS)
}
package require kVutils
package require kVsyn

#-----------------------------------------------------------------------------
# PARAMETERS
#-----------------------------------------------------------------------------
global DESIGN
if { ![info exists DESIGN] } {
    set DESIGN keyv
}
if { $DESIGN != "keyv" && $DESIGN != "synv" } {
    error "Unsopported design: $DESIGN"
}

set TOP              core
set LIB              work
set LIB_D            ${DESIGN}/${LIB}
set HDL_D            $::env(KEYV_SRC)
set SCRIPTS_D        $::env(KEYV_SCRIPTS)
set REP_D            $::env(KEYV_SYN)/${DESIGN}/$::env(KEYV_SYN_REP)
set NET_D            $::env(KEYV_SYN)/${DESIGN}/$::env(KEYV_SYN_NET)
set SAV_D            $::env(KEYV_SYN)/${DESIGN}/$::env(KEYV_SYN_SAV)
set SIM_D            $::env(KEYV_SIM)/${DESIGN}
set DESIGN_SRC       ${HDL_D}/${DESIGN}.src
set TIMING_LIB_D     $::env(KEYV_TSMC65GP_FE_TIM_LIB)
set TIMING_LIB       tcbn65gplustc_ccs; # tcbn65gplusbc_ccs tcbn65gpluswc_ccs
set OPCOND           NCCOM; # WCCOM BCCOM
set CELLS_IO_CELL    DFCND1
set CELLS_IO_DRIVE   Q
set CELLS_IO_LOAD    D
set CELLS_CK_CELL    CKBD1

#-----------------------------------------------------------------------------
# INIT
#-----------------------------------------------------------------------------
set_host_options -max_cores       16
set_app_var sh_continue_on_error  false
set_app_var search_path           [list . $HDL_D $TIMING_LIB_D]
set_app_var target_library        [list ${TIMING_LIB}.db]
set_app_var link_library          [list * ${TIMING_LIB}.db]
