/*****************************************************************************
* Project : KeyV
* File    : fibo.c
* Author  : Mickael Fiorentino  <mickael.fiorentino@polymtl.ca>
* Company : grm@polymtl
* Date    : <2020-03-24 Tue>
* Brief   : Fibonacci benchmark: runs the first fibonacci iterations
*           Simple C program to test the toolchain and stdlib
******************************************************************************/

#include <string.h>
#include "fibo.h"

/******************************************************************************
 * MAIN
 *
 *   - Call fibonacci function
 *   - Measure performance using get_keyv_time() & get_keyv_insn() functions
 *   - Write results in iopad memory using print_pad from stdlib
 ******************************************************************************/
int main()
{
    // Start
    int start_time = get_keyv_time();
    int start_insn = get_keyv_insn();
    print_pad("%d%d", start_time, start_insn);

    // String manipulation
    const char *msg = "Fibonacci";
    print_pad("%s", msg);          // 46 69 62 6F 6E 61 63 63 69

    char *str = (char *) malloc(10 * sizeof(char));
    strcpy(str, "Fibonacci");

    int ok = (int) strcmp(str, msg);
    print_pad("%d", ~ok);          // FFFFFFFF

    // Fibonacci algorithm
    int *fibo = fibonacci(FIBO_LEN);
    for (int i=0; i<FIBO_LEN; i++) {
      print_pad("%d", fibo[i]);   // 0 1 2 3 5 8 D 15 22
    }

    // End
    int end_time = get_keyv_time();
    int end_insn = get_keyv_insn();
    print_pad("%d%d", (end_time - start_time), (end_insn - start_insn));

    return 0;
}

/******************************************************************************
 * FIBONACCI
 *
 *   - Simple fibonacci algorithm calculating the first 'idx' values
 *   - Return a pointer to a table containing fibonacci values
 *   - Uses malloc from stdlib
 ******************************************************************************/
int *fibonacci(const int idx)
{
    int *fibo = (int *) malloc(idx * sizeof(int));

    fibo[0] = 0;
    fibo[1] = 1;
    for (int i=2; i<idx; i++) {
      fibo[i] = fibo[i-1]+fibo[i-2];
    }

    return fibo;
}
