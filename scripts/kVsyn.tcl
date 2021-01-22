#-----------------------------------------------------------------------------
# Project : KeyV
# File    : kVsyn.tcl
# Authors : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-03-13 Fri>
# Brief   : Package containing procedures to be used with Synopsys Tools
#-----------------------------------------------------------------------------
package provide kVsyn 1.0
package require Tcl 8.6
package require kVutils

namespace eval ::kVsyn {

    namespace export *
}

#-----------------------------------------------------------------------------
# SAVE_DESIGN
#
#    Saves a design NETLIST | SDF | DDC
#-----------------------------------------------------------------------------
proc ::kVsyn::save_design args {

    parse_proc_arguments -args $args params

    set dir $params(-dir)
    set basename $params(-name)
    set options  ""
    if { [llength [array names params -exact -options]] > 0 } {
        set options $params(-options)
    }
    if { ![file isdirectory $dir] } {
        error "Dirctory $dir not found"
    }
    set date [clock format [clock seconds] -format %y%m%d%H]

    # NETLIST
    if { [llength [array names params -exact -netlist]] > 0 } {
        set link ${dir}/${basename}.v
        set full ${dir}/${basename}.${date}.v
        set cmd "write_file -format verilog -hierarchy $options -output $full"
    }

    # DDC
    if { [llength [array names params -exact -ddc]] > 0 } {
        set link ${dir}/${basename}.ddc
        set full ${dir}/${basename}.${date}.ddc
        set cmd "write_file -format ddc -hierarchy $options -output $full"
    }

    # SDF
    if { [llength [array names params -exact -sdf]] > 0 } {
        set link ${dir}/${basename}.sdf
        if { [llength [array names params -exact -dc]] > 0 } {
            set full ${dir}/${basename}.dc.${date}.sdf
            set cmd "write_sdf $options $full"
        }
        if { [llength [array names params -exact -pt]] > 0 } {
            set full ${dir}/${basename}.pt.${date}.sdf
            set cmd "write_sdf -version 3.0 -include RECREM $options $full"
        }
    }

    # SDC
    if { [llength [array names params -exact -sdc]] > 0 } {
        set link ${dir}/${basename}.sdc
        set full ${dir}/${basename}.${date}.sdc
        set cmd "write_sdc $full"
    }

    uplevel #0 $cmd

    # Using hard link instead of symlink to allow uploading the file to git repo
    file delete -force $link
    file link -hard $link $full
}
define_proc_attributes ::kVsyn::save_design \
    -info "Saves a design NETLIST | SDF | DDC" \
    -define_args {
        {-dc       "Using DC"                 "" boolean required}
        {-pt       "Using PrimeTime"          "" boolean required}
        {-netlist  "Save the verilog netlist" "" boolean required}
        {-sdf      "Save the SDF file"        "" boolean required}
        {-sdc      "Save the SDC constraints" "" boolean required}
        {-ddc      "Save the ddc database"    "" boolean required}
        {-dir      "Destination directory" <directory> string required}
        {-name     "Base name of the file" <basename>  string required}
        {-options  "Additional options"    <options>   string optional}
    } \
    -define_arg_groups {
        {exclusive {-netlist -ddc -sdf -sdc}}
        {exclusive {-pt -dc}}
        {together  {-dir -name}}
    }

#-----------------------------------------------------------------------------
# SAVE_REPORT
#
#    Save reports: STA | AREA | CLOCK | CLOCK GATE | POWER
#-----------------------------------------------------------------------------
proc ::kVsyn::save_report args {

    parse_proc_arguments -args $args params

    set top $params(-top)
    set dir $params(-dir)
    set basename $params(-name)
    set options  ""
    if { [llength [array names params -exact -options]] > 0 } {
        set options $params(-options)
    }
    if { ![file isdirectory $dir] } {
        error "$dir is not a directory"
    }

    set date [clock format [clock seconds] -format %y%m%d%H]
    set link ${dir}/${basename}.rpt
    set full ${dir}/${basename}.${date}.rpt

    # STA
    if { [llength [array names params -exact -sta]] > 0 } {
        puts "\[STA\] $full"
        if { $top == "keyv" } {
            ::kVsyn::keyv_report_timing $full
        }
        if { $top == "synv" } {
            ::kVsyn::synv_report_timing $full
        }
    }

    # CLOCK
    if { [llength [array names params -exact -clock]] > 0 } {
        puts "\[CLOCK\] $full"
        if { $top == "keyv" } {
            ::kVsyn::keyv_report_clocks $full
        }
        if { $top == "synv" } {
            ::kVsyn::synv_report_clocks $full
        }
    }

    # CLOCK GATE
    if { [llength [array names params -exact -cg]] > 0 } {
        puts "\[CG\] $full"
        redirect $full {
            report_clock_gating -structure
        }
    }

    # AREA
    if { [llength [array names params -exact -area]] > 0 } {
        puts "\[AREA\] $full"
        redirect $full {
            report_area -hierarchy
            report_cell
        }
    }

    # POWER
    if { [llength [array names params -exact -pwr]] > 0 } {
        puts "\[POWER\] $full"
        redirect $full {
            report_power
            report_power -hierarchy
        }
    }

    # Using hard link instead of symlink to allow uploading the file to git repo
    file delete -force $link
    file link -hard $link $full
}
define_proc_attributes ::kVsyn::save_report \
    -info "Save reports STA | AREA | CLOCKS" \
    -define_args {
        {-sta      "Static Timing Analysis"      "" boolean required}
        {-area     "Area & modules reports"      "" boolean required}
        {-clock    "Clocks & clock tree reports" "" boolean required}
        {-cg       "Clock-gating reports"        "" boolean required}
        {-pwr      "Clock-gating reports"        "" boolean required}
        {-top      "Top-level design" <top> one_of_string {required value_help {values {keyv synv}}}}
        {-dir      "Destination directory"   <directory> string required}
        {-name     "Base name of the report" <basename>  string required}
        {-options  "Additional options"      <options>   string optional}
    } \
    -define_arg_groups {
        {exclusive {-sta -area -clock -cg -pwr}}
        {together  {-sta -top}}
    }


#-----------------------------------------------------------------------------
# GET_SLACK
#
#    Returns the worst case slack value of current design
#-----------------------------------------------------------------------------
proc ::kVsyn::get_slack args {

    parse_proc_arguments -args $args params

    set options ""

    if { [llength [array names params -exact -options]] > 0 } {
        set options $params(-options)
    }
    if { [llength [array names params -exact -from]] > 0 } {
        append options [subst -nobackslashes -nocommands { -from [get_clock $params(-from)]}]
    }
    if { [llength [array names params -exact -to]] > 0 } {
        append options [subst -nobackslashes -nocommands { -to [get_clock $params(-to)]}]
    }
    if { [llength [array names params -exact -setup]] > 0 } {
        set type max
    }
    if { [llength [array names params -exact -hold]] > 0 } {
        set type min
    }

    redirect -variable timing "report_timing -sort_by slack -nosplit -delay_type $type $options"

    if { [regexp {(slack\s+\(\w+.*\)\s+)(-?[0-9]+\.[0-9]+)} $timing all tmp slack] } {
        return $slack
    } else {
        return -1
    }

}
define_proc_attributes ::kVsyn::get_slack \
    -info "Returns the worst case slack value of current design" \
    -define_args {
        {-setup    "Max path analysis" ""    boolean required}
        {-hold     "Min path analysis" ""    boolean required}
        {-from     "Launch clock"      <clk> string  optional}
        {-to       "Capture clock"     <clk> string  optional}
        {-options  "Additionnal options passed to report_timing" <options> string  optional}
    } \
    -define_arg_groups {
        {exclusive {-setup -hold}}
    }

#-----------------------------------------------------------------------------
# SIZE_PULSE_WIDTH
#
#    Change the standard cells of the pulse-width delay elements
#-----------------------------------------------------------------------------
proc ::kVsyn::size_pulse_width args {

    parse_proc_arguments -args $args params

    set cell [get_lib_cells -quiet tcbn65gpluswc_ccs/$params(-cell)]
    if { [sizeof_collection $cell] <= 0 } {
        error "$params(-cell) not found in library "
    }

    size_cell [get_cells u_keyring/u_click_*/u_pulsew_*/u_gate] $cell
    update_timing
}
define_proc_attributes ::kVsyn::size_pulse_width \
    -info "Change the standard cells of the pulse-width delay elements" \
    -define_args {
        {-cell "Standard cell to use" <cell> one_of_string {required value_help {values {CKBD0 CKBD8 DEL005 DEL0 DEL1}}}}
    }

#-----------------------------------------------------------------------------
# KEYV_REPORT_TIMING
#
#    Run timing analysis for the KeyV processor, and save to <rpt>
#    Min/Max timing analysys for each setup/hold capture clock
#-----------------------------------------------------------------------------
proc ::kVsyn::keyv_report_timing { rpt } {

    global kMain
    global kMul

    #-------------------------------------------------------------------------
    # HEADER
    #-------------------------------------------------------------------------
    set head   [subst "| %-35s | %-35s | %-6s | %-6s | %-10s |"]
    set header [format $head "From" "To" "Delay" "Slack" "Period"]
    set sep    [string repeat - [string length $header]]
    ::kVutils::file_init $rpt
    ::kVutils::file_write $rpt "$sep\n$header\n$sep"

    #-------------------------------------------------------------------------
    # Update timing information
    #-------------------------------------------------------------------------
    $kMain update_timing_information
    $kMul update_timing_information

    #-------------------------------------------------------------------------
    # Setup
    #-------------------------------------------------------------------------

    # Main
    foreach click [$kMain get_clicks] {

        set launch_left  [$kMain get_clock_name $click -launch -left]
        set capture_left [$kMain get_clock_name $click -capture -left]
        set launch_up    [$kMain get_clock_name $click -launch -up]
        set capture_up   [$kMain get_clock_name $click -capture -up]

        ::kVutils::file_write $rpt \
            [format $head $launch_left $capture_left \
                 [$kMain get_de_delay -from $launch_left -to $capture_left -max] \
                 [$kMain get_slack -from $launch_left -to $capture_left -max]    \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_left $capture_up \
                 [$kMain get_de_delay -from $launch_left -to $capture_up -max] \
                 [$kMain get_slack -from $launch_left -to $capture_up -max]    \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_up $capture_up \
                 [$kMain get_de_delay -from $launch_up -to $capture_up -max] \
                 [$kMain get_slack -from $launch_up -to $capture_up -max]    \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_up $capture_left \
                 [$kMain get_de_delay -from $launch_up -to $capture_left -max] \
                 [$kMain get_slack -from $launch_up -to $capture_left -max]    \
                 [$kMain get_period $click]]
    }
    ::kVutils::file_write $rpt $sep

    # Mul
    foreach click [$kMul get_clicks] {

        set launch  [$kMul get_clock_name $click -launch -left]
        set capture [$kMul get_clock_name $click -capture -left]

        ::kVutils::file_write $rpt \
            [format $head $launch $capture \
                 [$kMul get_de_delay -from $launch -to $capture -max] \
                 [$kMul get_slack -from $launch -to $capture -max]    \
                 [get_attribute [get_clock $capture] period]]
    }
    ::kVutils::file_write $rpt $sep

    # Mulsync
    for {set e 0} {$e < [$kMain get_eus]} {incr e} {
        set launch  [get_clocks C_mulsync_${e}_start_setup_launch]
        set capture [get_clocks C_mulsync_${e}_start_setup_capture]
        ::kVutils::file_write $rpt \
            [format $head [get_attribute $launch name] [get_attribute $capture name]  \
                 -1 [::kVsyn::get_slack -setup -from $launch -to $capture] \
                 [get_attribute $capture period]]
    }
    for {set e 0} {$e < [$kMain get_eus]} {incr e} {
        set launch  [get_clocks C_mulsync_${e}_stop_setup_launch]
        set capture [get_clocks C_mulsync_${e}_stop_setup_capture]
        ::kVutils::file_write $rpt \
            [format $head [get_attribute $launch name] [get_attribute $capture name]  \
                 -1 [::kVsyn::get_slack -setup -from $launch -to $capture] \
                 [get_attribute $capture period]]
    }
    ::kVutils::file_write $rpt $sep

    # Perf
    ::kVutils::file_write $rpt \
        [format $head C_perf C_perf -1 \
             [::kVsyn::get_slack -setup -from C_perf -to C_perf] \
             [get_attribute [get_clock C_perf] period]]

    #--------------------------------------------------------------------------
    # Hold
    #--------------------------------------------------------------------------
    ::kVutils::file_write $rpt $sep

    # Main
    foreach click [$kMain get_clicks] {

        set launch_right  [$kMain get_clock_name $click -launch -right]
        set capture_right [$kMain get_clock_name $click -capture -right]
        set launch_down   [$kMain get_clock_name $click -launch -down]
        set capture_down  [$kMain get_clock_name $click -capture -down]
        set alter_down    [$kMain get_clock_name $click -capture -alter_down]
        set alter_right   [$kMain get_clock_name $click -capture -alter_right]

        ::kVutils::file_write $rpt \
            [format $head $launch_right $capture_right \
                 [$kMain get_de_delay -from $launch_right -to $capture_right -min] \
                 [$kMain get_slack -from $launch_right -to $capture_right -min]    \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_down $capture_down \
                 [$kMain get_de_delay -from $launch_down -to $capture_down -min] \
                 [$kMain get_slack -from $launch_down -to $capture_down -min]   \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_right $alter_right \
                 [$kMain get_de_delay -from $launch_right -to $alter_right -min] \
                 [$kMain get_slack -from $launch_right -to $alter_right -min]   \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_down $alter_down \
                 [$kMain get_de_delay -from $launch_down -to $alter_down -min] \
                 [$kMain get_slack -from $launch_down -to $alter_down -min]   \
                 [$kMain get_period $click]]

    }
    ::kVutils::file_write $rpt $sep

    # XBS Sel
    foreach click [$kMain get_clicks] {

        set clksel [$kMain get_clock_name $click -root -sel]

        ::kVutils::file_write $rpt \
            [format $head  $clksel $clksel -1 \
                 [::kVsyn::get_slack -hold -from $clksel -to $clksel] \
                 [get_attribute [get_clock $clksel] period]]
    }
    ::kVutils::file_write $rpt $sep

    # Mul
    foreach click [$kMul get_clicks] {

        set launch  [$kMul get_clock_name $click -launch -down]
        set capture [$kMul get_clock_name $click -capture -down]

        ::kVutils::file_write $rpt \
            [format $head $launch $capture \
                 [$kMul get_de_delay -from $launch -to $capture -min] \
                 [$kMul get_slack -from $launch -to $capture -min]    \
                 [get_attribute [get_clock $capture] period]]
    }
    ::kVutils::file_write $rpt $sep

    # Perf
    ::kVutils::file_write $rpt \
        [format $head C_perf C_perf -1 \
             [::kVsyn::get_slack -hold -from C_perf -to C_perf] \
             [get_attribute [get_clock C_perf] period]]

    #--------------------------------------------------------------------------
    # Details
    #--------------------------------------------------------------------------
    ::kVutils::file_write $rpt $sep

    # Main
    foreach click [$kMain get_clicks] {
        foreach_in_collection l [get_clocks ${click}_setup_* -filter "full_name=~*_launch"] {
            foreach_in_collection c [get_clocks ${click}_setup_* -filter "full_name=~*_capture"] {
                redirect -append $rpt {
                    report_timing -path_type full_clock_expanded -delay_type max -from $l -to $c
                }
            }
        }
        foreach_in_collection l [get_clocks ${click}_hold_* -filter "full_name=~*_launch"] {
            foreach_in_collection c [get_clocks ${click}_hold_* -filter "full_name=~*_capture"] {
                redirect -append $rpt {
                    report_timing -path_type full_clock_expanded -delay_type min -from $l -to $c
                }
            }
        }
    }

    # Mul
    foreach click [$kMul get_clicks] {
        foreach_in_collection l [get_clocks ${click}_setup_* -filter "full_name=~*_launch"] {
            foreach_in_collection c [get_clocks ${click}_setup_* -filter "full_name=~*_capture"] {
                redirect -append $rpt {
                    report_timing -path_type full_clock_expanded -delay_type max -from $l -to $c
                }
            }
        }
        foreach_in_collection l [get_clocks ${click}_hold_* -filter "full_name=~*_launch"] {
            foreach_in_collection c [get_clocks ${click}_hold_* -filter "full_name=~*_capture"] {
                redirect -append $rpt {
                    report_timing -path_type full_clock_expanded -delay_type min -from $l -to $c
                }
            }
        }
    }

    # Mulsync
    foreach_in_collection capture [get_clocks C_mulsync_* -filter "full_name=~*setup_capture"] {
        redirect -append $rpt {
            report_timing -path_type full_clock_expanded -delay_type max -to $capture
        }
    }

    # XBS Sel
    foreach click [$kMain get_clicks] {
        redirect -append $rpt {
            report_timing -delay_type min -to [get_clocks ${click}_sel]
        }
    }

    # Perf
    redirect -append $rpt {
        report_timing -delay_type max -to C_perf
        report_timing -delay_type min -to C_perf
    }
}

#-----------------------------------------------------------------------------
# SYNV_REPORT_TIMING
#
#    Run timing analysis for the SynV processor, and save to <rpt>
#-----------------------------------------------------------------------------
proc ::kVsyn::synv_report_timing { rpt } {

    redirect $rpt {
        report_timing -delay_type max -to [get_clock synv_clk]
        report_timing -delay_type min -to [get_clock synv_clk]
    }
}

#-----------------------------------------------------------------------------
# KEYV_REPORT_CLOCKS
#
#    Run clock reports for the KeyV processor, and save to <rpt>
#-----------------------------------------------------------------------------
proc ::kVsyn::keyv_report_clocks { rpt } {

    redirect $rpt {
        report_clocks
        report_clock_tree -summary
        report_clock_timing -type latency -max -capture -setup -clock [get_clock *_setup_*_capture]
        report_clock_timing -type latency -min -capture -hold -clock [get_clock *_hold_*_capture]
        report_transitive_fanout -clock_tree
    }
}

#-----------------------------------------------------------------------------
# SYNV_REPORT_CLOCKS
#
#    Run clock reports for the SynV processor, and save to <rpt>
#-----------------------------------------------------------------------------
proc ::kVsyn::synv_report_clocks { rpt } {

    redirect $rpt {
        report_clocks
        report_clock_tree -summary
        report_clock_timing -type latency -max -capture -setup -clock [get_clock synv_clk]
        report_clock_timing -type latency -min -capture -hold -clock [get_clock synv_clk]
        report_transitive_fanout -clock_tree
    }
}

#------------------------------------------------------------------------------
# KEYV_GENERATE_INTER_KEYRING_CLOCKS
#
#    kMul is enabled by mul/div enable signals coming from EUs @R_clks
#    The enable signal of kMul is connected to the stall input of the click;
#    It is delayed through another DE, matching the Init path of the mul/div units
#    Hold violations are handled architecturally
#------------------------------------------------------------------------------
proc ::kVsyn::keyv_generate_inter_keyring_clocks args {

    global kMain
    global kMul

    set mul_start_pin [get_pins u_keyring/i_keyring\[M_START\]]
    set mul_stop_pin  [get_pins u_keyring/i_keyring\[M_STOP\]]
    set mul_stop_Q    [get_pins u_keyring/m_stop_reg/Q]
    set mul_start_Q   [get_pins u_keyring/m_start_reg/Q]
    set mul_stall_pin [get_pins u_keyring/u_click_m/i_click\[STALL\]]

    # CLOCKS
    for {set e 0} {$e < [$kMain get_eus]} {incr e} {

        set click_mul [$kMul get_click_by_index 0 0]
        set click_R   [$kMain get_click_by_index $e 2]
        set click_E   [$kMain get_click_by_index $e 3]

        # Start Clk
        create_generated_clock -name C_mulsync_${e}_start_clk \
            -edges {1 3 5} -master_clock [get_clock [$kMain get_clock_name $click_R -root -clk]] \
            -source [$kMain get_endpoint $click_R -clkb] \
            -add [get_pins $mul_start_pin]

        # Start Key
        create_generated_clock -name C_mulsync_${e}_start_key \
            -edges {1 3 5} -master_clock [get_clock C_mulsync_${e}_start_clk] \
            -source [get_pins $mul_start_pin] \
            -add [get_pins $mul_start_Q]

        # Start Setup Launch
        create_generated_clock -name C_mulsync_${e}_start_setup_launch \
            -edges {1 5 9} -master_clock [get_clock [$kMain get_clock_name $click_R -root -clk]] \
            -source [$kMain get_endpoint $click_R -clkb] \
            -add [$kMain get_endpoint $click_R -clkb]

        # Start Setup Capture
        create_generated_clock -name C_mulsync_${e}_start_setup_capture \
            -combinational -master_clock [get_clock C_mulsync_${e}_start_key] \
            -source [get_pins $mul_start_Q] \
            -add [$kMul get_endpoint $click_mul -clkb]

        # Stop Clk
        create_generated_clock -name C_mulsync_${e}_stop_clk \
            -edges {1 3 5} -master_clock [get_clock [$kMul get_clock_name $click_mul -root -clk]] \
            -source [$kMul get_endpoint $click_mul -clkb] \
            -add [get_pins $mul_stop_pin]

        # Stop Key
        create_generated_clock -name C_mulsync_${e}_stop_key \
            -edges {1 3 5} -master_clock [get_clock C_mulsync_${e}_stop_clk] \
            -source [get_pins $mul_stop_pin] \
            -add [get_pins $mul_stop_Q]

        # Stop Setup Launch
        create_generated_clock -name C_mulsync_${e}_stop_setup_launch \
            -edges {1 5 9} -master_clock [get_clock [$kMul get_clock_name $click_mul -root -clk]] \
            -source [$kMul get_endpoint $click_mul -clkb] \
            -add [$kMul get_endpoint $click_mul -clkb]

        # Stop Setup Capture
        create_generated_clock -name C_mulsync_${e}_stop_setup_capture \
            -combinational -master_clock [get_clock C_mulsync_${e}_stop_key] \
            -source [get_pins $mul_stop_Q] \
            -add [$kMain get_endpoint $click_E -clkb]
    }

    # MARGINS
    foreach_in_collection launch [get_clocks C_mulsync_*_setup_launch] {
        foreach_in_collection capture [get_clocks C_mulsync_*_setup_capture] {
            set_clock_uncertainty -setup -from $launch -to $capture [$kMain get_margin $click_E -setup]
        }
    }

    # DE CONFIGURATIONS (same as kMul)
    set b 0
    foreach_in_collection pin [get_pins u_keyring/u_dcdl_m_start/u_ckmx*/u_gate/S] {
        set_case_analysis [string index [$kMul get_dl $click_mul -opcode] $b] [get_pin $pin]
        incr b
    }
    set b 0
    foreach_in_collection pin [get_pins u_keyring/u_dcdl_m_stop/u_ckmx*/u_gate/S] {
        set_case_analysis [string index [$kMul get_dl $click_mul -opcode] $b] [get_pin $pin]
        incr b
    }

    set_propagated_clock [get_clocks C_mulsync_*]
    update_timing
}

#------------------------------------------------------------------------------
# KEYV_CREATE_PERF_CLOCKS
#
#   Synchronous clock used for the performance counter.
#   Interfaced with M_clks through CDC sync module (sync)
#------------------------------------------------------------------------------
proc ::kVsyn::keyv_create_perf_clocks args {

    parse_proc_arguments -args $args params
    upvar 1 $params(-margins) margins

    create_clock -name C_perf -period $params(-period) -add [get_ports i_clk]
    set_clock_uncertainty -setup -from [get_clocks C_perf] -to [get_clocks C_perf] $margins(setup)
    set_clock_uncertainty -hold  -from [get_clocks C_perf] -to [get_clocks C_perf] $margins(hold)

    set_propagated_clock [get_clocks C_perf]
    update_timing
}
define_proc_attributes ::kVsyn::keyv_create_perf_clocks \
    -info "Synchronous clock used for the performance counter." \
    -define_args {
        {-period  "Clock period" <T> string required}
        {-margins "Margins array [setup, hold]" <margins> string required}
    }

#------------------------------------------------------------------------------
# KEYV_EXCEPTIONS
#
#    Define asynchronous clock groups
#    Defined in a procedure to facilitate clock groups update (remove+set)
#------------------------------------------------------------------------------
proc ::kVsyn::keyv_exceptions args {

    global kMain
    global kMul

    #######################
    # ASYNCHRONOUS GROUPS #
    #######################
    remove_clock_groups -asynchronous -all

    set group_cmd [subst -nocommands -nobackslashes {set_clock_groups -asynchronous}]

    # kMain
    foreach click [$kMain get_clicks] {
        append group_cmd [subst -nocommands -nobackslashes \
                              { -group [get_clocks ${click}_* -filter "full_name !~ *sel"]}]
    }
    # kMul
    foreach click [$kMul get_clicks] {
        append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks ${click}_*]}]
    }
    # Mulsync
    for {set e 0} {$e < [$kMain get_eus]} {incr e} {
        append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks C_mulsync_${e}_start*]}]
        append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks C_mulsync_${e}_stop*]}]
    }
    # XBS Sel
    foreach click [$kMain get_clicks] {
        append group_cmd [subst -nocommands -nobackslashes \
                              { -group [get_clocks ${click}_* -filter "full_name =~ *sel"]}]
    }
    # Performance counters
    append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks C_perf]}]

    uplevel #0 $group_cmd

    ###############
    # FALSE PATHS #
    ###############

    # Root clocks are not used for timing analysis
    set_false_path -from [get_clocks *_key]
    set_false_path -to   [get_clocks *_key]
    set_false_path -from [get_clocks *_clk]
    set_false_path -to   [get_clocks *_clk]

    # Launch/Capture clocks do not capture/launch timing paths
    set_false_path -to [get_clocks *_launch]
    set_false_path -from [get_clocks *_capture]

    # Launch/Capture paths are either rise/rise or fall/fall
    set_false_path -rise_from [get_clocks *_launch] -fall_to [get_clocks *_capture]
    set_false_path -fall_from [get_clocks *_launch] -rise_to [get_clocks *_capture]

    # Hold clocks are not used for setup analysis
    set_false_path -setup -from [get_clocks *_hold_*]
    set_false_path -setup -to [get_clocks *_hold_*]

    # Setup clocks are not used for hold analysis
    set_false_path -hold -from [get_clocks *_setup_*]
    set_false_path -hold -to [get_clocks *_setup_*]

    # Selection signals must be constrained for hold only
    set_false_path -setup -from [get_clocks *_sel]
    set_false_path -setup -to [get_clocks *_sel]

    ####################
    # ZERO CYCLE PATHS #
    ####################
    set_multicycle_path 0 -setup -from [get_clock *_setup_*launch] -to [get_clock *_setup_*capture]
    set_multicycle_path 0 -hold -from [get_clock *_hold_*launch] -to [get_clock *_hold_*capture]

    update_timing
}

#------------------------------------------------------------------------------
# KEYV_ADD_ALTER_HOLD_MARGIN
#
#    Add margin to the inter-clock hold constraint
#    It assumes the worst case scenario whereby the capture clock is late
#------------------------------------------------------------------------------
proc ::kVsyn::keyv_update_alter_hold_margin args {

    global kMain
    parse_proc_arguments -args $args params

    # Check list of click provided
    set click_list [$kMain get_clicks]
    foreach click $params(-clicks) {
        if { [lsearch -exact $click_list $click] < 0 } {
            error "$click not found"
        }
    }

    foreach click $params(-clicks) {

        set click_left  [$kMain get_parent $click -left]
        set click_up    [$kMain get_parent $click -up]

        # Alter Hold Down Capture
        create_generated_clock -name  [$kMain get_clock_name $click -capture -alter_down] \
            -edges {1 2 3} -edge_shift [list $params(-margin) $params(-margin) $params(-margin)] \
            -master_clock [get_clock [$kMain get_clock_name $click_up -root -key]] \
            -source [$kMain get_endpoint $click_up -keyb_c] \
            -add [$kMain get_endpoint $click -clkb]

        # Alter Hold Right Capture
        create_generated_clock -name [$kMain get_clock_name $click -capture -alter_right] \
            -edges {1 2 3} -edge_shift [list $params(-margin) $params(-margin) $params(-margin)] \
            -master_clock [get_clock [$kMain get_clock_name $click_left -root -key]] \
            -source [$kMain get_endpoint $click_left -keyb_c] \
            -add [$kMain get_endpoint $click -clkb]
    }
    set_propagated_clock [get_clocks *_alter_*]
    set_fix_hold [get_clocks *_alter_*]
    update_timing

    # Replace inter-clock constraints by alter-hold constraints with added margins
    set_false_path -hold -from [get_clocks *_hold_down_launch] -to [get_clocks *_hold_right_capture]
    set_false_path -hold -from [get_clocks *_hold_right_launch] -to [get_clocks *_hold_down_capture]
    set_false_path -hold -from [get_clocks *_hold_down_launch] -to [get_clocks *_alter_right_capture]
    set_false_path -hold -from [get_clocks *_hold_right_launch] -to [get_clocks *_alter_down_capture]
    set_multicycle_path -1 -hold -from [get_clock *_hold_*_launch] -to [get_clock *_alter_*_capture]

    # Update exceptions
    ::kVsyn::keyv_exceptions
}
define_proc_attributes ::kVsyn::keyv_update_alter_hold_margin \
    -info "Add margin to the inter-clock hold constraint" \
    -define_args {
        {-clicks   "List of clicks"    <c>   list   required}
        {-margin   "Hold margin"       <m>   string required}
    }
