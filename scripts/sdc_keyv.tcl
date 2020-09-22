#------------------------------------------------------------------------------
# Project : KeyV
# File    : sdc_keyv.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-03-09 Mon>
# Brief   : KeyV timing constraints
#------------------------------------------------------------------------------
package require Tcl 8.6
package require kVutils
package require kVsyn

global SCRIPTS_D
global OPERATING_CONDITIONS_MAX
global OPERATING_CONDITIONS_MIN
global CELLS_IO_CELL
global CELLS_IO_DRIVE
global CELLS_IO_LOAD
global CELLS_CK_CELL

set_operating_conditions -max $OPERATING_CONDITIONS_MAX -min $OPERATING_CONDITIONS_MIN
suppress_message [list TIM-099 TIM-052 TIM-112 TIM-255]

#------------------------------------------------------------------------------
# DESIGN CONSTRAINTS
#
#    Flatten standard cells wrappers
#    Keep top-level hierarchy
#------------------------------------------------------------------------------
set_ideal_network [get_ports i_rstn]

# ORed clocks are considered as high_fanout nets, which replace their capacitance by a default value
# setting this variable to 0 prevent this behavior
set_app_var high_fanout_net_threshold 0

# Flatten standard cells wrappers
set_dont_touch   [get_cells u_keyring/*/*/u_gate]
ungroup -flatten [get_cells u_keyring/u_dcdl*/*]
ungroup -flatten [get_cells u_keyring/u_click*/*]

# Keep top-level hierarchy
set_dont_touch [get_cells u_keyring/u_dcdl*]
set_dont_touch [get_cells u_keyring/u_click*]

# Flatten the design and keep top-level hierarchy
ungroup -all -flatten -start_level 2

#------------------------------------------------------------------------------
# KEYRINGS CONFIGURATIONS
#
#    Create the main KeyRing & the Mul/Div KeyRing objects
#    Configure delay elements
#    Initial delays: effective key length x DE delay (same for all childs)
#    Configure margin & periods (effective delay between same click)
#    Configure Endpoints pins
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# KEYRING OBJECTS
#------------------------------------------------------------------------------
if { [info exist kMain] || [info exist kMul] } {
    KeyRing destroy
}
source ${SCRIPTS_D}/KeyRing.tcl

# MAIN KEYRING OBJECT : 6x6 (1)
set kMain [KeyRing create "main" 6 6 1]

# MUL/DIV KEYRING OBJECT : 1X1 (1)
set kMul [KeyRing create "mul" 1 1 1]

#------------------------------------------------------------------------------
# CONFIGURE DELAY ELEMENTS
#------------------------------------------------------------------------------
set DE_SIZE   30
set DE_MIN    0.10
set DE_MAX    0.12

set DE_MAIN(0) [expr $DE_SIZE - 25]; # F -> F,D
set DE_MAIN(1) [expr $DE_SIZE - 15]; # D -> D,R
set DE_MAIN(2) [expr $DE_SIZE - 15]; # R -> R,E
set DE_MAIN(3) [expr $DE_SIZE - 15]; # E -> E,M
set DE_MAIN(4) [expr $DE_SIZE - 15]; # M -> M,W
set DE_MAIN(5) [expr $DE_SIZE - 20]; # W -> W,F
set DE_MUL     [expr $DE_SIZE - 1]

# DE LENGTH
foreach click [$kMain get_clicks] {
    set s [$kMain get_index $click -stage]
    $kMain set_dl $click -size $DE_SIZE -length $DE_MAIN($s)
}
foreach click [$kMul get_clicks] {
    $kMul set_dl $click -size $DE_SIZE -length $DE_MUL
}

# INITIAL DELAYS
foreach click [$kMain get_clicks] {
    set de_l [$kMain get_dl $click -length]
    foreach child [$kMain get_child $click -all] {
        $kMain set_delay $click -max -to $child -delay [expr $DE_MAX * $de_l]
        $kMain set_delay $click -min -to $child -delay [expr $DE_MIN * $de_l]
    }
}
foreach click [$kMul get_clicks] {
    set de_l [$kMul get_dl $click -length]
    $kMul set_delay $click -max -to $click -delay [expr $DE_MAX * $de_l]
    $kMul set_delay $click -min -to $click -delay [expr $DE_MIN * $de_l]
}

#------------------------------------------------------------------------------
# INITIAL PERIODS & MARGINS
#------------------------------------------------------------------------------
set SETUP_MARGIN 0.1
set HOLD_MARGIN  0.1
set TRANS_MARGIN 0.1

foreach click [$kMain get_clicks] {
    $kMain set_margin $click -setup $SETUP_MARGIN
    $kMain set_margin $click -hold  $HOLD_MARGIN
    $kMain set_period $click [$kMain get_effective_delay $click $click]
}
foreach click [$kMul get_clicks] {
    $kMul set_margin $click -setup $SETUP_MARGIN
    $kMul set_margin $click -hold  $HOLD_MARGIN
    $kMul set_period $click [$kMul get_effective_delay $click $click]
}

#------------------------------------------------------------------------------
# ENDPOINTS
#------------------------------------------------------------------------------
foreach click [$kMain get_clicks] {
    set e [$kMain get_index $click -eu ]
    set s [$kMain get_index $click -stage]
    $kMain set_endpoint $click -clkb [get_pins u_keyring/u_click_${e}_${s}/u_clkbuf/u_gate/Z]
    $kMain set_endpoint $click -clkf [get_pins u_keyring/u_click_${e}_${s}/u_toggle/u_gate/CP]
    $kMain set_endpoint $click -keyb [get_pins u_keyring/u_click_${e}_${s}/u_keybuf/u_gate/Z]
    $kMain set_endpoint $click -keyf [get_pins u_keyring/u_click_${e}_${s}/u_toggle/u_gate/Q]
    $kMain set_endpoint $click -dl   [get_pins u_keyring/u_dcdl_${e}_${s}/u_obf/u_gate/Z]
    $kMain set_endpoint $click -sel  [get_pins u_keyring/u_dcdl_${e}_${s}/u_ckmx*/u_gate/S]
}
foreach click [$kMul get_clicks] {
    $kMul set_endpoint $click -clkb [get_pins u_keyring/u_click_m/u_clkbuf/u_gate/Z]
    $kMul set_endpoint $click -clkf [get_pins u_keyring/u_click_m/u_toggle/u_gate/CP]
    $kMul set_endpoint $click -keyb [get_pins u_keyring/u_click_m/u_keybuf/u_gate/Z]
    $kMul set_endpoint $click -keyf [get_pins u_keyring/u_click_m/u_toggle/u_gate/Q]
    $kMul set_endpoint $click -dl   [get_pins u_keyring/u_dcdl_m/u_obf/u_gate/Z]
    $kMul set_endpoint $click -sel  [get_pins u_keyring/u_dcdl_m/u_ckmx*/u_gate/S]
}

#------------------------------------------------------------------------------
# CLOCKS DEFINITIONS
#
#    Root Clocks Definitions: Click, Key
#    Launch & Capture Clocks Definitions: Setup (left, up), Hold (right, down)
#    Clock Propagations
#    Clock Margins
#    Delay Elements configurations (case analysis)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# ROOT CLOCKS
#------------------------------------------------------------------------------
foreach click [$kMain get_clicks] {

    # Click
    create_clock -name [$kMain get_clock_name $click -root -clk] \
        -period [$kMain get_period ${click}] \
        -add [$kMain get_endpoint $click -clkb]

    # Key
    create_generated_clock -name [$kMain get_clock_name $click -root -key] \
        -divide_by 2 -master_clock [get_clock [$kMain get_clock_name $click -root -clk]] \
        -source [$kMain get_endpoint $click -clkf] \
        -add [$kMain get_endpoint $click -keyf]
}
foreach click [$kMul get_clicks] {

    # Click
    create_clock -name [$kMul get_clock_name $click -root -clk] \
        -period [$kMul get_period $click] \
        -add [$kMul get_endpoint $click -clkb]

    # Key
    create_generated_clock -name [$kMul get_clock_name $click -root -key] \
        -divide_by 2 -master_clock [get_clock [$kMul get_clock_name $click -root -clk]] \
        -source [$kMul get_endpoint $click -clkf] \
        -add [$kMul get_endpoint $click -keyf]
}

update_timing

#------------------------------------------------------------------------------
# LAUNCH & CAPTURE CLOCKS
#------------------------------------------------------------------------------
foreach click [$kMain get_clicks] {

    set click_left  [$kMain get_parent $click -left]
    set click_up    [$kMain get_parent $click -up]
    set click_down  [$kMain get_child [$kMain get_parent $click -left] -down]
    set click_right [$kMain get_child [$kMain get_parent $click -up] -right]

    # Setup Left Launch
    create_generated_clock -name [$kMain get_clock_name $click -launch -left] \
        -edges {1 3 5} -master_clock [get_clock [$kMain get_clock_name $click_left -root -clk]] \
        -source [$kMain get_endpoint $click_left -clkb] \
        -add [$kMain get_endpoint $click_left -clkb]

    # Setup Left Capture
    create_generated_clock -name [$kMain get_clock_name $click -capture -left] \
        -combinational -master_clock [get_clock [$kMain get_clock_name $click_left -root -key]] \
        -source [$kMain get_endpoint $click_left -keyf] \
        -add [$kMain get_endpoint $click -clkb]

    # Setup Up Launch
    create_generated_clock -name [$kMain get_clock_name $click -launch -up] \
        -edges {1 3 5} -master_clock [get_clock [$kMain get_clock_name $click_up -root -clk]] \
        -source [$kMain get_endpoint $click_up -clkb] \
        -add [$kMain get_endpoint $click_up -clkb]

    # Setup Up Capture
    create_generated_clock -name [$kMain get_clock_name $click -capture -up] \
        -combinational -master_clock [get_clock [$kMain get_clock_name $click_up -root -key]] \
        -source [$kMain get_endpoint $click_up -keyf] \
        -add [$kMain get_endpoint $click -clkb]

    # Hold Down Launch
    create_generated_clock -name [$kMain get_clock_name $click -launch -down] \
        -edges {1 2 3} -master_clock [get_clock [$kMain get_clock_name $click_left -root -key]] \
        -source [$kMain get_endpoint $click_left -keyf] \
        -add [$kMain get_endpoint $click_down -clkb]

    # Hold Down Capture
    create_generated_clock -name [$kMain get_clock_name $click -capture -down] \
        -combinational -master_clock [get_clock [$kMain get_clock_name $click_left -root -key]] \
        -source [$kMain get_endpoint $click_left -keyf] \
        -add [$kMain get_endpoint $click -clkb]

    # Hold Right Launch
    create_generated_clock -name [$kMain get_clock_name $click -launch -right] \
        -edges {1 2 3} -master_clock [get_clock [$kMain get_clock_name $click_up -root -key]] \
        -source [$kMain get_endpoint $click_up -keyf] \
        -add [$kMain get_endpoint $click_right -clkb]

    # Hold Right Capture
    create_generated_clock -name [$kMain get_clock_name $click -capture -right] \
        -combinational -master_clock [get_clock [$kMain get_clock_name $click_up -root -key]] \
        -source [$kMain get_endpoint $click_up -keyf] \
        -add [$kMain get_endpoint $click -clkb]
}
foreach click [$kMul get_clicks] {

    # Setup Launch
    create_generated_clock -name [$kMul get_clock_name $click -launch -left] \
        -edges {1 3 5} -master_clock [get_clock [$kMul get_clock_name $click -root -clk]] \
        -source [$kMul get_endpoint $click -clkb] \
        -add [$kMul get_endpoint $click -clkb]

    # Setup Capture
    create_generated_clock -name [$kMul get_clock_name $click -capture -left] \
        -combinational -master_clock [get_clock [$kMul get_clock_name $click -root -key]] \
        -source [$kMul get_endpoint $click -keyf] \
        -add [$kMul get_endpoint $click -clkb]

    # Hold Launch
    create_generated_clock -name [$kMul get_clock_name $click -launch -down] \
        -edges {1 2 3} -master_clock [get_clock [$kMul get_clock_name $click -root -key]] \
        -source [$kMul get_endpoint $click -keyf] \
        -add [$kMul get_endpoint $click -clkb]

    # Hold Capture
    create_generated_clock -name [$kMul get_clock_name $click -capture -down] \
        -combinational -master_clock [get_clock [$kMul get_clock_name $click -root -key]] \
        -source [$kMul get_endpoint $click -keyf] \
        -add [$kMul get_endpoint $click -clkb]
}

#------------------------------------------------------------------------------
# CLOCKS PROPAGATION
#------------------------------------------------------------------------------
set_propagated_clock [all_clocks]

foreach click [$kMain get_clicks] {
    set_sense -stop_propagation -clocks \
        [get_clocks [get_attribute [$kMain get_endpoint $click -clkb] clocks] \
             -filter "full_name=~*launch or full_name=~*capture"] [$kMain get_endpoint $click -clkf]
}
foreach click [$kMul get_clicks] {
    set_sense -stop_propagation -clocks \
        [get_clocks [get_attribute [$kMul get_endpoint $click -clkb] clocks] \
             -filter "full_name=~*launch or full_name=~*capture"] [$kMul get_endpoint $click -clkf]
}

# Mul/Div KeyRing has only one click: prevents direct feedback for hold calculation
set_sense -stop_propagation [get_pins u_keyring/u_click_m/u_xor*/*/* -filter {name =~ A2}]

# Do not use path through stall pin
for {set e 0} {$e < [$kMain get_eus]} {incr e} {

    # R stalls
    set_sense -clocks [get_clocks C_main_*] \
        -stop_propagation [get_pins u_keyring/u_click_${e}_2/u_clk/u_gate/A3]

    # E stalls (mul/div)
    set_sense -clocks [get_clocks C_main_*] \
        -stop_propagation [get_pins u_keyring/u_click_${e}_3/u_clk/u_gate/A3]
}

#------------------------------------------------------------------------------
# MARGINS
#------------------------------------------------------------------------------
foreach click [$kMain get_clicks] {
    foreach_in_collection launch [get_clocks ${click}_setup_*_launch] {
        foreach_in_collection capture [get_clocks ${click}_setup_*_capture] {
            set_clock_uncertainty -setup -from $launch -to $capture [$kMain get_margin $click -setup]
        }
    }
    foreach_in_collection launch [get_clocks ${click}_hold_*_launch] {
        foreach_in_collection capture [get_clocks ${click}_hold_*_capture] {
            set_clock_uncertainty -hold -from $launch -to $capture [$kMain get_margin $click -hold]
        }
    }
}
foreach click [$kMul get_clicks] {
    foreach_in_collection launch [get_clocks ${click}_setup_*_launch] {
        foreach_in_collection capture [get_clocks ${click}_setup_*_capture] {
            set_clock_uncertainty -setup -from $launch -to $capture [$kMul get_margin $click -setup]
        }
    }
    foreach_in_collection launch [get_clocks ${click}_hold_*_launch] {
        foreach_in_collection capture [get_clocks ${click}_hold_*_capture] {
            set_clock_uncertainty -hold -from $launch -to $capture [$kMul get_margin $click -hold]
        }
    }
}

#------------------------------------------------------------------------------
# DE CONFIGURATIONS
#------------------------------------------------------------------------------
foreach click [$kMain get_clicks] {
    set b 0
    foreach_in_collection pin [$kMain get_endpoint $click -sel] {
        set_case_analysis [string index [$kMain get_dl $click -opcode] $b] [get_pin $pin]
        incr b
    }
}
foreach click [$kMul get_clicks] {
    set b 0
    foreach_in_collection pin [$kMul get_endpoint $click -sel] {
        set_case_analysis [string index [$kMul get_dl $click -opcode] $b] [get_pin $pin]
        incr b
    }
}

update_timing

#------------------------------------------------------------------------------
# INTER-KEYRING CLOCKS
#
#    kMul is enabled by mul/div enable signals coming from EUs @R_clks
#    The enable signal of kMul is connected to the stall input of the click;
#    It is delayed through another DE, matching the Init path of the mul/div units
#    Hold violations are handled architecturally
#------------------------------------------------------------------------------
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
        -source [$kMain get_endpoint $click_R -clkf] \
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
        set_clock_uncertainty -setup -from $launch -to $capture $SETUP_MARGIN
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

#------------------------------------------------------------------------------
# PERFORMANCE COUNTERS SYNCHRONOUS CLOCK (@500MHz)
#
#   Synchronous clock used for cycle counter,
#   interfaced with M_clks through CDC sync module (sync)
#------------------------------------------------------------------------------

# CLOCK
set PERFCNT_CLK    C_perf
set PERFCNT_PERIOD 2
create_clock -name $PERFCNT_CLK -period $PERFCNT_PERIOD -add [get_ports i_clk]

# MARGINS
set_clock_uncertainty -setup -from [get_clocks $PERFCNT_CLK] -to [get_clocks $PERFCNT_CLK] $SETUP_MARGIN
set_clock_uncertainty -hold  -from [get_clocks $PERFCNT_CLK] -to [get_clocks $PERFCNT_CLK] $HOLD_MARGIN
set_clock_transition $TRANS_MARGIN [get_clocks $PERFCNT_CLK]

#------------------------------------------------------------------------------
# EXCEPTIONS
#
#    Clock groups
#    False Paths
#    Zero Cycle Paths
#    Case Analysis
#------------------------------------------------------------------------------
set_propagated_clock [all_clocks]
update_timing

#------------------------------------------------------------------------------
# CLOCK GROUPS
#------------------------------------------------------------------------------
set group_cmd {set_clock_groups -asynchronous}

# kMain
foreach click [$kMain get_clicks] {
    append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks "${click}_*"]}]
}

# kMul
foreach click [$kMul get_clicks] {
    append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks "${click}_*"]}]
}

# Mulsync
for {set e 0} {$e < [$kMain get_eus]} {incr e} {
    append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks C_mulsync_${e}_start*]}]
    append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks C_mulsync_${e}_stop*]}]
}

# Perf
append group_cmd [subst -nocommands -nobackslashes { -group [get_clocks "C_perf"]}]

uplevel #0 $group_cmd

#------------------------------------------------------------------------------
# FLASE PATHS
#------------------------------------------------------------------------------

# Root clocks are not used for timing analysis
set_false_path -from [get_clock *_key]
set_false_path -to   [get_clock *_key]
set_false_path -from [get_clock *_clk]
set_false_path -to   [get_clock *_clk]

# Launch/Capture clocks do not capture/launch timing paths
set_false_path -to [get_clock *_launch]
set_false_path -from [get_clock *_capture]

# Launch/Capture paths are either rise/rise or fall/fall
set_false_path -rise_from [get_clock *_launch] -fall_to [get_clock *_capture]
set_false_path -fall_from [get_clock *_launch] -rise_to [get_clock *_capture]

# Hold clocks are not used for setup analysis
set_false_path -setup -from [get_clock *_hold_*]
set_false_path -setup -to [get_clock *_hold_*]

# Setup clocks are not used for hold analysis
set_false_path -hold -from [get_clock *_setup_*]
set_false_path -hold -to [get_clock *_setup_*]

#------------------------------------------------------------------------------
# ZERO CYCLE PATHS
#------------------------------------------------------------------------------
set_multicycle_path 0 -setup -from [get_clock *_setup*launch] -to [get_clock *_setup*capture]
set_multicycle_path 0 -hold -from [get_clock *_hold*launch] -to [get_clock *_hold*capture]

update_timing

#------------------------------------------------------------------------------
# INPUTS / OUPUTS
#
#    Set Drive/Load for each Input/Output but clocks
#    Add I/O delay margin from/to KeyV to/from memories relative to their clock
#    Input delays are constrained relative to capturing clock
#    Output delays are constrained relative to launching clock
#------------------------------------------------------------------------------
set IO_DELAY  1
set IPORTS [remove_from_collection [all_inputs] [get_ports i*clk]]
set OPORTS [remove_from_collection [all_outputs] [get_ports o*clk]]

# I/O Drive/Load
set_driving_cell -library $TIMING_LIB_SLOW -lib_cell $CELLS_IO_CELL -pin $CELLS_IO_DRIVE $IPORTS
set_load [expr 5 * [load_of ${TIMING_LIB_SLOW}/${CELLS_IO_CELL}/${CELLS_IO_LOAD}]] $OPORTS

# I/O Delays
create_clock -name C_virtual_io -period 1
set_input_delay -max -clock [get_clock C_virtual_io] $IO_DELAY [get_ports i_imem_read*]
set_input_delay -max -clock [get_clock C_virtual_io] $IO_DELAY [get_ports i_dmem_read*]
set_input_delay -clock [get_clock C_perf] $IO_DELAY [get_ports i_delayl_*]

update_timing
