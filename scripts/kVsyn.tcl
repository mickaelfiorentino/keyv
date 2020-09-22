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

    namespace export save_* report_* get_*
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
    set head   [subst "| %-32s | %-32s | %-6s | %-6s | %-10s |"]
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
            [format $head $launch_up $capture_left \
                 [$kMain get_de_delay -from $launch_up -to $capture_left -max] \
                 [$kMain get_slack -from $launch_up -to $capture_left -max]    \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_up $capture_up \
                 [$kMain get_de_delay -from $launch_up -to $capture_up -max] \
                 [$kMain get_slack -from $launch_up -to $capture_up -max]    \
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

        ::kVutils::file_write $rpt \
            [format $head $launch_right $capture_right \
                 [$kMain get_de_delay -from $launch_right -to $capture_right -min] \
                 [$kMain get_slack -from $launch_right -to $capture_right -min]    \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_right $capture_down \
                 [$kMain get_de_delay -from $launch_right -to $capture_down -min] \
                 [$kMain get_slack -from $launch_right -to $capture_down -min]   \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_down $capture_right \
                 [$kMain get_de_delay -from $launch_down -to $capture_right -min] \
                 [$kMain get_slack -from $launch_down -to $capture_right -min]   \
                 [$kMain get_period $click]]

        ::kVutils::file_write $rpt \
            [format $head $launch_down $capture_down \
                 [$kMain get_de_delay -from $launch_down -to $capture_down -min] \
                 [$kMain get_slack -from $launch_down -to $capture_down -min]   \
                 [$kMain get_period $click]]
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
