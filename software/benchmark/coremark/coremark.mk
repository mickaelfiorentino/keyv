#-----------------------------------------------------------------------------
# Project  : KeyV
# File     : coremark.mk
# Author   : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab      : grm@polymtl
# Date     : <2020-02-26 Wed>
# Brief    : Coremark benchmark Makefile
#----------------------------------------------------------------------------

ITERATIONS=1

CORE_FILES	 = core_main.c core_list_join.c core_matrix.c core_state.c core_util.c
PORT_FILES	 = core_portme.c
CORE_SRCS	 = $(addprefix $(BENCH_DIR)/,$(CORE_FILES))
PORT_SRCS	 = $(addprefix $(BENCH_DIR)/,$(PORT_FILES))

OBJS := $(CRT).o $(STDLIB).o $(CORE_SRCS:.c=.o) $(PORT_SRCS:.c=.o)
INCLUDES := $(addprefix -I,$(FIRM_DIR))

CFLAGS  = -march=rv32im -O3 -Wall -DITERATIONS=$(ITERATIONS)
LDFLAGS = -march=rv32im -static -nostartfiles

%.o : %.S
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@

%.o : %.c
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@

download:
	git clone --depth 1 --branch v1.01 https://github.com/eembc/coremark benchmark/.coremark
	rm -rf benchmark/.coremark/.git
