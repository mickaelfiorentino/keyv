#-----------------------------------------------------------------------------
# Project : KeyV
# File    : syn.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-27 Thu>
# Brief   : Synthesis script
#-----------------------------------------------------------------------------
# [tcsh]% source setup.csh && cd synthesis
# [tcsh]% dv -f ../scripts/syn.tcl -x "set DESIGN <design>"
#-----------------------------------------------------------------------------
package require Tcl 8.6

#-----------------------------------------------------------------------------
# Flow control
#-----------------------------------------------------------------------------
set DO_INIT     1;     # Init technology libraries & global synthesis parameters
set DO_ELAB     1;     # Compile sources & elaborate the design
set DO_SYN      1;     # Synthesis
set DO_HOLD     1;     # Incremental synthesis for hold violations fixing
set DO_SAVE     1;     # Save (netlist, ddc, reports)

#-----------------------------------------------------------------------------
# Init
#-----------------------------------------------------------------------------
if { $DO_INIT } {
    source $::env(KEYV_SCRIPTS)/init_tsmc65.tcl

    global DESIGN
    global TOP
    global LIB
    global LIB_D
    global HDL_D
    global SCRIPTS_D
    global REP_D
    global NET_D
    global SAV_D
    global SIM_D
    global DESIGN_SRC
    global TIMING_LIB_D
    global TIMING_LIB
    global OPCOND

    remove_design -all
    file delete -force $LIB_D
    define_design_lib $LIB -path $LIB_D
}

#-----------------------------------------------------------------------------
# Elaboration
#-----------------------------------------------------------------------------
if { $DO_ELAB } {
    puts [::kVutils::format_title "ELABORATION"]

    set_app_var hdlin_vhdl_std                  "2008"
    set_app_var hdlin_check_no_latch            "true"
    set_app_var hdlin_enable_configurations     "true"
    set_app_var hdlin_report_inferred_modules   "true"
    set_app_var hdlin_infer_multibit            "default_all"
    set_app_var hdlin_ff_always_sync_set_reset  "false"
    set_app_var enable_phys_lib_during_elab     "true"
    set_app_var compile_log_format " %elap_time %area %total_power %wns %max_delay %min_delay %endpoint"

    analyze -library $LIB -format vhdl [::kVutils::get_src $DESIGN_SRC "vhd"]

    elaborate -library $LIB $TOP
    uniquify -dont_skip_empty_designs

    # Constraints
    if { $DESIGN == "keyv" } {
        source ${SCRIPTS_D}/sdc_keyv.tcl
    }
    if { $DESIGN == "synv" } {
        source ${SCRIPTS_D}/sdc_synv.tcl
    }

    # Save
    if { $DO_SAVE } {
        ::kVsyn::save_design -dc -ddc -dir $SAV_D -name ${DESIGN}.elab
        ::kVsyn::save_design -dc -sdc -dir $SAV_D -name ${DESIGN}.elab
    }
}

#-----------------------------------------------------------------------------
# Synthesis
#-----------------------------------------------------------------------------
if { $DO_SYN } {
    puts [::kVutils::format_title "SYNTHESIS"]

    # Load elaborated design if not in memory
    if { ![list_designs] } {
        read_ddc ${SAV_D}/${DESIGN}.elab.ddc
        read_sdc ${SAV_D}/${DESIGN}.sdc
    }

    # Multiple port nets
    set_fix_multiple_port_nets -feedthroughs -outputs -constants -exclude_clock_network

    # Prioritise max delay optimizations
    set_cost_priority -delay

    # Synthesis
    compile
    update_timing

    # Min delay optimizations
    if { $DO_HOLD } {
        set_fix_hold [all_clocks]
        set_app_var timing_disable_recovery_removal_checks false
        set_app_var enable_recovery_removal_arcs true
        compile -incremental_mapping
        update_timing
    }

    # Save
    if { $DO_SAVE } {
        ::kVsyn::save_report -area  -top $DESIGN -dir $REP_D -name ${DESIGN}.syn.area
        ::kVsyn::save_report -clock -top $DESIGN -dir $REP_D -name ${DESIGN}.syn.clock
        ::kVsyn::save_report -sta   -top $DESIGN -dir $REP_D -name ${DESIGN}.syn.timing
        ::kVsyn::save_design -netlist -dc -dir $NET_D -name ${DESIGN}.syn
        ::kVsyn::save_design -ddc -dc -dir $SAV_D -name ${DESIGN}.syn
        ::kVsyn::save_design -sdc -dc -dir $SAV_D -name ${DESIGN}.syn
    }
}
