#-----------------------------------------------------------------------------
# Project  : KeyV
# File     : Makefile <benchmarks>
# Author   : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab      : grm@polymtl
# Date     : <2020-02-26 Wed>
# Brief    : Makefile for compiling RV32IM code
#----------------------------------------------------------------------------
ifndef KEYV_HOME
$(error KEYV_HOME environment variable not set... source setup.csh prior to running this Makefile)
endif

ifndef RISCV
$(error RISCV variable not defined... source setup.csh prior to running this Makefile)
endif


ifndef BENCH
BENCH = basic
$(warning BENCH variable not defined... using $(BENCH) by default)
endif

DATE_LOG = $(shell date +%Y%m%d-%H%M)
DATE     = $(shell date +%Y/%m/%d)

#-----------------------------------------------------------------------------
# INFO & HELP
#-----------------------------------------------------------------------------
help: header
	$(info make help: Print this help														)
	$(info make <target> BENCH=<bench>														)
	$(info <target>:																		)
	$(info   - clean   : Clean the benchmark/<bench> directory								)
	$(info   - compile : Compile program to .elf + produce .dump & .hex files				)
	$(info <bench>:																			)
	$(info   - basic     : 'basic' assembly program which verify the ISA implementation		)
	$(info   - fibo      : 'fibo' C program which test stdlib using the fibonacci algorithm	)
	$(info   - dhrystone : 'dhrystone' benchmark											)
	$(info   - coremark  : 'coremark' benchmark												)
	$(info   - embench   : 'embench' benchmark												)
	$(info																					)

header:
	$(info																)
	$(info =============================================================)
	$(info Project : KeyV												)
	$(info Authors : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>	)
	$(info Lab     : GRM - Polytechnique Montreal						)
	$(info Brief   : Software compilation (RV32IM)						)
	$(info Date    : $(DATE)											)
	$(info Bench   : $(BENCH)											)
	$(info =============================================================)
	$(info																)

#----------------------------------------------------------------------------
# SETTINGS
#----------------------------------------------------------------------------

RV_ENV_DIR		= $(KEYV_SW_EXT)/riscv-tests/env
RV_MACRO_DIR	= $(KEYV_SW_EXT)/riscv-tests/isa/macros/scalar
RV_BENCH_DIR	= $(KEYV_SW_EXT)/riscv-tests/benchmarks/common
RV_DEBUG_DIR	= $(KEYV_SW_EXT)/riscv-tests/debug/programs

FIRM_DIR		= $(KEYV_SW_FIRM)
BENCH_DIR		= $(KEYV_SW_BENCH)/$(BENCH)
CLEANDIRS		= $(FIRM_DIR) $(BENCH_DIR)

CC				= riscv32-unknown-elf-gcc
OBJCOPY			= riscv32-unknown-elf-objcopy
OBJDUMP			= riscv32-unknown-elf-objdump
OBJHEX			= $(KEYV_SCRIPTS)/hex.tcl

LD				= $(FIRM_DIR)/link.ld
STDLIB			= $(FIRM_DIR)/stdlib
CRT				= $(FIRM_DIR)/crt

BENCHMARK		= $(BENCH_DIR)/$(BENCH)
BENCH_HEX		= $(BENCHMARK)_mem.hex

ELFS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.elf))
DUMPS = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.dump))
HEXS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.hex))
MAPS  = $(foreach dir,$(CLEANDIRS),$(wildcard $(dir)/*.map))

#----------------------------------------------------------------------------
# TARGETS
#----------------------------------------------------------------------------
include $(BENCHMARK).mk

.PHONY : clean
.PRECIOUS: %.elf

compile: $(BENCHMARK).dump $(BENCHMARK).hex

%.dump : %.elf
	$(OBJDUMP) -D $< > $@

%.hex : %.elf
	$(OBJCOPY) -O verilog $< $@
	$(OBJHEX) $@ $(BENCH_HEX)

%.elf: $(OBJS) $(LD)
	$(CC) -Wl,-T,$(LD),-Map,$(BENCHMARK).map $(OBJS) -o $@ $(LDFLAGS)

clean:
	$(foreach f,$(ELFS),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(DUMPS),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(HEXS),$(if $(strip $(f)), rm $(f);))
	$(foreach f,$(MAPS),$(if $(strip $(f)), rm $(f);))
