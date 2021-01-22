#-----------------------------------------------------------------------------
# Project : KeyV
# File    : sdf.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-27 Thu>
# Brief   : Generate SDF file from Prime Time
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh && cd synthesis
# [tcsh]% pt -f ../scripts/sdf.tcl -x "set DESIGN <design>; set STEP <STEP>"
#-----------------------------------------------------------------------------
source $::env(KEYV_SCRIPTS)/init_tsmc65.tcl

#----------------------------------------------------------------------------
# PARAMETERS
#----------------------------------------------------------------------------
global DESIGN
global SCRIPTS_D
global REP_D
global NET_D
global SAV_D
global OPCOND

if { ![info exists STEP] } {
    set STEP syn
}
if { $STEP != "syn" && $STEP != "cg" } {
    error "Wrong STEP ($STEP), should be 'syn' or 'cg'"
}

#----------------------------------------------------------------------------
# LOAD DESIGN
#----------------------------------------------------------------------------
read_ddc ${SAV_D}/${DESIGN}.${STEP}.ddc
set_operating_conditions -max $OPCOND -min $OPCOND

#----------------------------------------------------------------------------
# SAVE SDF
#----------------------------------------------------------------------------
if { $STEP == "syn" } {
    puts [::kVutils::format_title "POST-SYNTHESIS SDF"]

    if { $DESIGN == "synv" } {
        ::kVsyn::save_design -sdf -pt -dir $NET_D -name ${DESIGN}.syn
    }
    if { $DESIGN == "keyv" } {
        ::kVsyn::save_design -sdf -pt -dir $NET_D -name ${DESIGN}.syn \
            -options {-exclude_cells [find cell u_cycle_sync/*_reg*]}
    }
}
if { $STEP == "cg" } {
    puts [::kVutils::format_title "POST-CG SDF"]

    ::kVsyn::save_design -sdf -pt -dir $NET_D -name ${DESIGN}.cg \
        -options {-exclude_cells [find -hierarchy cell *clk_gate*]}
}
