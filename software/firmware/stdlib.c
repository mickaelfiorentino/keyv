/*****************************************************************************
* Project : KeyV
* File    : stdlib.c
* Author  : Mickael Fiorentino  <mickael.fiorentino@polymtl.ca>
* Lab     : grm@polymtl
* Date    : <2020-03-24 Tue>
* Brief   : stdlib adapted for KeyV
******************************************************************************/

#include "stdlib.h"

/******************************************************************************
 * PERFORMANCE COUNTERS
 *
 *   - get_time():
 *   - get_insn():
 ******************************************************************************/
int get_keyv_time()
{
    int cycles;
    asm("rdcycle %0" : "=r"(cycles));
    return cycles;
}

int get_keyv_insn()
{
    int insn;
    asm("rdinstret %0" : "=r"(insn));
    return insn;
}

/******************************************************************************
 * MALLOC:
 *
 *   Contiguous HEAP memory allocation: allocates a block of memory of size t,
 *   and returns a pointer to the first address of the block.
 *
 *   ebreak when the HEAP is full
 ******************************************************************************/
static size_t heap_used  = 0;
static size_t pad_used   = 0;
static size_t pad_align  = 0;

void *malloc(size_t t)
{
    size_t heap_align;
    size_t heap_block;

    heap_align = t % sizeof(int);
    heap_block = (heap_align > 0) ? t + sizeof(int) - heap_align : t;
    heap_used += heap_block;

    if (heap_used > HEAP_SIZE) {
        asm("ebreak");
    }

    void *p = (void *) (HEAP_START + heap_used - heap_block);
    return p;
}

void *palloc(size_t t)
{
    pad_used += t;

    if (t >= sizeof(int) && pad_align > 0) {
        pad_used += (sizeof(int) - pad_align);
    }

    if (pad_used > PAD_SIZE) {
        asm("ebreak");
    }

    pad_align = (pad_align < sizeof(int) - t) ? pad_align + t : 0;

    void *p = (void *) (PAD_START + pad_used - t);
    return p;
}

/******************************************************************************
 * PRINT_PAD
 *
 *   - print_pad():
 *   - print_c():
 *   - print_s():
 *   - print_d():
 ******************************************************************************/
static void print_c(char c)
{
    char *p = (char *) palloc(sizeof(char));
    *p = c;
}

static void print_s(char *s)
{
    while (*s) {
        print_c(*(s++));
    }
}

static void print_d(int d)
{
    int *p = (int *) palloc(sizeof(int));
    *p = d;
}

void print_pad(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);

    for (int i=0; format[i]; i++) {
        if (format[i] == '%') {
            i++;
            if (format[i] == 'c')
                print_c(va_arg(ap,int));

            if (format[i] == 's')
                print_s(va_arg(ap,char*));

            if (format[i] == 'd')
                print_d(va_arg(ap,int));

        } else {
            print_c(format[i]);
        }
    }
    va_end(ap);
}
