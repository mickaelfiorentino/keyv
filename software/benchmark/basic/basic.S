/*****************************************************************************
* Project : KeyV
* File    : basic.S
* Author  : Mickael Fiorentino  <mickael.fiorentino@polymtl.ca>
* Company : grm@polymtl
* Date    : <2019-04-11 Thu>
* Brief   : Basic instructions unit tests (from riscv)
******************************************************************************/

#define TEST_PASS 0x50 // 'P'
#define TEST_FAIL 0x46 // 'F'

/**************************************************************/
/*                            MACROS                          */
/**************************************************************/
/*  t0(x5)  : operand                                         */
/*  t1(x6)  : operand                                         */
/*  t2(x7)  : result                                          */
/*  a1(x11) : test number                                     */
/*  a2(x12) : correct value                                   */
/*  s2(x18) : address of next test                            */
/**************************************************************/

#define SEXT(x) ((x) | (-(((x) >> 11) & 1) << 11))

#define TEST_CASE( testnum, testreg, correctval,code... ) \
    test_ ## testnum:       \
    code;                   \
    li    a2, correctval;   \
    li    a1, testnum;      \
    auipc s2, 0;            \
    addi  s2, s2, 16;       \
    bne   testreg, a2, fail;\
    jal   pass;

#define DOUBLE_TEST( num, reg0, reg1, val0, val1, code... ) \
    test_ ## num:          \
    code                  ;\
    li    a2, val0        ;\
    li    a3, val1        ;\
    li    a1, num         ;\
    auipc s2, 0           ;\
    addi  s2, s2, 16      ;\
    bne   reg0, a2, fail  ;\
    jal   pass            ;\
    auipc s2, 0           ;\
    addi  s2, s2, 16      ;\
    bne   reg1, a3, fail  ;\
    jal   pass;

#define TEST_RR_OP( testnum, inst, result, val1, val2 ) \
    TEST_CASE                   \
    (                           \
        testnum, t2, result,    \
        li       t0, val1;      \
        li       t1, val2;      \
        inst     t2, t0, t1;    \
    )

#define TEST_IMM_OP( testnum, inst, result, val1, imm ) \
    TEST_CASE                   \
    (                           \
        testnum, t2, result,    \
        li   t0, val1;          \
        inst t2, t0, SEXT(imm); \
    )

#define TEST_BR_TAKEN( testnum, inst, val1, val2 ) \
    test_ ## testnum: \
    li    a1, testnum;      \
    li    t0, val1;         \
    li    t1, val2;         \
    auipc ra, 0 ;           \
    addi  ra, ra, 24;       \
    inst  t0, t1, pass;     \
    auipc s2, 0;            \
    addi  s2, s2, 12;       \
    j     fail;

#define TEST_BR_NOTTAKEN( testnum, inst, val1, val2 ) \
    test_ ## testnum: \
    li    a1, testnum;      \
    li    t0, val1;         \
    li    t1, val2;         \
    auipc s0, 0;            \
    addi  s0, s0, 16;       \
    inst  t0, t1, fail;     \
    jal   pass;


#define TEST_LSU_OP( testnum, load_inst, store_inst, result, offset, base ) \
    TEST_CASE( testnum, t2, result, \
      la  t0, base; \
      li  t1, result; \
      store_inst t1, offset(t0); \
      nop                      ; \
      nop                      ; \
      nop                      ; \
      load_inst t2, offset(t0);  \
    )

/**************************************************************/
/*                          PASS/FAIL                         */
/**************************************************************/

pass:
    li   s1, TEST_PASS
    sh   a1, 2(gp)
    sh   s1, 0(gp)
    addi gp, gp, 4
    ret

fail:
    li   s1, TEST_FAIL
    sh   a1, 2(gp)
    sh   s1, 0(gp)
    addi gp, gp, 4
    jr   s2
    nop
    nop
    nop
    nop
    nop

/**************************************************************/
/*                  PERFORMANCE COUNTERS                      */
/**************************************************************/

get_time:
    rdcycle a0
    ret

get_inst:
    rdinstret a0
    ret

/**************************************************************/
/*                            MAIN                            */
/**************************************************************/
.global main
main:

    // Init global pointer to PAD area
    la   gp, _iopad_start
    addi gp, gp, 4

/**************************************************************/
/*                    ARITHMETIC TESTS                        */
/**************************************************************/

    TEST_RR_OP( 1,  add, 0x80000000, 0x00000001, 0x7fffffff );
    TEST_RR_OP( 2,  add, 0x00000000, 0xffffffff, 0x00000001 );
    TEST_RR_OP( 3,  add, 0x80007ffe, 0x7fffffff, 0x00007fff );

    TEST_RR_OP( 4,  sub, 0x00000000, 0x00000001, 0x00000001 );
    TEST_RR_OP( 5,  sub, 0xfffffffc, 0x00000003, 0x00000007 );
    TEST_RR_OP( 6,  sub, 0x00000000, 0xffffffff, 0xffffffff );

    TEST_RR_OP( 7,  slt,  0, 0x00000001, 0xffffffff );
    TEST_RR_OP( 8,  slt,  1, 0xffffffff, 0x00000001 );

    TEST_RR_OP( 9,  sltu, 0, 0xffffffff, 0x00000001 );
    TEST_RR_OP( 10, sltu, 1, 0x00000001, 0xffffffff );

    TEST_RR_OP( 11, and, 0x000f000f, 0x00ff00ff, 0x0f0f0f0f );
    TEST_RR_OP( 12, or,  0x0fff0fff, 0x00ff00ff, 0x0f0f0f0f );
    TEST_RR_OP( 13, xor, 0x0ff00ff0, 0x00ff00ff, 0x0f0f0f0f );

    TEST_RR_OP( 14, sll, 0x90909080, 0x21212121, 7  );
    TEST_RR_OP( 15, sll, 0x00004000, 0x00000001, 14 );
    TEST_RR_OP( 16, sll, 0x42424242, 0x21212121, 0xffffffe1 );

    TEST_RR_OP( 17, srl, 0x01ffff00, 0xffff8000, 7  );
    TEST_RR_OP( 18, srl, 0x0003ffff, 0xffffffff, 14 );
    TEST_RR_OP( 19, srl, 0x10909090, 0x21212121, 0xffffffe1 );

    TEST_RR_OP( 20, sra, 0x00ffffff, 0x7fffffff, 7  );
    TEST_RR_OP( 21, sra, 0xfffe0606, 0x81818181, 14 );
    TEST_RR_OP( 22, sra, 0xff030303, 0x81818181, 0xffffffc7 );

    TEST_IMM_OP( 23, addi, 0x7ffff800, 0x80000000, 0x800 );
    TEST_IMM_OP( 24, addi, 0x800007fe, 0x7fffffff, 0x7ff );
    TEST_IMM_OP( 25, addi, 0xfffffffe, 0xffffffff, 0xfff );

    TEST_IMM_OP( 26, slti,  0, 0x00000001, 0xfff );
    TEST_IMM_OP( 27, slti,  1, 0xffffffff, 0x001 );

    TEST_IMM_OP( 28, sltiu, 0, 0xffffffff, 0x001 );
    TEST_IMM_OP( 29, sltiu, 1, 0x00000001, 0xfff );

    TEST_IMM_OP( 30, andi, 0x0000000f, 0x00ff00ff, 0x70f );
    TEST_IMM_OP( 31, ori,  0x00ff07ff, 0x00ff00ff, 0x70f );
    TEST_IMM_OP( 32, xori, 0x00ff0ff0, 0x00ff08ff, 0x70f );

    TEST_IMM_OP( 33, slli, 0xffffff80, 0xffffffff, 7  );
    TEST_IMM_OP( 34, slli, 0x48484000, 0x21212121, 14 );

    TEST_IMM_OP( 35, srli, 0x01ffffff, 0xffffffff, 7  );
    TEST_IMM_OP( 36, srli, 0x00008484, 0x21212121, 14 );

    TEST_IMM_OP( 37, srai, 0x0001ffff, 0x7fffffff, 14 );
    TEST_IMM_OP( 38, srai, 0xffffffff, 0x81818181, 31 );

    TEST_RR_OP( 39, mul   ,  21,  3,  7 );
    TEST_RR_OP( 40, mul   , -21, -3,  7 );
    TEST_RR_OP( 41, mul   ,  21, -3, -7 );
    TEST_RR_OP( 42, mul   , -21,  3, -7 );
    TEST_RR_OP( 43, mulhsu, 0xffff0081, 0xaaaaaaab, 0x0002fe7d );
    TEST_RR_OP( 44, mulhu , 0x0001fefe, 0xaaaaaaab, 0x0002fe7d );
    TEST_RR_OP( 45, mulh  , 0xffff0081, 0x0002fe7d, 0xaaaaaaab );

    TEST_RR_OP( 46, div,  1,  4,  3 );
    TEST_RR_OP( 47, rem,  1,  4,  3 );

    TEST_RR_OP( 48, div, -1,  -4,  3 );
    TEST_RR_OP( 49, rem, -1,  -4,  3 );

    TEST_RR_OP( 50, div, -1,   4, -3 );
    TEST_RR_OP( 51, rem,  1,   4, -3 );

    TEST_RR_OP( 52, div,   1, -4, -3 );
    TEST_RR_OP( 53, rem,  -1, -4, -3 );

    TEST_RR_OP( 54, div, -1<<31, -1<<31,  1 );
    TEST_RR_OP( 55, rem,  0    , -1<<31,  1 );

    TEST_RR_OP( 56, div, -1    , -1<<31,  0 );
    TEST_RR_OP( 57, rem, -1<<31, -1<<31,  0 );

    TEST_RR_OP( 58, div, -1<<31, -1<<31, -1 );
    TEST_RR_OP( 59, rem,  0    , -1<<31, -1 );

    TEST_RR_OP( 60, divu, 715827879, -20,  6 );
    TEST_RR_OP( 61, remu, 2        , -20,  6 );

    TEST_RR_OP( 62, divu,  0    , -1<<31, -1 );
    TEST_RR_OP( 63, remu, -1<<31, -1<<31, -1 );


/**************************************************************/
/*                      CONTROL TESTS                         */
/**************************************************************/

    TEST_BR_TAKEN( 64, beq,  1,  1 );
    TEST_BR_TAKEN( 65, beq, -1, -1 );

    TEST_BR_NOTTAKEN( 66, beq, -1,  1 );
    TEST_BR_NOTTAKEN( 67, beq,  1, -1 );

    TEST_BR_TAKEN( 68, bne, -1,  1 );
    TEST_BR_TAKEN( 69, bne,  1, -1 );

    TEST_BR_NOTTAKEN( 70, bne,  1,  1 );
    TEST_BR_NOTTAKEN( 71, bne, -1, -1 );

    TEST_BR_TAKEN( 72, blt, -1,  1 );
    TEST_BR_TAKEN( 73, blt, -2, -1 );

    TEST_BR_NOTTAKEN( 74, blt, -1, -2 );
    TEST_BR_NOTTAKEN( 75, blt,  1, -2 );

    TEST_BR_TAKEN( 76, bltu, 0xfffffffe, 0xffffffff );
    TEST_BR_NOTTAKEN( 77, bltu, 0xffffffff, 0xfffffffe );

    TEST_BR_TAKEN( 78, bge,  1,  0 );
    TEST_BR_TAKEN( 79, bge,  1, -1 );

    TEST_BR_NOTTAKEN( 80, bge, -2, -1 );
    TEST_BR_NOTTAKEN( 81, bge, -2,  1 );

    TEST_BR_TAKEN( 82, bgeu, 0xffffffff, 0xfffffffe );
    TEST_BR_NOTTAKEN( 83, bgeu, 0xfffffffe, 0xffffffff );


/**************************************************************/
/*                    LOAD/STORE TESTS                        */
/**************************************************************/

    TEST_LSU_OP( 84, lw, sw, 0x00aa00aa,  0,   dat  );
    TEST_LSU_OP( 85, lw, sw, 0xaa00aa00,  4,   dat  );
    TEST_LSU_OP( 86, lw, sw, 0xa00aa00a,  12,  dat  );
    TEST_LSU_OP( 87, lw, sw, 0x00aa00aa, -12,  dat8 );
    TEST_LSU_OP( 88, lw, sw, 0xaa00aa00, -8,   dat8 );
    TEST_LSU_OP( 90, lw, sw, 0xa00aa00a,  0,   dat8 );

    TEST_LSU_OP( 91, lh, sh, 0x000000aa,  0,   dat  );
    TEST_LSU_OP( 92, lh, sh, 0xffffaa00,  2,   dat  );
    TEST_LSU_OP( 93, lh, sh, 0xffffa00a,  6,   dat  );
    TEST_LSU_OP( 94, lh, sh, 0x000000aa, -6,   dat8 );
    TEST_LSU_OP( 95, lh, sh, 0x00000aa0, -2,   dat8 );
    TEST_LSU_OP( 96, lh, sh, 0xffffa00a,  0,   dat8 );

    TEST_LSU_OP(  97, lb, sb, 0xffffffaa,  0,   dat  );
    TEST_LSU_OP(  98, lb, sb, 0x00000000,  1,   dat  );
    TEST_LSU_OP(  99, lb, sb, 0x0000000a,  3,   dat  );
    TEST_LSU_OP( 100, lb, sb, 0xffffffaa, -3,   dat8 );
    TEST_LSU_OP( 101, lb, sb, 0xffffffa0, -1,   dat8 );
    TEST_LSU_OP( 102, lb, sb, 0x0000000a,  0,   dat8 );

/**************************************************************/
/*                      SPECIFIC TESTS                        */
/**************************************************************/

    // Multiple sw/lw in a row with dependencies
    TEST_CASE( 103, t3, 0x80000000, \
        li t0, 0x00000001;          \
        li t1, 0x00000002;          \
        li t2, 0x00000003;          \
        li t3, 0x7ffffffa;          \
        la a0, dat10;               \
        sw t0, 0(a0);               \
        sw t1, 4(a0);               \
        sw t2, 8(a0);               \
        sw t3, 12(a0);              \
        sw a0, 16(a0);              \
        addi a1, a0, 12;            \
        lw t0, 0(a1);               \
        lw t1, -4(a1);              \
        lw a1, 16(a0);              \
        lw t2, 8(a1);               \
        lw t3, 12(a1);              \
        add t1, t0, t1;             \
        add t2, t1, t2;             \
        add t3, t2, t3;             \
    )

    // Two multiplications in a row
    DOUBLE_TEST( 104, t3, t4, 21, 24, \
        li  t0, 7 ;                   \
        li  t1, 8 ;                   \
        li  t2, 3 ;                   \
        mul t3, t0, t2 ;              \
        mul t4, t1, t2 ;              \
    )

    // RF structural hazard with stall
    TEST_CASE( 105, t0, 0x00000000, \
        la a0, dat9;                \
        li t1, 0xdead;              \
        li t2, 0xbeef;              \
        li t0, 0xffff;              \
        lw t1, 0(a0);               \
        nop;                        \
        lw t2, 0(a0);               \
        sub t0, t2, t1;             \
    )

    // Performance Counters
    jal get_time
    mv s0, a0
    jal get_inst
    mv s1, a0
    jal get_time
    mv s2, a0

/**************************************************************/
/*                      END OF TESTS                          */
/**************************************************************/
    ebreak
    nop
    nop
    nop


/**************************************************************/
/*                          DATA                              */
/**************************************************************/

.data

dat  : .word 0xdeadbeef
dat1 : .word 0xcafedeca
dat2 : .word 0xfeedfeed
dat3 : .word 0xdeafdeaf
dat4 : .word 0xbeefdead
dat5 : .word 0xabcdabcd
dat6 : .word 0xaaaabbbb
dat7 : .word 0xccccdddd
dat8 : .word 0x11111111
dat9 : .word 0x88888888
dat10: .word 0x77777777
