/*****************************************************************************
* Project: Key-V
* File   : crt.S
* Author : Mickaël FIORENTINO  <mickael.fiorentino@polymtl.ca>
* Lab    : grm@polymtl
* Date   : 2019-04-10
* Brief  : Generic code start and trap handling procedure
******************************************************************************/

#define CSR_MCAUSE_BREAK   3
#define CSR_MCAUSE_ILLEGAL 2
#define IOPAD_START        0x00010000

#define EXIT_TRAP(exit_code, exit_loop) \
    li t0, exit_code;                   \
    li t1, IOPAD_START;                 \
    sw t0, 0(t1);                       \
    j exit_loop;                        \

    .section .text
    .global start
    .global main

start:
    nop
    beqz sp,reset

machine_trap:
    csrr a0,mcause
    csrr a1,mepc
    li t0, CSR_MCAUSE_BREAK
    li t1, CSR_MCAUSE_ILLEGAL
    beq a0,t1,illegal
    beq a0,t0,break

unknown:
    EXIT_TRAP(3,forever);

illegal:
    EXIT_TRAP(2,forever);

break:
    EXIT_TRAP(1,forever);

reset:
    la sp, _stack_start
    jal main
    ebreak
    nop
    nop
    nop
    nop

forever:
    j forever
    nop
    nop
    nop
    nop
    nop
