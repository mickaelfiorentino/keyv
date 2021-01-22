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
global OPCOND
global CELLS_IO_CELL
global CELLS_IO_DRIVE
global CELLS_IO_LOAD
global CELLS_CK_CELL

set_operating_conditions -max $OPCOND -min $OPCOND
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

# KEYRING OBJECTS
if { [info exist kMain] || [info exist kMul] } {
    KeyRing destroy
}
source ${SCRIPTS_D}/KeyRing.tcl

# MAIN KEYRING OBJECT : 6x6 (1)
set kMain [KeyRing create "main" 6 6 1]

# MUL/DIV KEYRING OBJECT : 1X1 (1)
set kMul [KeyRing create "mul" 1 1 1]

set DE_PARAMS(size) 20
set DE_PARAMS(min)  0.1
set DE_PARAMS(max)  0.1

set DE_LENGTH_MAIN(0) [expr $DE_PARAMS(size) - 5]
set DE_LENGTH_MAIN(1) [expr $DE_PARAMS(size) - 5]
set DE_LENGTH_MAIN(2) [expr $DE_PARAMS(size) - 5]
set DE_LENGTH_MAIN(3) [expr $DE_PARAMS(size) - 5]
set DE_LENGTH_MAIN(4) [expr $DE_PARAMS(size) - 5]
set DE_LENGTH_MAIN(5) [expr $DE_PARAMS(size) - 5]
set DE_LENGTH_MUL(0)  [expr $DE_PARAMS(size) - 1]

set MARGINS(setup) 0.1
set MARGINS(hold)  0.1

$kMain init_delays -de_params DE_PARAMS -de_length DE_LENGTH_MAIN -margins MARGINS
$kMul  init_delays -de_params DE_PARAMS -de_length DE_LENGTH_MUL -margins MARGINS

foreach click [$kMain get_clicks] {
    set e [$kMain get_index $click -eu ]
    set s [$kMain get_index $click -stage]
    $kMain set_endpoint $click -clkb   [get_pins u_keyring/u_click_${e}_${s}/u_clkb/u_gate/Z]
    $kMain set_endpoint $click -clkf   [get_pins u_keyring/u_click_${e}_${s}/u_toggle/u_gate/CP]
    $kMain set_endpoint $click -keyb_c [get_pins u_keyring/u_click_${e}_${s}/u_keyb_c/u_gate/Z]
    $kMain set_endpoint $click -keyb_d [get_pins u_keyring/u_click_${e}_${s}/u_keyb_d/u_gate/ZN]
    $kMain set_endpoint $click -keyf   [get_pins u_keyring/u_click_${e}_${s}/u_toggle/u_gate/Q]
    $kMain set_endpoint $click -dl     [get_pins u_keyring/u_dcdl_${e}_${s}/u_obf/u_gate/Z]
    $kMain set_endpoint $click -sel    [get_pins u_keyring/u_dcdl_${e}_${s}/u_ckmx*/u_gate/S]
}
foreach click [$kMul get_clicks] {
    $kMul set_endpoint $click -clkb   [get_pins u_keyring/u_click_m/u_clkb/u_gate/Z]
    $kMul set_endpoint $click -clkf   [get_pins u_keyring/u_click_m/u_toggle/u_gate/CP]
    $kMul set_endpoint $click -keyb_c [get_pins u_keyring/u_click_m/u_keyb_c/u_gate/Z]
    $kMul set_endpoint $click -keyb_d [get_pins u_keyring/u_click_m/u_keyb_d/u_gate/ZN]
    $kMul set_endpoint $click -keyf   [get_pins u_keyring/u_click_m/u_toggle/u_gate/Q]
    $kMul set_endpoint $click -dl     [get_pins u_keyring/u_dcdl_m/u_obf/u_gate/Z]
    $kMul set_endpoint $click -sel    [get_pins u_keyring/u_dcdl_m/u_ckmx*/u_gate/S]
}

#------------------------------------------------------------------------------
# CLOCKS CONSTRAINTS
#
#    Root clocks definitions: Click, Key
#    Launch & Capture clocks definitions: Setup (left, up), Hold (right, down)
#    Inter KeyRing synchronizer clock definitions
#    Perofrmance counter
#    Exceptions
#------------------------------------------------------------------------------

# ROOT CLOCKS
$kMain create_root_clocks
$kMul create_root_clocks

# LAUNCH & CAPTURE CLOCKS
$kMain generate_lc_clocks
$kMul generate_lc_clocks

# XBS CLOCKS
$kMain generate_xbs_clocks

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
update_timing

# INTER-KEYRING CLOCKS
::kVsyn::keyv_generate_inter_keyring_clocks

# PERFORMANCE COUNTER SYNCHRONOUS CLOCK (@500MHz)
::kVsyn::keyv_create_perf_clocks -period 2 -margins MARGINS

# EXCEPTIONS
::kVsyn::keyv_exceptions

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
set_driving_cell -library $TIMING_LIB -lib_cell $CELLS_IO_CELL -pin $CELLS_IO_DRIVE $IPORTS
set_load [expr 5 * [load_of ${TIMING_LIB}/${CELLS_IO_CELL}/${CELLS_IO_LOAD}]] $OPORTS

# I/O Delays
create_clock -name C_virtual_io -period 1
set_input_delay -max -clock [get_clock C_virtual_io] $IO_DELAY [get_ports i_imem_read*]
set_input_delay -max -clock [get_clock C_virtual_io] $IO_DELAY [get_ports i_dmem_read*]
set_input_delay -clock [get_clock C_perf] $IO_DELAY [get_ports i_delay_*]

update_timing
