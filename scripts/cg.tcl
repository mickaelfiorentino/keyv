#-----------------------------------------------------------------------------
# Project : KeyV
# File    : cg.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-27 Thu>
# Brief   : Synthesis script
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh && cd synthesis
# [tcsh]% dv -f ../scripts/cg.tcl -x "set DESIGN <design>"
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# INIT
#-----------------------------------------------------------------------------
if { ![list_designs] } {
    source $::env(KEYV_SCRIPTS)/init_tsmc65.tcl

    global DESIGN
    global LIB
    global LIB_D
    global SCRIPTS_D
    global REP_D
    global NET_D
    global SAV_D

    set DO_HOLD 1
    set DO_SAVE 1

    define_design_lib ${LIB}_cg -path ${LIB_D}_cg
    read_ddc ${SAV_D}/${DESIGN}.syn.ddc
    read_sdc ${SAV_D}/${DESIGN}.sdc
}

#-----------------------------------------------------------------------------
# COMPILE
#-----------------------------------------------------------------------------
set_clock_gating_style -sequential_cell latch -max_fanout 32 -minimum_bitwidth 4
compile -incremental_mapping -gate_clock

propagate_constraints -gate_clock

if { $DO_HOLD } {
    set_fix_hold [all_clocks]
    set_app_var timing_disable_recovery_removal_checks false
    set_app_var enable_recovery_removal_arcs true
}

compile -incremental_mapping
update_timing

#-----------------------------------------------------------------------------
# SAVE & REPORTS
#-----------------------------------------------------------------------------
if { $DO_SAVE } {
    ::kVsyn::save_report -area  -top $DESIGN -dir $REP_D -name ${DESIGN}.cg.area
    ::kVsyn::save_report -clock -top $DESIGN -dir $REP_D -name ${DESIGN}.cg.clock
    ::kVsyn::save_report -cg    -top $DESIGN -dir $REP_D -name ${DESIGN}.cg.clk_gate
    ::kVsyn::save_report -sta   -top $DESIGN -dir $REP_D -name ${DESIGN}.cg.timing
    ::kVsyn::save_design -netlist -dc -dir $NET_D -name ${DESIGN}.cg
    ::kVsyn::save_design -ddc -dc -dir $SAV_D -name ${DESIGN}.cg
}
