#-----------------------------------------------------------------------------
# Project : KeyV
# File    : run.do
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-04-01 Wed>
# Brief   : Modelsim simulation script
#-----------------------------------------------------------------------------
global dut
global saif
global mem
global pad
global DO_SAIF

set StdArithNoWarnings   1
set NumericStdNoWarnings 1

# Log all signals in wave files
log * -r
add wave -r /*

onerror {
    quit -sim
}

# Toggle power recording on/off each time the breakpoint is triggered,
# as long as rstn = 1, else save files & exit.
onbreak {
    if { $DO_SAIF } {
        if { [examine -value -radix unsigned rstn] == 1 } {
            if { !$pwr } {
                set pwr 1
                echo [format "POWER ON @ %dps" $now]
                power on
            } else {
                set pwr 0
                echo [format "POWER OFF @ %dps" $now]
                power off
            }
            resume
            run -all
        } else {
            echo [format "SAVING FILES\n>> %s \n>> %s" $saif $mem]
            power report -bsaif $saif
            mem save -addressradix hex -dataradix hex -wordsperline 1 -outfile $mem ${pad}/mem
            resume
            echo [format "\nSIMULATION END \[%s\]\n" [::kVutils::get_time]]
            quit -sim
        }
    } else {
        echo [format "SAVING FILES\n>> %s" $mem]
        mem save -addressradix hex -dataradix hex -wordsperline 1 -outfile $mem ${pad}/mem
        resume
        echo [format "\nSIMULATION END \[%s\]\n" [::kVutils::get_time]]
        quit -sim
    }
}

# Trigger a breakpoint when imem_read = C0002573 (timer instruction : rdcycle a0)
# Record all signals of the dut in the SAIF file (off @ start)
if { $DO_SAIF } {
    bp tb.sv 98 -cond {imem_read == C0002573}
    power add -internal -r ${dut}/*
    power off
    set pwr 0
}

echo [format "\nSIMULATION START \[%s\]\n" [::kVutils::get_time]]
run -all
