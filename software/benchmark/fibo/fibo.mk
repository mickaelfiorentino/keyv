#-----------------------------------------------------------------------------
# Project  : KeyV
# File     : fibo.mk
# Author   : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
# Lab      : grm@polymtl
# Date     : <2020-02-26 Wed>
# Brief    : Fibonacci benchmark Makefile
#----------------------------------------------------------------------------

SRC_FILES = fibo.c
SRCS = $(addprefix $(BENCH_DIR)/,$(SRC_FILES))

OBJS:= $(CRT).o $(STDLIB).o $(SRCS:.c=.o)
INCLUDES := $(addprefix -I,$(FIRM_DIR))

CFLAGS  = -march=rv32im -O3 -Wall
LDFLAGS = -march=rv32im -static -nostartfiles

%.o : %.S
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@

%.o : %.c
	$(CC) -c $(INCLUDES) $(CFLAGS) $< -o $@
