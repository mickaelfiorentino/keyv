#------------------------------------------------------------------------------
# Project : KeyV
# File    : KeyRing.tcl
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-03-09 Mon>
# Brief   :
#
#   The KeyRing class allows to model the timing of a KeyRing system.
#   It uses a collection of functions on top of a dictionary data structure to:
#   - Properly define timing constraints for a KeyRing system
#   - Allow timing driven synthesis
#   - Allow static timing analyis
#
#   The KeyRing is modeled by a graph (toroidal mesh network) G = (C, K) such
#   that C ∈ E × S and K ∈ E^2 × S^2, where E represents the number of EUs in
#   the KeyRing and S represents the number of stages per EU.
#   G is a two-dimensional grid of EUs with wrap-around connections at the edges,
#   such that for any node (e,s) where e ∈ {0,..., E}, and s ∈ {0,..., S},
#   connections are defined by:
#   (1)          (e,s) ← (e, [s − 1]%S), ([e − 1]%E, [s + D - 1]%S)
#   (2)          (e,s) → (e, [s + 1]%S), ([e + 1]%E, [s - D + 1]%S)
#   D represents the dependency shift between two stages of successive EUs
#
#-----------------------------------------------------------------------------
package require Tcl 8.6
package require kVutils

oo::class create KeyRing {

    variable K; # Main dictionary
    variable E; # Number of EUs
    variable S; # Number of stages per EU
    variable D; # Dependency shift between two stages of successive EUs
    variable verbose
}
oo::define KeyRing {

    #-------------------------------------------------------------------------
    # DESTRUCTOR
    #
    #    Deletes the KeyRing object
    #-------------------------------------------------------------------------
    destructor {
        if { $verbose } {
            puts "Deleting the KeyRing object [self]"
        }
    }

    #-------------------------------------------------------------------------
    # CONSTRUCTOR
    #
    #   Generates the KeyRing object
    #   <e> x <s> clicks with dependency shift <d>
    #-------------------------------------------------------------------------
    constructor {e s d {v 0}} {

        set verbose $v

        if { [expr $d * $e] != $s } {
            error "Wrong KeyRing configuration: $s =/= $e x $d"
        }
        if { $verbose } {
            puts "Creating the KeyRing object [self] $e x $s ($d)"
        }

        set E $e
        set S $s
        set D $d

        # Crate KeyRing
        for {set e 0} {$e < $E} {incr e} {
            for {set s 0} {$s < $S} {incr s} {
                my CreateClick $e $s
            }
        }

        # Initialize with default values
        for {set e 0} {$e < $E} {incr e} {
            for {set s 0} {$s < $S} {incr s} {
                my InitClick $e $s
            }
        }
    }

    #-------------------------------------------------------------------------
    # CREATECLICK
    #
    #   Create a click (<e>,<s>) in the KeyRing (name & indexes)
    #-------------------------------------------------------------------------
    method CreateClick { e s } {

        set l [string trim [self] ::]
        dict set K C_${l}_${e}${s} name         C_${l}_${e}${s}
        dict set K C_${l}_${e}${s} index(eu)    ${e}
        dict set K C_${l}_${e}${s} index(stage) ${s}
    }

    #-------------------------------------------------------------------------
    # INITCLICK
    #
    #   Initialize a click (<e>,<s>) in the KeyRing with default values
    #   The K dictionnary is the main data structure of the KeyRing
    #-------------------------------------------------------------------------
    method InitClick { e s } {

        set l [my get_keyring_name]
        dict set K C_${l}_${e}${s} parent(left) [my get_neighbor ${e} ${s} -left]
        dict set K C_${l}_${e}${s} parent(up)   [my get_neighbor ${e} ${s} -up]
        dict set K C_${l}_${e}${s} child(right) [my get_neighbor ${e} ${s} -right]
        dict set K C_${l}_${e}${s} child(down)  [my get_neighbor ${e} ${s} -down]
        dict set K C_${l}_${e}${s} period       0
        dict set K C_${l}_${e}${s} pulse        0
        dict set K C_${l}_${e}${s} margin       setup  0
        dict set K C_${l}_${e}${s} margin       hold   0
        dict set K C_${l}_${e}${s} clk_launch   left        C_${l}_${e}${s}_setup_left_launch
        dict set K C_${l}_${e}${s} clk_launch   up          C_${l}_${e}${s}_setup_up_launch
        dict set K C_${l}_${e}${s} clk_launch   right       C_${l}_${e}${s}_hold_right_launch
        dict set K C_${l}_${e}${s} clk_launch   down        C_${l}_${e}${s}_hold_down_launch
        dict set K C_${l}_${e}${s} clk_capture  left        C_${l}_${e}${s}_setup_left_capture
        dict set K C_${l}_${e}${s} clk_capture  up          C_${l}_${e}${s}_setup_up_capture
        dict set K C_${l}_${e}${s} clk_capture  right       C_${l}_${e}${s}_hold_right_capture
        dict set K C_${l}_${e}${s} clk_capture  down        C_${l}_${e}${s}_hold_down_capture
        dict set K C_${l}_${e}${s} clk_capture  alter_down  C_${l}_${e}${s}_hold_alter_down_capture
        dict set K C_${l}_${e}${s} clk_capture  alter_right C_${l}_${e}${s}_hold_alter_right_capture
        dict set K C_${l}_${e}${s} clk_root     clk         C_${l}_${e}${s}_clk
        dict set K C_${l}_${e}${s} clk_root     key         C_${l}_${e}${s}_key
        dict set K C_${l}_${e}${s} clk_root     sel         C_${l}_${e}${s}_sel
        dict set K C_${l}_${e}${s} dl           opcode ""
        dict set K C_${l}_${e}${s} dl           size   0
        dict set K C_${l}_${e}${s} pin          clkp   ""
        dict set K C_${l}_${e}${s} pin          clkb   ""
        dict set K C_${l}_${e}${s} pin          clkf   ""
        dict set K C_${l}_${e}${s} pin          keyf   ""
        dict set K C_${l}_${e}${s} pin          keyb_c ""
        dict set K C_${l}_${e}${s} pin          keyb_d ""
        dict set K C_${l}_${e}${s} pin          dl     ""
        dict set K C_${l}_${e}${s} pin          sel    ""
        dict set K C_${l}_${e}${s} delay        max    [dict get $K C_${l}_${e}${s} child(right)] 0
        dict set K C_${l}_${e}${s} delay        max    [dict get $K C_${l}_${e}${s} child(down)]  0
        dict set K C_${l}_${e}${s} delay        min    [dict get $K C_${l}_${e}${s} child(right)] 0
        dict set K C_${l}_${e}${s} delay        min    [dict get $K C_${l}_${e}${s} child(down)]  0
        dict set K C_${l}_${e}${s} slack        max    [dict get $K C_${l}_${e}${s} child(right)] 0
        dict set K C_${l}_${e}${s} slack        max    [dict get $K C_${l}_${e}${s} child(down)]  0
        dict set K C_${l}_${e}${s} slack        min    [dict get $K C_${l}_${e}${s} child(right)] 0
        dict set K C_${l}_${e}${s} slack        min    [dict get $K C_${l}_${e}${s} child(down)]  0
    }

    #-------------------------------------------------------------------------
    # GET_KEYRING_NAME
    #
    #   Returns the name of the keyring
    #-------------------------------------------------------------------------
    method get_keyring_name args {

        set usage {
            "get_keyring_name [options]:"
            "Returns the name of the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        return [string trim [self] ::]
    }

    #-------------------------------------------------------------------------
    # GET_NAME
    #
    #   Returns the name attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_name { click args } {

        set usage {
            "get_name <click> [options]:"
            "Returns the name attribute of <click> in the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        return [dict get $K $click name]
    }

    #-------------------------------------------------------------------------
    # GET_EUS
    #
    #   Returns the number of EUs in the keyring
    #-------------------------------------------------------------------------
    method get_eus { args } {

        set usage {
            "get_eus [options]:"
            "Returns the number of EUs in the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        return $E
    }

    #-------------------------------------------------------------------------
    # GET_STAGES
    #
    #   Returns the number of stages per EU in the keyring
    #-------------------------------------------------------------------------
    method get_stages { args } {

        set usage {
            "get_stages [options]:"
            "Returns the number of stages per EU in the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        return $S
    }

    #-------------------------------------------------------------------------
    # GET_DEP
    #
    #   Returns the dependency shift between two stages of successive EUs
    #-------------------------------------------------------------------------
    method get_dep { args } {

        set usage {
            "get_dep [options]:"
            "Returns the dependency shift between two stages of successive EUs"
        }
        ::kVutils::parse_args $args "" $usage

        return $D
    }

    #-------------------------------------------------------------------------
    # SET_PERIOD
    #
    #   Set the attribute period of <click> in the keyring to <period>
    #-------------------------------------------------------------------------
    method set_period { click period args } {

        set usage {
            "set_period <click> <period> [options]:"
            "Set the attribute period of <click> in the keyring to <period>"
        }
        ::kVutils::parse_args $args "" $usage

        dict set K $click period $period
    }

    #-------------------------------------------------------------------------
    # GET_PERIOD
    #
    #   Get the period attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_period { click args } {

        set usage {
            "get_period <click> [options]:"
            "Get the period attribute of <click> in the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        return [dict get $K $click period]
    }

    #-------------------------------------------------------------------------
    # SET_PULSE
    #
    #   Set the pulse attribute of <click> in the keyring to <delay>
    #-------------------------------------------------------------------------
    method set_pulse { click delay args } {

        set usage {
            "set_pulse <click> <delay> [options]:"
            "Set the pulse attribute of <click> in the keyring to <delay>"
        }
        ::kVutils::parse_args $args "" $usage

        dict set K $click pulse $delay
    }

    #-------------------------------------------------------------------------
    # GET_PULSE
    #
    #    Get the pulse attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_pulse { click args } {

        set usage {
            "get_pulse <click> [options]:"
            "Get the pulse attribute of <click> in the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        return [dict get $K $click pulse]
    }

    #-------------------------------------------------------------------------
    # GET_CLICKS
    #
    #    Returns the list of clicks in the keyring
    #-------------------------------------------------------------------------
    method get_clicks { args } {

        set usage {
            "get_clicks [options]:"
            "Returns the list of clicks in the keyring"
        }
        ::kVutils::parse_args $args "" $usage

        set clicks [list ]
        dict for {click c} [dict get $K] {
            lappend clicks $click
        }
        return $clicks
    }

    #-------------------------------------------------------------------------
    # GET_NEIGHBOR
    #
    #    Returns the name of a neighbor click in the keyring
    #-------------------------------------------------------------------------
    method get_neighbor { e s args } {

        set usage {
            "get_neighbor e s [options]"
            "Returns the name of a neighbor click in the keyring"
        }
        set options {
            {-left  bool 0 "Get the 'left' neighbor"}
            {-right bool 0 "Get the 'right' neighbor"}
            {-up    bool 0 "Get the 'up' neighbor"}
            {-down  bool 0 "Get the 'down' neighbor"}
        }

        if { [llength $args] != 1} {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-left) } {
            return [my get_click_by_index [expr $e % ${E}] [expr ($s - 1) % ${S}]]

        } elseif { $params(-right) } {
            return [my get_click_by_index [expr $e % ${E}] [expr ($s + 1) % ${S}]]

        } elseif { $params(-up) } {
            return [my get_click_by_index [expr ($e - 1) % ${E}] [expr ($s + ${D} - 1) % ${S}]]

        } elseif { $params(-down) } {
            return [my get_click_by_index [expr ($e + 1) % ${E}] [expr ($s - ${D} + 1) % ${S}]]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # GET_INDEX
    #
    #    Returns the index of <click>
    #-------------------------------------------------------------------------
    method get_index { click args } {

        set usage {
            "get_index click [options]"
            "Returns the index of <click>"
        }
        set options {
            {-eu    bool 0 "Get the 'eu' index of click"}
            {-stage bool 0 "Get the 'stage' index of click"}
            {-all   bool 0 "Get a list {'eu' 'stage'} of click indexes"}
        }

        if { [llength $args] != 1 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-eu) } {
            return [dict get $K $click index(eu)]

        } elseif { $params(-stage) } {
            return [dict get $K $click index(stage)]

        } elseif { $params(-all) } {
            return [list [dict get $K $click index(eu)] [dict get $K $click index(stage)]]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # GET_CLICK_BY_INDEX
    #
    #   Returns the click of index <e>,<s>
    #-------------------------------------------------------------------------
    method get_click_by_index { e s args } {

        set usage {
            "get_click_by_index e s [options]"
            "Returns the click of index <e>,<s>"
        }
        ::kVutils::parse_args $args "" $usage

        foreach click [my get_clicks] {
            if { $e == [my get_index $click -eu] && $s == [my get_index $click -stage] } {
                return $click
            }
        }
    }

    #-------------------------------------------------------------------------
    # GET_CHILD
    #
    #   Returns child(s) of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_child { click args } {

        set usage {
            "get_child click [options]"
            "Returns child(s) of <click> in the keyring"
        }
        set options {
            {-right bool 0 "Get the 'right' child"}
            {-down  bool 0 "Get the 'down' child"}
            {-all   bool 0 "Get a list {'right' 'down'} of childs"}
        }

        if { [llength $args] != 1} {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-right) } {
            return [dict get $K $click child(right)]

        } elseif { $params(-down) } {
            return [dict get $K $click child(down)]

        } elseif { $params(-all) } {
            set right [dict get $K $click child(right)]
            set down  [dict get $K $click child(down)]
            if { $right == $down } {
                return [list $right]
            } else {
                return [list $right $down]
            }
        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # IS_CHILD
    #
    #   Returns [lsearch <child>] in the list of <click> childs
    #-------------------------------------------------------------------------
    method is_child { click child args } {

        set usage {
            "is_child click child [options]"
            "Returns [lsearch <child>] in the list of <click> childs"
        }
        ::kVutils::parse_args $args "" $usage

        return [lsearch [my get_child $click -all] $child]
    }

    #-------------------------------------------------------------------------
    # GET_PARENT
    #
    #   Returns a parent of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_parent { click args } {

        set usage {
            "get_parent click [options]"
            "Returns a parent of <click> in the keyring"
        }
        set options {
            {-left bool 0 "Get the 'left' parent"}
            {-up   bool 0 "Get the 'up' parent"}
            {-all  bool 0 "Get a list {'left' 'up'} of parents"}
        }

        if { [llength $args] != 1} {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-left) } {
            return [dict get $K $click parent(left)]

        } elseif { $params(-up) } {
            return [dict get $K $click parent(up)]

        } elseif { $params(-all) } {
            set left [dict get $K $click parent(left)]
            set up   [dict get $K $click parent(up)]
            if { $left == $up } {
                return [list $left]
            } else {
                return [list $left $up]
            }

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # IS_PARENT
    #
    #   Returns [lsearch <parent>] in the list of <click> parents
    #-------------------------------------------------------------------------
    method is_parent { click parent args } {

        set usage {
            "is_child click child [options]"
            "Returns [lsearch <parent>] in the list of <click> parents"
        }
        ::kVutils::parse_args $args "" $usage

        return [lsearch [my get_parent $click -all] $parent]
    }

    #-------------------------------------------------------------------------
    # GET_CLOCK_NAME
    #
    #   Returns the launch/capture clock name of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_clock_name { click args } {

        set usage {
            "get_clock_name click [options]"
            "Returns the launch/capture clock name of <click> in the keyring"
        }
        set options {
            {-root          bool 0 "Get a root clock"}
            {-clk           bool 0 "Get the root clock 'clk'"}
            {-key           bool 0 "Get the root clock 'key'"}
            {-sel           bool 0 "Get the root clock 'sel'"}
            {-launch        bool 0 "Get a launch clock"}
            {-capture       bool 0 "Get a capture clock"}
            {-left          bool 0 "Get the 'left' clock (setup)"}
            {-up            bool 0 "Get the 'up' clock (setup)"}
            {-right         bool 0 "Get the 'right' clock (hold)"}
            {-down          bool 0 "Get the 'down' clock (hold)"}
            {-alter_right   bool 0 "Get the 'Alter right' clock (capture hold)"}
            {-alter_down    bool 0 "Get the 'Alter down' clock (capture hold)"}
            {-all           bool 0 "Get all the (launch/capture) clocks in a list"}
        }

        if { [llength $args] < 2} {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-root) } {

            if { $params(-clk) } {
                return [dict get $K $click clk_root clk]

            } elseif { $params(-key) } {
                return [dict get $K $click clk_root key]

            } elseif { $params(-sel) } {
                return [dict get $K $click clk_root sel]

            } else {
                error [::kVutils::parse_usage $options $usage]
            }

        } elseif { $params(-launch) } {
            set clk clk_launch

        } elseif { $params(-capture) } {
                set clk clk_capture

        } else {
            error [::kVutils::parse_usage $options $usage]
        }

        if { $params(-left) } {
            return [dict get $K $click $clk left]

        } elseif { $params(-up) } {
            return [dict get $K $click $clk up]

        } elseif { $params(-right) } {
            return [dict get $K $click $clk right]

        } elseif { $params(-down) } {
            return [dict get $K $click $clk down]

        } elseif { $params(-alter_right) } {
            return [dict get $K $click $clk alter_right]

        } elseif { $params(-alter_down) } {
            return [dict get $K $click $clk alter_down]

        } elseif { $params(-all) } {
            return [list [dict get $K $click $clk left]    \
                         [dict get $K $click $clk up]      \
                         [dict get $K $click $clk right]   \
                         [dict get $K $click $clk down]]
        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # SET_MARGIN
    #
    #   Set the clock margins of <click> in the keyring
    #-------------------------------------------------------------------------
    method set_margin { click args } {

        set usage {
            "set_margin click [options]"
            "Set the clock margins of <click> in the keyring"
        }
        set options {
            {-setup val 0 "Setup margin"}
            {-hold  val 0 "Hold margin"}
        }

        if { [llength $args] != 2 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-setup) != 0 } {
            dict set K $click margin setup $params(-setup)

        } elseif { $params(-hold) != 0 } {
            dict set K $click margin hold $params(-hold)

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # GET_MARGIN
    #
    #   Get the clock margin of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_margin { click args } {

        set usage {
            "get_margin click [options]"
            "Get the clock margin of <click> in the keyring"
        }
        set options {
            {-setup bool 0 "Setup margin"}
            {-hold  bool 0 "Hold margin"}
        }

        if { [llength $args] != 1 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-setup) } {
            return [dict get $K $click margin setup]

        } elseif { $params(-hold) } {
            return [dict get $K $click margin hold]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # SET_DL
    #
    #   Set the dl attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method set_dl { click args } {

        set usage {
            "set_dl click [options]"
            "Set the dl attribute of <click> in the keyring"
        }
        set options {
            {-size   val 0 "Size of the DL (Total number of DE)"}
            {-length val 0 "Length of the DL (Active number of DE)"}
        }

        if { [llength $args] != 4 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-size) < $params(-length) } {
            error "Click \"$click\" size cannot be less than its length"
        }

        dict set K $click dl size $params(-size)
        dict set K $click dl opcode [::kVutils::to_thermometer $params(-length) $params(-size)]
    }

    #-------------------------------------------------------------------------
    # GET_DL
    #
    #   Get the dl attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_dl { click args } {

        set usage {
            "get_dl click [options]"
            "Get the dl attribute of <click> in the keyring"
        }
        set options {
            {-size   bool 0 "Return the 'size' of the DL (Total number of DE)"}
            {-length bool 0 "Return the 'length' of the DL (Active number of DE)"}
            {-opcode bool 0 "Return the 'opcode' string of the DL"}
        }

        if { [llength $args] != 1 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-size) } {
            return [dict get $K $click dl size]

        } elseif { $params(-opcode) } {
            return [dict get $K $click dl opcode]

        } elseif { $params(-length) } {
            return [string length [string trimright [dict get $K $click dl opcode] 1]]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # SET_ENDPOINT
    #
    #   Set the pin attributes of <click> in the keyring
    #-------------------------------------------------------------------------
    method set_endpoint { click args } {

        set usage {
            "set_endpoint click [options] pins"
            "Set the pin attributes of <click> in the keyring"
        }
        set options {
            {-clkb   val "" "Clock pin @Buffer"}
            {-clkf   val "" "Clock pin @Flip-Flop (CK)"}
            {-keyb_c val "" "Key pin on clock path @Buffer"}
            {-keyb_d val "" "Key pin on data path @Buffer"}
            {-keyf   val "" "Key pin @Flip-Flop (Q)"}
            {-dl     val "" "Delay line output pin"}
            {-sel    val "" "Delay line selection pins"}
        }

        if { [llength $args] != 2 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        # Parse options
        if { $params(-clkb) != "" } {
            dict set K $click pin clkb [get_attribute $params(-clkb) full_name]

        } elseif { $params(-clkf) != "" } {
            dict set K $click pin clkf [get_attribute $params(-clkf) full_name]

        } elseif { $params(-keyb_c) != "" } {
            dict set K $click pin keyb_c [get_attribute $params(-keyb_c) full_name]

        } elseif { $params(-keyb_d) != "" } {
            dict set K $click pin keyb_d [get_attribute $params(-keyb_d) full_name]

        } elseif { $params(-keyf) != "" } {
            dict set K $click pin keyf [get_attribute $params(-keyf) full_name]

        } elseif { $params(-dl) != "" } {
            dict set K $click pin dl [get_attribute $params(-dl) full_name]

        } elseif { $params(-sel) != "" } {
            dict set K $click pin sel [get_attribute $params(-sel) full_name]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # GET_ENDPOINT
    #
    #   Get a the pins attributes of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_endpoint { click args } {

        set usage {
            "get_endpoint click [options]"
            "Get a the pins attributes of <click> in the keyring"
        }
        set options {
            {-clkb   bool 0 "Clock pin @Buffer"}
            {-clkf   bool 0 "Clock pin @Flip-Flop (CK)"}
            {-keyb_c bool 0 "Key pin on clock path @Buffer"}
            {-keyb_d bool 0 "Key pin on data path @Buffer"}
            {-keyf   bool 0 "Key pin @Flip-Flop (Q)"}
            {-dl     bool 0 "Delay line output pin"}
            {-sel    bool 0 "Delay line selection pins"}
        }

        if { [llength $args] != 1 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-clkb) } {
            return [get_pins [dict get $K $click pin clkb]]

        } elseif { $params(-clkf) } {
            return [get_pins [dict get $K $click pin clkf]]

        } elseif { $params(-keyb_c) } {
            return [get_pins [dict get $K $click pin keyb_c]]

        } elseif { $params(-keyb_d) } {
            return [get_pins [dict get $K $click pin keyb_d]]

        } elseif { $params(-keyf) } {
            return [get_pins [dict get $K $click pin keyf]]

        } elseif { $params(-dl) } {
            return [get_pins [dict get $K $click pin dl]]

        } elseif { $params(-sel) } {
            return [get_pins [dict get $K $click pin sel]]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # SET_DELAY
    #
    #   Set a delay attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method set_delay { click args } {

        set usage {
            "set_delay click [options]"
            "Set a delay attribute of <click> in the keyring"
        }
        set options {
            {-max   bool 0  "Max delay"}
            {-min   bool 0  "Min delay"}
            {-to    val  "" "Destination Click"}
            {-delay val  0  "Delay to apply"}
        }

        if { [llength $args] < 5} {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        variable keyring

        if { [my is_child $click $params(-to)] < 0 } {
            error "$params(-to) is not in the child list of $click"
        }

        if { $params(-max) } {
            dict set K $click delay max $params(-to) $params(-delay)

        } elseif { $params(-min) } {
            dict set K $click delay min $params(-to) $params(-delay)

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # GET_DELAY
    #
    #   Get a delay attribute of <click> in the keyring
    #-------------------------------------------------------------------------
    method get_delay { click args } {

        set usage {
            "get_delay click [options]"
            "Get a delay attribute of <click> in the keyring"
        }
        set options {
            {-max bool 0  "Max delay"}
            {-min bool 0  "Min delay"}
            {-to  val  "" "Destination Click"}
        }

        if { [llength $args] != 3} {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { [my is_child $click $params(-to)] < 0 } {
            error "$params(-to) is not in the child list of $click"
        }

        if { $params(-max) } {
            return [dict get $K $click delay max $params(-to)]

        } elseif { $params(-min) } {
            return [dict get $K $click delay min $params(-to)]

        } else {
            error [::kVutils::parse_usage $options $usage]
        }
    }

    #-------------------------------------------------------------------------
    # GET_EFFECTIVE_DELAY
    #
    #   Returns the maximum delay between <C_src> and <C_dest> clicks by
    #   exploring the keyring dependency graph
    #   The algorithm is based on Breadth-first-Search & Dijkstra:
    #   - Creates an acyclic subgraph starting from <C_src>, following forward
    #     neighbors, stopping after 2 periods
    #   - Cumulated delay values from <C_src> ponderate each nodes
    #   - Computes the delay difference betwen <C_dest> and <C_src>
    #-------------------------------------------------------------------------
    method get_effective_delay { C_src C_dest args } {

        set usage {
            "get_effective_delay <C_src> C_dest> [options]"
            "Returns the maximum delay between <C_src> and <C_dest> clicks"
            "by exploring the keyring dependency graph"
        }
        ::kVutils::parse_args $args "" $usage

        # Init Data structure
        foreach click [my get_clicks] {
            dict set clks $click parent [my get_parent $click -left]
            dict set clks $click dist   0
            dict set clks $click cumul  0
        }

        # 1st pass: init, 2nd pass: definitive values
        for { set i 0 } { $i < 2 } { incr i } {

            set stack [::kVutils::stack_create $C_src]
            set hist  [::kVutils::stack_create $C_src]

            while { [llength $stack] > 0 } {

                # Update Distance
                set src [::kVutils::stack_pop stack]
                dict set clks $src dist [dict get $clks $src cumul]

                # Look for each destination neighbors
                foreach dest [my get_child $src -all] {

                    # Push new neighbors in the stack
                    if { [lsearch $hist $dest] < 0 } {
                        ::kVutils::stack_push stack $dest
                        ::kVutils::stack_push hist $dest
                    }

                    # Compute cumulated delays
                    set dold [dict get $clks $dest cumul]
                    set dnew [expr [dict get $clks $src cumul] + [my get_delay $src -max -to $dest]]

                    # Update
                    if { $dold < $dnew } {
                        dict set clks $dest cumul  $dnew
                        dict set clks $dest parent $src
                    }
                }
            }
        }

        # dict for {l c} [dict get $clks] {
        #     puts [format "%s:%s:%s" $l [dict get $c dist] [dict get $c cumul]]
        # }

        # Return the difference beween C_dest and C_src
        if { $C_src == $C_dest } {

            set C_left [my get_parent $C_dest -left]
            set C_up   [my get_parent $C_dest -up]

            set d_left [my get_delay $C_left -max -to $C_dest]
            set d_up   [my get_delay $C_up -max -to $C_dest]

            set D_left [expr [dict get $clks ${C_left} dist] - [dict get $clks ${C_src} dist]]
            set D_up   [expr [dict get $clks ${C_up} dist] - [dict get $clks ${C_src} dist]]

            return [expr max($D_left + $d_left, $D_up + $d_up)]

        } else {
            return [expr [dict get $clks ${C_dest} dist] - [dict get $clks ${C_src} dist]]
        }
    }

    #-------------------------------------------------------------------------
    # GET_DE_DELAY
    #
    #   Get the propagated delay between two clocks
    #-------------------------------------------------------------------------
    method get_de_delay args {

        set usage {
            "get_de_delay [options]"
            "Get the propagated delay between two clocks"
        }
        set options {
            {-from val "" "Launch clock"}
            {-to   val "" "Capture clock"}
            {-min  bool 0 "Report min delay (hold)"}
            {-max  bool 0 "Report max delay (setup)"}
        }

        if { [llength $args] != 5 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-max) } {
            set type max

        } elseif { $params(-min) } {
            set type min

        } else {
            error [::kVutils::parse_usage $options $usage]
        }

        redirect -variable timing {
            report_timing -nosplit -from $params(-from) -to $params(-to) -delay_type $type
        }

        set re [subst -nocommands -nobackslashes \
                    {(data arrival.*delay \(propagated\)\s+)([0-9]+\.?[0-9]+)}]

        if { [regexp $re $timing all tmp delay] } {
            return $delay
        } else {
            return 0
        }
    }

    #-------------------------------------------------------------------------
    # GET_SLACK
    #
    #   Get the slack value between two clocks
    #-------------------------------------------------------------------------
    method get_slack args {

        set usage {
            "get_slack [options]"
            "Get the slack value between two clocks"
        }
        set options {
            {-from val "" "Launch clock"}
            {-to   val "" "Capture clock"}
            {-min  bool 0 "Report min delay (hold)"}
            {-max  bool 0 "Report max delay (setup)"}
        }

        if { [llength $args] !=5 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        if { $params(-max) } {
            set type max

        } elseif { $params(-min) } {
            set type min

        } else {
            error [::kVutils::parse_usage $options $usage]
        }

        redirect -variable timing {
            report_timing -nosplit -from $params(-from) -to $params(-to) -delay_type $type
        }

        if { [regexp {(slack\s+\(\w+\)\s+)(-?[0-9]+\.[0-9]+)} $timing all tmp slack] } {
            return $slack

        } else {
            return -1
        }
    }

    #-------------------------------------------------------------------------
    # UPDATE_DELAY_ELEMENTS
    #
    # Update a KeyRing Delay Element configuration
    #-------------------------------------------------------------------------
    method update_delay_elements args {

        set usage {
            "update_delay_elements [options]"
            "Update a KeyRing Delay Element configuration"
        }
        set options {
            {-size val "" "Size of delay elements"}
            {-cfg  val "" "Array of delay elements configuration"}
        }
        if { [llength $args] != 4 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]
        upvar 1 $params(-cfg) cfg

        # Update KeyRing object
        foreach click [my get_clicks] {
            set s [my get_index $click -stage]
            my set_dl $click -size $params(-size) -length $cfg($s)
        }

        # Apply case analysis
        foreach click [my get_clicks] {
            set b 0
            foreach_in_collection pin [my get_endpoint $click -sel] {
                set_case_analysis [string index [my get_dl $click -opcode] $b] [get_pin $pin]
                incr b
            }
        }
    }

    #-------------------------------------------------------------------------
    # UPDATE_TIMING_INFORMATION
    #
    # Update a KeyRing object timing information from timing analysis
    # (delays, slack, periods)
    #-------------------------------------------------------------------------
    method update_timing_information args {

        set usage {
            "update_timing_information [options]"
            "Update a KeyRing object timing information from timing analysis (delays, slack, periods)"
        }
        ::kVutils::parse_args $args "" $usage

        # Update Clicks delays
        foreach click [my get_clicks] {

            set left  [my get_parent $click -left]
            set up    [my get_parent $click -up]
            set right [my get_child  $click -right]
            set down  [my get_child  $click -down]

            # Parent left (max)
            my set_delay $left -to $click -max -delay \
                [my get_de_delay -max \
                     -from [my get_clock_name $click -launch -left] \
                     -to   [my get_clock_name $click -capture -left]]

            # Parent Up (max)
            my set_delay $up -to $click -max -delay \
                [my get_de_delay -max \
                     -from [my get_clock_name $click -launch -up] \
                     -to   [my get_clock_name $click -capture -up]]

            # Child Right (min)
            my set_delay $click -to $right -min -delay \
                [my get_de_delay -min \
                     -from [my get_clock_name $click -launch -right] \
                     -to   [my get_clock_name $click -capture -right]]

            # Child Down (min)
            my set_delay $click -to $down -min -delay \
                [my get_de_delay -min \
                     -from [my get_clock_name $click -launch -down] \
                     -to   [my get_clock_name $click -capture -down]]
        }

        # Update Clicks period
        foreach click [my get_clicks] {
            my set_period $click [my get_effective_delay $click $click]
        }
    }

    #------------------------------------------------------------------------------
    # INIT_DELAYS
    #
    #    Define initial delays (DE length/period/margins) parameters in the KeyRing
    #------------------------------------------------------------------------------
    method init_delays args {

        set usage {
            "init_delays [options]"
            "Define initial delays (DE length/period/margins) parameters in the KeyRing"
        }
        set options {
            {-de_params val "" "Deleay elements parameters array [size, min, max]"}
            {-de_length val "" "Deleay elements length array [s,]"}
            {-margins   val "" "Margins array [setup, hold]"}
        }
        if { [llength $args] != 6 } {
            error [::kVutils::parse_usage $options $usage]
        }
        array set params [::kVutils::parse_args $args $options $usage]

        upvar 1 $params(-de_params) de_params
        upvar 1 $params(-de_length) de_length
        upvar 1 $params(-margins) margins

        # DE LENGTH
        foreach click [my get_clicks] {
            set s [my get_index $click -stage]
            my set_dl $click -size $de_params(size) -length $de_length($s)
        }

        # INITIAL DELAYS
        foreach click [my get_clicks] {
            set de_l [my get_dl $click -length]
            foreach child [my get_child $click -all] {
                my set_delay $click -max -to $child -delay [expr $de_params(max) * $de_l]
                my set_delay $click -min -to $child -delay [expr $de_params(min) * $de_l]
            }
        }

        # CLOCK PERIODS & MARGINS
        foreach click [my get_clicks] {
            my set_period $click [my get_effective_delay $click $click]
            my set_margin $click -setup $margins(setup)
            my set_margin $click -hold  $margins(hold)
        }
    }

    #------------------------------------------------------------------------------
    # CREATE_ROOT_CLOCKS
    #
    #    Create clock/key root clocks intended to be used for defining
    #    launch/capture clocks
    #------------------------------------------------------------------------------
    method create_root_clocks args {

        set usage {
            "create_root_clocks [options]"
            "Create clock/key root clocks of the KeyRing"
        }
        ::kVutils::parse_args $args "" $usage

        foreach click [my get_clicks] {

            # Click
            create_clock -name [my get_clock_name $click -root -clk] \
                -period [my get_period $click] \
                -add [my get_endpoint $click -clkb]

            # Key
            create_generated_clock -name [my get_clock_name $click -root -key] \
                -divide_by 2 -master_clock [get_clock [my get_clock_name $click -root -clk]] \
                -source [my get_endpoint $click -clkb] \
                -add [my get_endpoint $click -keyb_c]
        }

        set_propagated_clock [get_clocks *_clk]
        set_propagated_clock [get_clocks *_key]
        update_timing
    }

    #------------------------------------------------------------------------------
    # GENERATE_LC_CLOCKS
    #
    #    Generate Launch/Capture clocks from root clocks
    #------------------------------------------------------------------------------
    method generate_lc_clocks args {

        set usage {
            "generate_lc_clocks [options]"
            "Generate Launch/Capture clocks from root clocks"
        }
        ::kVutils::parse_args $args "" $usage

        foreach click [my get_clicks] {

            set click_left  [my get_parent $click -left]
            set click_up    [my get_parent $click -up]
            set click_down  [my get_child [my get_parent $click -left] -down]
            set click_right [my get_child [my get_parent $click -up] -right]

            ###########
            #  SETUP  #
            ###########

            # Setup Left Launch
            create_generated_clock -name [my get_clock_name $click -launch -left] \
                -edges {1 3 5} -master_clock [get_clock [my get_clock_name $click_left -root -clk]] \
                -source [my get_endpoint $click_left -clkb] \
                -add [my get_endpoint $click_left -clkb]

            # Setup Left Capture
            create_generated_clock -name [my get_clock_name $click -capture -left] \
                -combinational -master_clock [get_clock [my get_clock_name $click_left -root -key]] \
                -source [my get_endpoint $click_left -keyb_c] \
                -add [my get_endpoint $click -clkb]

            # (1,1,1) KeyRing does not need these clocks (redundant)
            if { $click_left != $click_up } {

                # Setup Up Launch
                create_generated_clock -name [my get_clock_name $click -launch -up] \
                    -edges {1 3 5} -master_clock [get_clock [my get_clock_name $click_up -root -clk]] \
                    -source [my get_endpoint $click_up -clkb] \
                    -add [my get_endpoint $click_up -clkb]

                # Setup Up Capture
                create_generated_clock -name [my get_clock_name $click -capture -up] \
                    -combinational -master_clock [get_clock [my get_clock_name $click_up -root -key]] \
                    -source [my get_endpoint $click_up -keyb_c] \
                    -add [my get_endpoint $click -clkb]
            }

            ##########
            #  HOLD  #
            ##########

            # Hold Down Launch
            create_generated_clock -name [my get_clock_name $click -launch -down] \
                -edges {1 2 3} -master_clock [get_clock [my get_clock_name $click_left -root -key]] \
                -source [my get_endpoint $click_left -keyb_c] \
                -add [my get_endpoint $click_down -clkb]

            # Hold Down Capture
            create_generated_clock -name [my get_clock_name $click -capture -down] \
                -combinational -master_clock [get_clock [my get_clock_name $click_left -root -key]] \
                -source [my get_endpoint $click_left -keyb_c] \
                -add [my get_endpoint $click -clkb]

            # (1,1,1) KeyRing does not need these clocks (redundant)
            if { $click_down != $click_right } {

                # Hold Right Launch
                create_generated_clock -name [my get_clock_name $click -launch -right] \
                    -edges {1 2 3} -master_clock [get_clock [my get_clock_name $click_up -root -key]] \
                    -source [my get_endpoint $click_up -keyb_c] \
                    -add [my get_endpoint $click_right -clkb]

                # Hold Right Capture
                create_generated_clock -name [my get_clock_name $click -capture -right] \
                    -combinational -master_clock [get_clock [my get_clock_name $click_up -root -key]] \
                    -source [my get_endpoint $click_up -keyb_c] \
                    -add [my get_endpoint $click -clkb]
            }
        }

        # CLOCK CONFIGURATIONS
        set_propagated_clock [get_clocks *_launch]
        set_propagated_clock [get_clocks *_capture]

        # Break timing loops in the KeyRing
        foreach click [my get_clicks] {
            set_sense -stop_propagation -clocks \
                [get_clocks [get_attribute [my get_endpoint $click -clkb] clocks] \
                     -filter "full_name=~*launch or full_name=~*capture"] \
                [my get_endpoint $click -keyb_c]
        }

        # Define DE effective lengths
        foreach click [my get_clicks] {
            set b 0
            foreach_in_collection pin [my get_endpoint $click -sel] {
                set_case_analysis [string index [my get_dl $click -opcode] $b] [get_pin $pin]
                incr b
            }
        }

        # Add margins
        foreach click [my get_clicks] {

            # Setup
            foreach_in_collection launch [get_clocks ${click}_setup_*_launch] {
                foreach_in_collection capture [get_clocks ${click}_setup_*_capture] {
                    set_clock_uncertainty -setup -from $launch -to $capture \
                        [my get_margin $click -setup]
                }
            }

            # Hold
            foreach_in_collection launch [get_clocks ${click}_hold_*_launch] {
                foreach_in_collection capture [get_clocks ${click}_hold_*_capture] {
                    set_clock_uncertainty -hold -from $launch -to $capture \
                        [my get_margin $click -hold]
                }
            }
        }

        update_timing
    }

    #------------------------------------------------------------------------------
    # GENERATE_XBS_CLOCKS
    #
    #   Clocks defined on the clkb pin which activates a single-cycle path going
    #   through the keyb_d pins. Allow to constrain hold on xbs selection signals
    #------------------------------------------------------------------------------
    method generate_xbs_clocks args {

         set usage {
            "generate_xbs_clocks [options]"
            "Sel clocks to constrain hold on xbs selection signals"
        }
        ::kVutils::parse_args $args "" $usage

        foreach click [my get_clicks] {

            set clksel [my get_clock_name $click -root -sel]

            create_generated_clock -name  $clksel \
                -edges {1 2 3} -master_clock [get_clock [my get_clock_name $click -root -clk]] \
                -source [my get_endpoint $click -clkb] \
                -add [my get_endpoint $click -clkb]

            set_clock_uncertainty -hold -from [get_clocks $clksel] -to [get_clocks $clksel] \
                [my get_margin $click -hold]
        }

        set_propagated_clock [get_clocks *_sel]
        update_timing
    }

}
