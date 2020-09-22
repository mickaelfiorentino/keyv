#-----------------------------------------------------------------------------
# Project  : KeyV
# File     : dhrystone.mk
# Author   : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab      : grm@polymtl
# Date     : <2020-02-26 Wed>
# Brief    : Dhrystone benchmark Makefile
#----------------------------------------------------------------------------

SRC_FILES = dhrystone_main.c dhrystone.c
SRCS = $(addprefix $(BENCH_DIR)/,$(SRC_FILES))

OBJS:= $(CRT).o $(STDLIB).o $(SRCS:.c=.o)
INCLUDES := $(addprefix -I,$(FIRM_DIR))

CFLAGS  = -march=rv32im -O3 -Wall -Wno-implicit-int -Wno-implicit-function-declaration -Wno-return-type
LDFLAGS = -march=rv32im -static -nostartfiles

%.o : %.S
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@

%.o : %.c
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@
