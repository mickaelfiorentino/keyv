#!/usr/bin/env tcsh
#-----------------------------------------------------------------------------
# Project : KeyV
# File    : setup.csh
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-25 Tue>
# Brief   : Project Setup for EDA tools under a CMC environment
#-----------------------------------------------------------------------------

# Make sure setup.csh is sourced from the root directory
setenv KEYV_HOME `pwd`
if ( ! -f ${KEYV_HOME}/setup.csh ) then
    echo "ERROR: setup.csh should be sourced from the root of the project... exiting"
    exit 1
endif

# Check if we are in a CMC environment
setenv CMC_CONFIG  "/CMC/scripts/cmc.2017.12.csh"
if ( ! -f ${CMC_CONFIG} ) then
    echo "ERROR: Not in a CMC environment... exiting"
    exit 1
endif
source ${CMC_CONFIG}

#-----------------------------------------------------------------------------
# PROJECT HIERARCHY
#-----------------------------------------------------------------------------
setenv KEYV_DOC            ${KEYV_HOME}/doc
setenv KEYV_DATA           ${KEYV_HOME}/data
setenv KEYV_SCRIPTS        ${KEYV_HOME}/scripts
setenv KEYV_SRC            ${KEYV_HOME}/design
setenv KEYV_SIM            ${KEYV_HOME}/simulation
setenv KEYV_SYN            ${KEYV_HOME}/synthesis
setenv KEYV_SDC            ${KEYV_HOME}/constraints
setenv KEYV_SYN_NET        netlist
setenv KEYV_SYN_REP        reports
setenv KEYV_SYN_SAV        save
setenv KEYV_SYN_LOG        logs
setenv KEYV_SW             ${KEYV_HOME}/software
setenv KEYV_SW_BENCH       ${KEYV_SW}/benchmark
setenv KEYV_SW_FIRM        ${KEYV_SW}/firmware
setenv KEYV_SW_TOOL        ${KEYV_SW}/toolchain
setenv KEYV_SW_SIM         ${KEYV_SW}/simulator
setenv KEYV_SW_EXT         ${KEYV_SW}/external
setenv KEYV_SW_BENCH_BASIC ${KEYV_SW_BENCH}/basic
setenv KEYV_SW_BENCH_FIBO  ${KEYV_SW_BENCH}/fibo
setenv KEYV_SW_BENCH_DHRY  ${KEYV_SW_BENCH}/dhrystone
setenv KEYV_SW_BENCH_CM    ${KEYV_SW_BENCH}/coremark

#-----------------------------------------------------------------------------
# TSMC65GP KIT
#-----------------------------------------------------------------------------
setenv KEYV_TSMC65GP_HOME          ${CMC_HOME}/kits/tsmc_65nm_libs/tcbn65gplus_200a/TSMCHOME/digital
setenv KEYV_TSMC65GP_FE            ${KEYV_TSMC65GP_HOME}/Front_End
setenv KEYV_TSMC65GP_BE            ${KEYV_TSMC65GP_HOME}/Back_End
setenv KEYV_TSMC65GP_FE_TIM_LIB    ${KEYV_TSMC65GP_FE}/timing_power_noise/CCS/tcbn65gplus_200a
setenv KEYV_TSMC65GP_BE_LEF_LIB    ${KEYV_TSMC65GP_BE}/lef/tcbn65gplus_200a/lef
setenv KEYV_TSMC65GP_BE_CAPTBL_DIR ${KEYV_TSMC65GP_BE}/lef/tcbn65gplus_200a/techfiles/captable
setenv KEYV_TSMC65GP_BE_MW_LIB     ${KEYV_TSMC65GP_BE}/milkyway/tcbn65gplus_200a
setenv KEYV_TSMC65GP_SIMLIB        /export/tmp/fiorentino/kits/lib/sim

#-----------------------------------------------------------------------------
# EDA TOOLS
#-----------------------------------------------------------------------------

# GCC 9
if ( `gcc -dumpversion | cut -f1 -d.` < 9 ) then
    source /users/support/config/gcc/default_cfg
endif

# PYTHON 3.7
if ( `python3 --version | cut -d ' ' -f2` != "3.7.2" ) then
    source /users/support/config/python/python-372
endif

# TCLSH 8.6
if ( `where tclsh8.6` == "" ) then
    source /users/support/config/tcltk/default_cfg
endif

# RISCV
setenv RISCV           ${KEYV_SW_TOOL}/rv32im
setenv RISCV_SPIKE     ${KEYV_SW_SIM}/riscv-isa-sim
setenv RISCV_PK        ${KEYV_SW_SIM}/riscv-pk
setenv PATH            ${PATH}:${RISCV}/bin:${RISCV}/riscv32-unknown-elf/bin
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${RISCV_SPIKE}/build:${RISCV_PK}/build
alias hex2ascii "echo \!:1 | xxd -r -p | rev"

# MODELSIM
source ${CMC_HOME}/scripts/mentor.modelsim.10.7c.csh
alias vsim "vsim -64 -logfile sim_`date +%y%m%d`.log"
alias vsim_help "${MGC_HTML_BROWSER} ${CMC_MNT_MSIM_HOME}/docs/index.html"

# DESIGN VISION
source ${CMC_HOME}/scripts/synopsys.syn.2019.03.csh
alias dv "design_vision-xg -no_gui -output_log_file dv_`date +%y%m%d`.log"

# PRIME TIME
source ${CMC_HOME}/scripts/synopsys.pts.2019.03-SP3.csh
alias pt "pt_shell -output_log_file pt_`date +%y%m%d`.log"
