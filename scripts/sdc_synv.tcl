#------------------------------------------------------------------------------
# Project : KeyV
# File    : sdc_synv.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-03-09 Mon>
# Brief   : SynV Design Constraints
#------------------------------------------------------------------------------
package require Tcl 8.6
package require kVutils
package require kVsyn

global TIMING_LIB_SLOW
global TIMING_LIB_FAST
global OPERATING_CONDITIONS_MAX
global OPERATING_CONDITIONS_MIN
global CELLS_IO_CELL
global CELLS_IO_DRIVE
global CELLS_IO_LOAD
global CELLS_CK_CELL

#----------------------------------------------------------------------------
# DESIGN CONSTRAINTS
#----------------------------------------------------------------------------
set_operating_conditions -max $OPERATING_CONDITIONS_MAX -min $OPERATING_CONDITIONS_MIN

# Flatten the design and keep top-level hierarchy
ungroup -all -flatten -start_level 2

# Reset
set_ideal_network [get_pins u_clock_and_reset/o_rstn]

#----------------------------------------------------------------------------
# CLOCKS
#----------------------------------------------------------------------------
set PERIOD       2
set SETUP_MARGIN 0.1
set HOLD_MARGIN  0.1
set TRANS_MARGIN 0.1
set IO_MARGIN    0.2

# Input clock: Feeding clock_and_reset module
set input_clk_pin i_clk
set input_clk     "synv_in_clk"

create_clock -name $input_clk -period $PERIOD -add [get_ports $input_clk_pin]

# Main clock: From clock_and_reset module, feeding the whole design. Generated from input clock (x1)
set main_clk_pin  u_clock_and_reset/o_clk
set main_clk      "synv_clk"

create_generated_clock -name $main_clk -edges {1 2 3} \
    -master_clock [get_clocks $input_clk] -source [get_ports $input_clk_pin] \
    -add [get_pins $main_clk_pin]

# Margins
foreach_in_collection clk [get_clocks *] {
    set_clock_uncertainty -setup -from $clk -to $clk $SETUP_MARGIN
    set_clock_uncertainty -hold  -from $clk -to $clk $HOLD_MARGIN
    set_clock_transition $TRANS_MARGIN $clk
}

# Propagate clocks to add clock-tree estimations in timing
set_propagated_clock [all_clocks]

#----------------------------------------------------------------------------
# INPUTS / OUTPUTS
#----------------------------------------------------------------------------
set IPORTS [remove_from_collection [all_inputs] [get_ports i*clk]]
set OPORTS [remove_from_collection [all_outputs] [get_ports o*clk]]

# I/O Delay
set_input_delay  -clock [get_clock synv_clk] $IO_MARGIN $IPORTS
set_output_delay -clock [get_clock synv_clk] $IO_MARGIN $OPORTS

# I/O Drive/Load
set_driving_cell -library $TIMING_LIB_SLOW -lib_cell $CELLS_IO_CELL -pin $CELLS_IO_DRIVE $IPORTS
set_load [expr 5 * [load_of ${TIMING_LIB_SLOW}/${CELLS_IO_CELL}/${CELLS_IO_LOAD}]] $OPORTS

#----------------------------------------------------------------------------
# COST GROUPS
#----------------------------------------------------------------------------
foreach_in_collection clk [get_clocks *] {
    set clkname [get_attribute $clk name]
    group_path -name paths_$clkname -to $clk
}

group_path -name paths_inputs -from $IPORTS
group_path -name paths_outputs -to $OPORTS

update_timing
