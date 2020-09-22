/*****************************************************************************
* Project    : Key-V                                                           
* Description: RV32IM in-order KeyRing microarchitecture                       
******************************************************************************
* File       : stdlib.h
* Author     : Mickaël FIORENTINO  <mickael.fiorentino@polymtl.ca>             
* Company    : grm@polymtl                                                     
* Created    : 2019-04-10                                                      
* Last update: 2019-04-10                                                      
****************************************************************************** 
* Description: stdlib adapted for Key-V     
******************************************************************************/
#ifndef __KEYV_STDLIB_H
#define __KEYV_STDLIB_H

#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

#define HEAP_START  0x00008000
#define HEAP_SIZE   32768
#define PAD_START   0x00010004
#define PAD_SIZE    1024

int get_keyv_time();
int get_keyv_insn();
void *malloc (size_t t);
void *palloc(size_t t);
void print_pad(const char *format, ...);

#endif
