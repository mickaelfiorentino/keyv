#-----------------------------------------------------------------------------
# Project : KeyV
# File    : simulation/Makefile
# Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab     : GRM - Polytechnique Montreal
# Date    : <2020-02-25 Wed>
# Brief   : Simulation Makefile for Modelsim
#-----------------------------------------------------------------------------
ifndef KEYV_HOME
$(error KEYV_HOME environment variable not set... source setup.csh prior to running this Makefile)
endif

ifndef DESIGN
DESIGN = keyv
$(warning DESIGN variable not defined... using $(DESIGN) by default)
endif

ifndef STEP
STEP = beh
$(warning STEP variable not defined... using $(STEP) by default)
endif

ifndef BENCH
BENCH = basic
$(warning BENCH variable not defined... using $(BENCH) by default)
endif

DATE_LOG = $(shell date +%y%m%d%H)
DATE     = $(shell date +%Y/%m/%d)

#-----------------------------------------------------------------------------
# INFO & HELP
#-----------------------------------------------------------------------------
help: header
	$(info make help : Print this help												)
	$(info make clean: Clean directories if needed									)
	$(info make <target> DESIGN=<d> STEP=<s> BENCH=<b>								)
	$(info <target>:																)
	$(info   - sim : Perform simulation in batch mode. Save waveforms in wlf file	)
	$(info   - saif: Same as sim, +save saif file (power analysis)					)
	$(info   - view: Run vsim gui to see waveforms from wlf file (> make sim first) )
	$(info <d>:																		)
	$(info   - synv: synchronous processor											)
	$(info   - keyv: keyring processor												)
	$(info <s>:																		)
	$(info   - beh: Behavioral model												)
	$(info   - syn: Post-synthesis netlist											)
	$(info   - cg : Post-clock-gate netlist											)
	$(info <b>:																		)
	$(info   - basic																)
	$(info   - fibo																	)
	$(info   - dhrystone															)
	$(info   - coremark																)
	$(info   - embench																)
	$(info																			)

header:
	$(info																	)
	$(info =============================================================	)
	$(info Project  : KeyV													)
	$(info Authors  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>	)
	$(info Lab      : GRM - Polytechnique Montreal							)
	$(info Brief    : Simulation Flow										)
	$(info Date     : $(DATE)												)
	$(info Design   : $(DESIGN)												)
	$(info Step     : $(STEP)												)
	$(info Bench    : $(BENCH)												)
	$(info =============================================================	)
	$(info																	)

#----------------------------------------------------------------------------
# SETTINGS
#----------------------------------------------------------------------------

VSIM		= vsim -64 -quiet -logfile sim_$(DATE_LOG).log
VDEL		= vdel -all
SIM_SCRIPT	= $(KEYV_SCRIPTS)/sim.tcl

BENCH_DIR  = $(KEYV_SW_BENCH)/$(BENCH)
SIM_SUBDIR = $(DESIGN)/$(STEP)/$(BENCH)
SIM_PREFIX = $(SIM_SUBDIR)/$(DESIGN).$(STEP).$(BENCH)
CLEANDIRS  = $(KEYV_SIM)
CLEANDIRS += $(KEYV_SIM)/$(SIM_SUBDIR)

BENCH_HEX  = $(BENCH_DIR)/$(BENCH)_mem.hex
TB_HEX     = $(KEYV_SW)/mem.hex
WAVEFORMS  = $(DESIGN)/$(STEP)/$(DESIGN).$(STEP).wave.do

TRAN  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/transcript*))
WLFS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.wlf))
VCDS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.vcd))
LOGS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.log))
MTIS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.mti))
SAIF  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.saif))
WORK  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*work))

#----------------------------------------------------------------------------
# TARGETS
#----------------------------------------------------------------------------
.PHONY: clean clean_all sim view

bench:
	@rm -f $(TB_HEX)
	@ln -s $(BENCH_HEX) $(TB_HEX)

view: $(SIM_PREFIX).wlf
	$(VSIM) -view $< -do $(WAVEFORMS)

comp: header bench
	$(VSIM) -c -do $(SIM_SCRIPT) +DESIGN=$(DESIGN) +STEP=$(STEP) +BENCH=$(BENCH)

sim: header bench
	$(VSIM) -c -do $(SIM_SCRIPT) +DESIGN=$(DESIGN) +STEP=$(STEP) +BENCH=$(BENCH) +RUN

saif: header bench
	$(VSIM) -c -do $(SIM_SCRIPT) +DESIGN=$(DESIGN) +STEP=$(STEP) +BENCH=$(BENCH) +RUN +SAIF

clean:
	$(foreach f,$(TRAN),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(LOGS),$(if $(strip $(f)), rm $(f);))

clean_all: clean
	$(foreach f,$(WLFS),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(VCDS),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(MTIS),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(SAIF),$(if $(strip $(f)), rm $(f);))
	$(foreach d,$(WORK),$(if $(strip $(d)), rm -r $(d);))
