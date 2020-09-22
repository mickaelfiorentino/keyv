#-----------------------------------------------------------------------------
# Project : KeyV
# File    : synthesis/Makefile
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-14 Fri>
# Brief   : Synthesis Makefile for Synopsys Design Compiler
#-----------------------------------------------------------------------------
ifndef KEYV_HOME
$(error KEYV_HOME environment variable not set... source setup.csh prior to running this Makefile)
endif

ifndef DESIGN
DESIGN = keyv
$(warning DESIGN variable not defined... using $(DESIGN) by default)
endif

ifndef STEP
STEP = syn
$(warning STEP variable not defined... using $(STEP) by default)
endif

ifndef BENCH
BENCH = ""
endif

DATE_LOG = $(shell date +%y%m%d%H)
DATE     = $(shell date +%Y/%m/%d)

#-----------------------------------------------------------------------------
# INFO & HELP
#-----------------------------------------------------------------------------
help: header
	$(info make help : Print this help						)
	$(info make clean, clean_all : Clean outputs			)
	$(info make <target> DESIGN=<d> STEP=<s> BENCH=<b>		)
	$(info <target>:										)
	$(info   - syn     : Synthesis with Design Compiler		)
	$(info   - cg      : Clock gating with Design Compiler	)
	$(info   - sdf     : Write sdf with Prime Time			)
	$(info   - pwr     : Power evalutation with Prime Time	)
	$(info <d>:												)
	$(info   - synv: synchronous processor					)
	$(info   - keyv: keyring processor						)
	$(info <s>:												)
	$(info   - syn: Use post-synthesis netlist (sdf, pwr)	)
	$(info   - cg : Use post-clock-gate netlist (sdf, pwr)	)
	$(info <b>:												)
	$(info   - dhrystone									)
	$(info   - coremark										)
	$(info   - embench										)
	$(info													)

header:
	$(info																	)
	$(info =============================================================	)
	$(info Project  : KeyV													)
	$(info Authors  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>	)
	$(info Lab      : GRM - Polytechnique Montreal							)
	$(info Brief    : Synthesis Flow										)
	$(info Date     : $(DATE)												)
	$(info Design   : $(DESIGN)												)
	$(info =============================================================	)
	$(info																	)

#----------------------------------------------------------------------------
# SETTINGS
#----------------------------------------------------------------------------

SYN_SCRIPT	= $(abspath $(KEYV_SCRIPTS)/syn.tcl)
CG_SCRIPT	= $(abspath $(KEYV_SCRIPTS)/cg.tcl)
SDF_SCRIPT	= $(abspath $(KEYV_SCRIPTS)/sdf.tcl)
PWR_SCRIPT	= $(abspath $(KEYV_SCRIPTS)/pwr.tcl)

SYN_LOG = syn_$(DATE_LOG).log
CG_LOG	= cg_$(DATE_LOG).log
SDF_LOG = sdf_$(DATE_LOG).log
PWR_LOG = pwr_$(DATE_LOG).log

PT = pt_shell
DV = design_vision-xg -no_gui

#----------------------------------------------------------------------------
# TARGETS
#----------------------------------------------------------------------------
.PHONY: clean clean_all

syn: header
	$(DV) -f $(SYN_SCRIPT) -x "set DESIGN $(DESIGN)" -output_log_file $(SYN_LOG)

cg: header
	$(DV) -f $(CG_SCRIPT) -x "set DESIGN $(DESIGN)" -output_log_file $(CG_LOG)

sdf: header
	$(PT) -f $(SDF_SCRIPT) -x "set DESIGN $(DESIGN); set STEP $(STEP)" -output_log_file $(SDF_LOG)

pwr: header
	$(PT) -f $(PWR_SCRIPT) -x "set DESIGN $(DESIGN); set STEP $(STEP); set BENCH $(BENCH)" -output_log_file $(PWR_LOG)

clean:
	rm -rf alib* *.svf command.log filenames.log

clean_all: clean
	rm -rf */work *.log *.txt
