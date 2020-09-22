-------------------------------------------------------------------------------
-- Project : Key-V
-- File    : rv32_pkg.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-25
-- Brief   : Processors main parameters & RV32IM Instruction Set
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package rv32_pkg is

  ------------------------------------------------------------------------------
  --                            MAIN PARAMETERS
  ------------------------------------------------------------------------------
  constant XLEN      : positive := 32;
  constant BYTE_SIZE : positive := 8;
  constant BYTE_NB   : natural  := XLEN / BYTE_SIZE;
  constant BYTE_LSB  : natural  := integer(ceil(log2(real(BYTE_NB))));
  constant PC_INCR   : unsigned := to_unsigned(BYTE_NB, XLEN);
  constant JUMP_MASK : std_logic_vector(XLEN-1 downto 0) := X"FFFFFFFE";

  -- MEMORY
  --
  constant MEM_DEPTH      : positive := 16;  -- IMEM + DMEM = 64K (32K + 32K)
  constant PAD_DEPTH      : positive := 10;  -- PAD = 1K
  constant PAD_BIT_SELECT : positive := 16;  -- DMEM[18:2]
  constant RESET          : natural  := 16#00000000#;

  constant RESET_VECTOR : std_logic_vector(XLEN-1 downto 0) := std_logic_vector(to_unsigned(RESET, XLEN));
  constant PAD_START    : std_logic_vector(XLEN-1 downto 0) := x"00010000";
  constant PAD_END      : std_logic_vector(XLEN-1 downto 0) := x"00010400";

  -- Register File
  --
  constant REG_WIDTH : positive  := 5;
  constant REG_NB    : positive  := 2**REG_WIDTH;
  constant SRC1_R    : std_logic := '0';
  constant SRC1_PC   : std_logic := '1';
  constant SRC2_R    : std_logic := '0';
  constant SRC2_IM   : std_logic := '1';
  constant REG_X0    : std_logic_vector(REG_WIDTH-1 downto 0) := "00000";

  constant PERFCOUNT_WIDTH : positive := 64;

  ------------------------------------------------------------------------------
  --                            INTRUCTIONS FORMATS
  ------------------------------------------------------------------------------
  -- Field Boundaries
  constant OPCODE_H       : natural := 6;
  constant OPCODE_L       : natural := 0;
  constant FUNCT7_H       : natural := 31;
  constant FUNCT7_L       : natural := 25;
  constant FUNCT3_H       : natural := 14;
  constant FUNCT3_L       : natural := 12;
  constant RS1_H          : natural := 19;
  constant RS1_L          : natural := 15;
  constant RS2_H          : natural := 24;
  constant RS2_L          : natural := 20;
  constant RD_H           : natural := 11;
  constant RD_L           : natural := 7;
  constant SHAMT_H        : natural := 24;
  constant SHAMT_L        : natural := 20;
  constant SIGN_B         : natural := 31;
  -- I-Type Immediates
  constant INST_I_IM12_H  : natural := 30;
  constant INST_I_IM12_L  : natural := 20;
  constant INST_I_SHAMT_H : natural := 24;
  constant INST_I_SHAMT_L : natural := 20;
  -- S-Type Immediates
  constant INST_S_IM7_H   : natural := 30;
  constant INST_S_IM7_L   : natural := 25;
  constant INST_S_IM5_H   : natural := 11;
  constant INST_S_IM5_L   : natural := 7;
  -- SB-Type Immediates
  constant INST_B_IM7_H   : natural := 30;
  constant INST_B_IM7_L   : natural := 25;
  constant INST_B_IM4_H   : natural := 11;
  constant INST_B_IM4_L   : natural := 8;
  constant INST_B_IM1_B   : natural := 7;
  -- U-Type Immediates
  constant INST_U_IM20_H  : natural := 30;
  constant INST_U_IM20_L  : natural := 12;
  -- UJ-Type Immediates
  constant INST_J_IM10_H  : natural := 30;
  constant INST_J_IM10_L  : natural := 21;
  constant INST_J_IM8_H   : natural := 19;
  constant INST_J_IM8_L   : natural := 12;
  constant INST_J_IM1_B   : natural := 20;
  -- Arith/Logic
  constant INST_ARITH_B   : natural := 30;
  -- Mul/Div
  constant INST_MUL_B     : natural := 25;
  -- Sign
  constant INST_SIGN_B    : natural := 31;
  -- CSR
  constant CSR_H          : natural := 31;
  constant CSR_L          : natural := 20;
  -- Field widths
  constant OPCODE_WIDTH   : natural := OPCODE_H-OPCODE_L+1;
  constant FUNCT7_WIDTH   : natural := FUNCT7_H-FUNCT7_L+1;
  constant FUNCT3_WIDTH   : natural := FUNCT3_H-FUNCT3_L+1;
  constant SHAMT_WIDTH    : natural := SHAMT_H-SHAMT_L+1;
  constant CSR_WIDTH      : natural := CSR_H-CSR_L+1;

  ------------------------------------------------------------------------------
  --                             IMMEDIATE FORMAT
  ------------------------------------------------------------------------------
  -- I-immediate
  constant IMM_I_SIGN_H : natural := 31;
  constant IMM_I_SIGN_L : natural := 11;
  constant IMM_I_IM12_H : natural := 10;
  constant IMM_I_IM12_L : natural := 0;
  constant IMM_I_WIDTH  : natural := 12;
  -- S-immediate
  constant IMM_S_SIGN_H : natural := 31;
  constant IMM_S_SIGN_L : natural := 11;
  constant IMM_S_IM7_H  : natural := 10;
  constant IMM_S_IM7_L  : natural := 5;
  constant IMM_S_IM5_H  : natural := 4;
  constant IMM_S_IM5_L  : natural := 0;
  constant IMM_S_WIDTH  : natural := 12;
  -- B-immediate
  constant IMM_B_SIGN_H : natural := 31;
  constant IMM_B_SIGN_L : natural := 12;
  constant IMM_B_IM7_H  : natural := 10;
  constant IMM_B_IM7_L  : natural := 5;
  constant IMM_B_IM4_H  : natural := 4;
  constant IMM_B_IM4_L  : natural := 1;
  constant IMM_B_IM1_B  : natural := 11;
  constant IMM_B_ZERO_B : natural := 0;
  constant IMM_B_WIDTH  : natural := 12;
  -- U-immediate
  constant IMM_U_SIGN_B : natural := 31;
  constant IMM_U_IM20_H : natural := 30;
  constant IMM_U_IM20_L : natural := 12;
  constant IMM_U_ZERO_H : natural := 11;
  constant IMM_U_ZERO_L : natural := 0;
  constant IMM_U_WIDTH  : natural := 20;
  -- J-immediate
  constant IMM_J_SIGN_H : natural := 31;
  constant IMM_J_SIGN_L : natural := 20;
  constant IMM_J_IM10_H : natural := 10;
  constant IMM_J_IM10_L : natural := 1;
  constant IMM_J_IM8_H  : natural := 19;
  constant IMM_J_IM8_L  : natural := 12;
  constant IMM_J_IM1_B  : natural := 11;
  constant IMM_J_ZERO_B : natural := 0;
  constant IMM_J_WIDTH  : natural := 20;

  ------------------------------------------------------------------------------
  --                             INSTRUCTIONS CODES
  ------------------------------------------------------------------------------
  -- Opcodes
  constant OP_IMM           : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0010011";
  constant OP_OP            : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0110011";
  constant OP_BRANCH        : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "1100011";
  constant OP_LOAD          : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0000011";
  constant OP_STORE         : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0100011";
  constant OP_FENCE         : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0001111";
  constant OP_SYSTEM        : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "1110011";
  constant OP_JAL           : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "1101111";
  constant OP_JALR          : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "1100111";
  constant OP_LUI           : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0110111";
  constant OP_AUIPC         : std_logic_vector(OPCODE_WIDTH-1 downto 0) := "0010111";
  -- Register-Immediate
  constant FCT_ADDI         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_SLTI         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "010";
  constant FCT_SLTIU        : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "011";
  constant FCT_XORI         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "100";
  constant FCT_ORI          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "110";
  constant FCT_ANDI         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "111";
  constant FCT_SLLI         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_SRI          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "101";
  -- Register-Register
  constant FCT_ADD          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_SLT          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "010";
  constant FCT_SLTU         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "011";
  constant FCT_XOR          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "100";
  constant FCT_OR           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "110";
  constant FCT_AND          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "111";
  constant FCT_SLL          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_SR           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "101";
  constant FCT_MUL          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_MULH         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_MULHSU       : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "010";
  constant FCT_MULHU        : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "011";
  constant FCT_DIV          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "100";
  constant FCT_DIVU         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "101";
  constant FCT_REM          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "110";
  constant FCT_REMU         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "111";
  -- Control Transfert
  constant FCT_BEQ          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_BNE          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_BLT          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "100";
  constant FCT_BLTU         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "110";
  constant FCT_BGE          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "101";
  constant FCT_BGEU         : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "111";
  -- Load / Store
  constant FCT_LB           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_LBU          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "100";
  constant FCT_LH           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_LHU          : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "101";
  constant FCT_LW           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "010";
  constant FCT_SB           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_SH           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_SW           : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "010";
  -- Fence
  constant FCT_FENCE        : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  constant FCT_FENCEI       : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  -- Call & Breakpoint
  constant FN_ECALL         : std_logic_vector(CSR_WIDTH-1 downto 0)    := "000000000000";
  constant FN_EBREAK        : std_logic_vector(CSR_WIDTH-1 downto 0)    := "000000000001";
  constant FCT_ECALL_EBREAK : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "000";
  -- CSR
  constant FCT_CSRRW        : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "001";
  constant FCT_CSRRWI       : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "101";
  constant FCT_CSRRS        : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "010";
  constant FCT_CSRRSI       : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "110";
  constant FCT_CSRRC        : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "011";
  constant FCT_CSRRCI       : std_logic_vector(FUNCT3_WIDTH-1 downto 0) := "111";

  constant CSR_MCYCLE         : std_logic_vector(CSR_WIDTH-1 downto 0) := x"C00";
  constant CSR_MCYCLEH        : std_logic_vector(CSR_WIDTH-1 downto 0) := x"C80";
  constant CSR_MINSTRET       : std_logic_vector(CSR_WIDTH-1 downto 0) := x"C02";
  constant CSR_MINSTRETH      : std_logic_vector(CSR_WIDTH-1 downto 0) := x"C82";
  constant CSR_MEPC           : std_logic_vector(CSR_WIDTH-1 downto 0) := x"341";
  constant CSR_MCAUSE         : std_logic_vector(CSR_WIDTH-1 downto 0) := x"342";
  constant CSR_MCAUSE_ILLEGAL : natural                                := 2;
  constant CSR_MCAUSE_BREAK   : natural                                := 3;

  -- NOP INSTRUCTION (ADDI X0 X0 X0)
  constant IMEM_NOP_INST : std_logic_vector(XLEN-1 downto 0) :=
    X"000" & REG_X0 & FCT_ADDI & REG_X0 & OP_IMM;

  -- ALU Op
  constant ALU_OP_WIDTH : natural                                   := 4;
  constant ALU_OP_ADD   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0000";
  constant ALU_OP_SLT   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0010";
  constant ALU_OP_BEQ   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0011";
  constant ALU_OP_SL    : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0001";
  constant ALU_OP_SR    : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0101";
  constant ALU_OP_XOR   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0100";
  constant ALU_OP_OR    : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0110";
  constant ALU_OP_AND   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "0111";
  constant ALU_OP_MUL   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "1000";
  constant ALU_OP_MULH  : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "1001";
  constant ALU_OP_DIV   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "1100";
  constant ALU_OP_REM   : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "1110";
  constant ALU_OP_OTHER : std_logic_vector(ALU_OP_WIDTH-1 downto 0) := "1111";

  ------------------------------------------------------------------------------
  --                             PROGRAM COUNTER
  ------------------------------------------------------------------------------
  type keyv_to_pc is record
    stall  : std_logic;
    jump   : std_logic;
    branch : std_logic;
    sys    : std_logic;
    origin : std_logic_vector(XLEN-1 downto 0);
    target : std_logic_vector(XLEN-1 downto 0);
  end record keyv_to_pc;

  type keyv_from_pc is record
    pc         : std_logic_vector(XLEN-1 downto 0);
    invalidate : std_logic;
  end record keyv_from_pc;

  component pc is
    port (
      i_clk  : in  std_logic;
      i_rstn : in  std_logic;
      i_pc   : in  keyv_to_pc;
      o_pc   : out keyv_from_pc);
  end component pc;

  function init_pc return keyv_from_pc;

  ------------------------------------------------------------------------------
  --                                IDECODE
  ------------------------------------------------------------------------------
  type keyv_to_idecode is record
    flush : std_logic;
    stall : std_logic;
    imem  : std_logic_vector(XLEN-1 downto 0);
  end record keyv_to_idecode;

  type keyv_from_idecode is record
    opcode   : std_logic_vector(OPCODE_WIDTH-1 downto 0);
    funct3   : std_logic_vector(FUNCT3_WIDTH-1 downto 0);
    alu_op   : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
    rs1_addr : std_logic_vector(REG_WIDTH-1 downto 0);
    rs2_addr : std_logic_vector(REG_WIDTH-1 downto 0);
    rd_addr  : std_logic_vector(REG_WIDTH-1 downto 0);
    shamt    : std_logic_vector(SHAMT_WIDTH-1 downto 0);
    csr      : std_logic_vector(CSR_WIDTH-1 downto 0);
    imm      : std_logic_vector(XLEN-1 downto 0);
    B_imm    : std_logic_vector(XLEN-1 downto 0);
    sign     : std_logic_vector(1 downto 0);
    legal    : std_logic;
    arith    : std_logic;
    mul      : std_logic;
    div      : std_logic;
    src1     : std_logic;
    src2     : std_logic;
    csrwe    : std_logic;
    branch   : std_logic;
    jump     : std_logic;
    load     : std_logic;
    store    : std_logic;
    wb       : std_logic;
    fence    : std_logic;
    sys      : std_logic;
  end record keyv_from_idecode;

  component idecode is
    port (
      i_clk     : in  std_logic;
      i_rstn    : in  std_logic;
      i_idecode : in  keyv_to_idecode;
      o_idecode : out keyv_from_idecode);
  end component idecode;

  function init_idecode return keyv_from_idecode;

  ------------------------------------------------------------------------------
  --                             REGISTER FILE
  ------------------------------------------------------------------------------
  type keyv_to_rf is record
    addr_a : std_logic_vector(REG_WIDTH-1 downto 0);
    addr_b : std_logic_vector(REG_WIDTH-1 downto 0);
    en     : std_logic;
    we     : std_logic;
    addr_w : std_logic_vector(REG_WIDTH-1 downto 0);
    data_w : std_logic_vector(XLEN-1 downto 0);
  end record keyv_to_rf;

  type keyv_from_rf is record
    data_a : std_logic_vector(XLEN-1 downto 0);
    data_b : std_logic_vector(XLEN-1 downto 0);
  end record keyv_from_rf;

  component rf is
    port (
      i_clk  : in  std_logic;
      i_rstn : in  std_logic;
      i_rf   : in  keyv_to_rf;
      o_rf   : out keyv_from_rf);
  end component rf;

  ------------------------------------------------------------------------------
  --                           BRANCH PREDICTOR                               --
  ------------------------------------------------------------------------------
  type keyv_to_bp is record
    opcode    : std_logic_vector(FUNCT3_WIDTH-1 downto 0);
    branch    : std_logic;
    condition : std_logic;
  end record keyv_to_bp;

  type keyv_from_bp is record
    predict : std_logic;
    taken   : std_logic;
  end record keyv_from_bp;

  component bp is
    port (
      i_clk  : in  std_logic;
      i_rstn : in  std_logic;
      i_bp   : in  keyv_to_bp;
      o_bp   : out keyv_from_bp);
  end component bp;

  ------------------------------------------------------------------------------
  --                             PERFORMANCE COUNTERS
  ------------------------------------------------------------------------------
  type keyv_to_perf is record
    stall : std_logic;
  end record keyv_to_perf;

  type keyv_from_perf is record
    cycle   : std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);
    instret : std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);
  end record keyv_from_perf;

  component perf is
    port (
      i_clk_c : in  std_logic;
      i_clk_i : in  std_logic;
      i_rstn  : in  std_logic;
      i_perf  : in  keyv_to_perf;
      o_perf  : out keyv_from_perf);
  end component perf;

  ------------------------------------------------------------------------------
  --                                 SYSTEM
  ------------------------------------------------------------------------------
  type keyv_to_sys is record
    stall    : std_logic;
    sys      : std_logic;
    legal    : std_logic;
    fence    : std_logic;
    csrwe    : std_logic;
    csrsel   : std_logic_vector(CSR_WIDTH-1 downto 0);
    csrfunct : std_logic_vector(FUNCT3_WIDTH-1 downto 0);
    pc       : std_logic_vector(XLEN-1 downto 0);
    rs1      : std_logic_vector(XLEN-1 downto 0);
  end record keyv_to_sys;

  type keyv_from_sys is record
    invalidate : std_logic;
    pc         : std_logic_vector(XLEN-1 downto 0);
    rd         : std_logic_vector(XLEN-1 downto 0);
  end record keyv_from_sys;

  component sys is
    port (
      i_clk     : in  std_logic;
      i_rstn    : in  std_logic;
      i_cycle   : in  std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);
      i_instret : in  std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);
      i_sys     : in  keyv_to_sys;
      o_sys     : out keyv_from_sys);
  end component sys;

  ------------------------------------------------------------------------------
  --                             LOAD STORE UNIT
  ------------------------------------------------------------------------------
  type keyv_to_lsu is record
    load      : std_logic;
    store     : std_logic;
    funct     : std_logic_vector(FUNCT3_WIDTH-1 downto 0);
    base_addr : std_logic_vector(XLEN-1 downto 0);
    base_data : std_logic_vector(XLEN-1 downto 0);
  end record keyv_to_lsu;

  type keyv_from_lsu is record
    mem_en    : std_logic;
    mem_we    : std_logic_vector(BYTE_NB-1 downto 0);
    mem_addr  : std_logic_vector(XLEN-1 downto 0);
    mem_write : std_logic_vector(XLEN-1 downto 0);
    mem_read  : std_logic_vector(XLEN-1 downto 0);
  end record keyv_from_lsu;

  component lsu is
    port (
      i_clk  : in  std_logic;
      i_rstn : in  std_logic;
      i_dmem : in  std_logic_vector(XLEN-1 downto 0);
      i_lsu  : in  keyv_to_lsu;
      o_lsu  : out keyv_from_lsu);
  end component lsu;

  ------------------------------------------------------------------------------
  --                            SYNCHRONIZER
  ------------------------------------------------------------------------------
  component sync is
    generic (
      N : positive);
    port (
      i_rstn   : in  std_logic;
      i_clk_p  : in  std_logic;
      i_data_p : in  std_logic_vector(N-1 downto 0);
      i_clk_c  : in  std_logic;
      o_data_c : out std_logic_vector(N-1 downto 0));
  end component sync;

end package rv32_pkg;
package body rv32_pkg is

  --------------------------------------------------------------------------------
  --                               INIT PC
  --------------------------------------------------------------------------------
  function init_pc return keyv_from_pc is
    variable pc : keyv_from_pc;
  begin
    pc.pc         := RESET_VECTOR;
    pc.invalidate := '0';
    return pc;
  end function init_pc;

  --------------------------------------------------------------------------------
  --                              INIT IDECODE
  --------------------------------------------------------------------------------
  function init_idecode return keyv_from_idecode is
    variable decode : keyv_from_idecode;
  begin
    decode.opcode   := OP_IMM;
    decode.funct3   := FCT_ADDI;
    decode.alu_op   := ALU_OP_ADD;
    decode.rs1_addr := REG_X0;
    decode.rs2_addr := REG_X0;
    decode.rd_addr  := REG_X0;
    decode.shamt    := (others => '0');
    decode.csr      := (others => '0');
    decode.imm      := (others => '0');
    decode.B_imm    := (others => '0');
    decode.sign     := "00";
    decode.legal    := '1';
    decode.arith    := '0';
    decode.mul      := '0';
    decode.div      := '0';
    decode.src1     := '0';
    decode.src2     := '0';
    decode.csrwe    := '0';
    decode.branch   := '0';
    decode.jump     := '0';
    decode.load     := '0';
    decode.store    := '0';
    decode.wb       := '0';
    decode.fence    := '0';
    decode.sys      := '0';
    return decode;
  end function init_idecode;

end package body rv32_pkg;
