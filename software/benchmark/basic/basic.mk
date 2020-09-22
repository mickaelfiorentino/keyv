#-----------------------------------------------------------------------------
# Project  : KeyV
# File     : basic.mk
# Author   : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab      : grm@polymtl
# Date     : <2020-02-26 Wed>
# Brief    : Unit test benchmark Makefile
#----------------------------------------------------------------------------

OBJS:= $(CRT).o $(BENCHMARK).o
INCLUDES := $(addprefix -I,$(RV_ENV_DIR) $(RV_MACRO_DIR))

CFLAGS  = -march=rv32im -O3 -Wall
LDFLAGS = -march=rv32im -static -nostartfiles

%.o : %.S
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@
