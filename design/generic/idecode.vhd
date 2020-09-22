-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : idecode.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Instruction Decoding
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity idecode is
  port (
    i_clk     : in  std_logic;
    i_rstn    : in  std_logic;
    i_idecode : in  keyv_to_idecode;
    o_idecode : out keyv_from_idecode);
end entity idecode;

architecture beh of idecode is

  signal imem  : std_logic_vector(XLEN-1 downto 0);
  signal I_imm : std_logic_vector(XLEN-1 downto 0);
  signal S_imm : std_logic_vector(XLEN-1 downto 0);
  signal B_imm : std_logic_vector(XLEN-1 downto 0);
  signal U_imm : std_logic_vector(XLEN-1 downto 0);
  signal J_imm : std_logic_vector(XLEN-1 downto 0);

  signal R_type, I_type, S_type, B_type, U_type, J_type : boolean;

  signal decode   : keyv_from_idecode;
  signal s_decode : keyv_from_idecode;

begin

  imem      <= i_idecode.imem;
  o_idecode <= s_decode;

  --------------------------------------------------------------------------------
  -- DECODE IMMEDIATE
  --------------------------------------------------------------------------------
  -- I-Immediate
  I_imm(IMM_I_SIGN_H downto IMM_I_SIGN_L) <= (others => imem(INST_SIGN_B));
  I_imm(IMM_I_IM12_H downto IMM_I_IM12_L) <= imem(INST_I_IM12_H downto INST_I_IM12_L);

  -- S-Immediate
  S_imm(IMM_S_SIGN_H downto IMM_S_SIGN_L) <= (others => imem(INST_SIGN_B));
  S_imm(IMM_S_IM7_H downto IMM_S_IM7_L)   <= imem(INST_S_IM7_H downto INST_S_IM7_L);
  S_imm(IMM_S_IM5_H downto IMM_S_IM5_L)   <= imem(INST_S_IM5_H downto INST_S_IM5_L);

  -- B-immediate
  B_imm(IMM_B_SIGN_H downto IMM_B_SIGN_L) <= (others => imem(INST_SIGN_B));
  B_imm(IMM_B_IM7_H downto IMM_B_IM7_L)   <= imem(INST_B_IM7_H downto INST_B_IM7_L);
  B_imm(IMM_B_IM4_H downto IMM_B_IM4_L)   <= imem(INST_B_IM4_H downto INST_B_IM4_L);
  B_imm(IMM_B_IM1_B)                      <= imem(INST_B_IM1_B);
  B_imm(IMM_B_ZERO_B)                     <= '0';

  -- U-immediate
  U_imm(IMM_U_SIGN_B)                     <= imem(INST_SIGN_B);
  U_imm(IMM_U_IM20_H downto IMM_U_IM20_L) <= imem(INST_U_IM20_H downto INST_U_IM20_L);
  U_imm(IMM_U_ZERO_H downto IMM_U_ZERO_L) <= (others => '0');

  -- J-immediate
  J_imm(IMM_J_SIGN_H downto IMM_J_SIGN_L) <= (others => imem(INST_SIGN_B));
  J_imm(IMM_J_IM10_H downto IMM_J_IM10_L) <= imem(INST_J_IM10_H downto INST_J_IM10_L);
  J_imm(IMM_J_IM8_H downto IMM_J_IM8_L)   <= imem(INST_J_IM8_H downto INST_J_IM8_L);
  J_imm(IMM_J_IM1_B)                      <= imem(INST_J_IM1_B);
  J_imm(IMM_J_ZERO_B)                     <= '0';

  --------------------------------------------------------------------------------
  -- DECODE INSTRUCTION
  --------------------------------------------------------------------------------
  decode.opcode <= imem(OPCODE_H downto OPCODE_L);
  decode.funct3 <= imem(FUNCT3_H downto FUNCT3_L);

  R_type <= decode.opcode = OP_OP;
  I_type <= decode.opcode = OP_IMM or
            decode.opcode = OP_JALR or
            decode.opcode = OP_LOAD or
            decode.opcode = OP_FENCE or
            decode.opcode = OP_SYSTEM;
  S_type <= decode.opcode = OP_STORE;
  B_type <= decode.opcode = OP_BRANCH;
  U_type <= decode.opcode = OP_LUI or
            decode.opcode = OP_AUIPC;
  J_type <= decode.opcode = OP_JAL;

  decode.rs1_addr <= imem(RS1_H downto RS1_L) when R_type or I_type or S_type or B_type else REG_X0;
  decode.rs2_addr <= imem(RS2_H downto RS2_L) when R_type or S_type or B_type           else REG_X0;
  decode.rd_addr  <= imem(RD_H downto RD_L)   when R_type or I_type or U_type or J_type else REG_X0;

  decode.shamt <= imem(SHAMT_H downto SHAMT_L);
  decode.csr   <= imem(CSR_H downto CSR_L);
  decode.B_imm <= B_imm;

  p_cmb : process(all)
  begin
    case decode.opcode is

      -- Register-Immediate
      when OP_IMM =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.imm    <= I_imm;
        case decode.funct3 is
          when FCT_ADDI  => decode.legal <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_ADD;
          when FCT_SLTI  => decode.legal <= '1'; decode.arith <= '1'; decode.sign <= "11"; decode.alu_op <= ALU_OP_SLT;
          when FCT_SLTIU => decode.legal <= '1'; decode.arith <= '1'; decode.sign <= "00"; decode.alu_op <= ALU_OP_SLT;
          when FCT_XORI  => decode.legal <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_XOR;
          when FCT_ORI   => decode.legal <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_OR;
          when FCT_ANDI  => decode.legal <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_AND;
          when FCT_SLLI  => decode.legal <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_SL;
          when FCT_SRI   => decode.legal <= '1'; decode.arith <= imem(INST_ARITH_B); decode.sign <= "11"; decode.alu_op <= ALU_OP_SR;
          when others    => decode.legal <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_OTHER;
        end case;

      -- Register-Register
      when OP_OP =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0';
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_R;
        decode.imm    <= I_imm;
        if imem(INST_MUL_B) = '1' then
          case decode.funct3 is
            when FCT_MUL    => decode.legal <= '1'; decode.mul <= '1'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_MUL;
            when FCT_MULH   => decode.legal <= '1'; decode.mul <= '1'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_MULH;
            when FCT_MULHSU => decode.legal <= '1'; decode.mul <= '1'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "01"; decode.alu_op <= ALU_OP_MULH;
            when FCT_MULHU  => decode.legal <= '1'; decode.mul <= '1'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "00"; decode.alu_op <= ALU_OP_MULH;
            when FCT_DIV    => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_DIV;
            when FCT_DIVU   => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '1'; decode.arith <= '0'; decode.sign <= "00"; decode.alu_op <= ALU_OP_DIV;
            when FCT_REM    => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '1'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_REM;
            when FCT_REMU   => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '1'; decode.arith <= '0'; decode.sign <= "00"; decode.alu_op <= ALU_OP_REM;
            when others     => decode.legal <= '0'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_OTHER;
          end case;
        else
          case decode.funct3 is
            when FCT_ADD  => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= imem(INST_ARITH_B); decode.sign <= "11"; decode.alu_op <= ALU_OP_ADD;
            when FCT_SLT  => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '1'; decode.sign <= "11"; decode.alu_op <= ALU_OP_SLT;
            when FCT_SLTU => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '1'; decode.sign <= "00"; decode.alu_op <= ALU_OP_SLT;
            when FCT_XOR  => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_XOR;
            when FCT_OR   => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_OR;
            when FCT_AND  => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_AND;
            when FCT_SLL  => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_SL;
            when FCT_SR   => decode.legal <= '1'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= imem(INST_ARITH_B); decode.sign <= "11"; decode.alu_op <= ALU_OP_SR;
            when others   => decode.legal <= '0'; decode.mul <= '0'; decode.div <= '0'; decode.arith <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_OTHER;
          end case;
        end if;

      -- LUI
      when OP_LUI =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.legal  <= '1'; decode.arith <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_OTHER;
        decode.imm    <= U_imm;

      -- AUIPC
      when OP_AUIPC =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.legal  <= '1'; decode.arith <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_PC;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_ADD;
        decode.imm    <= U_imm;

      -- Branch
      when OP_BRANCH =>
        decode.branch <= '1'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '0';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.arith <= '1'; decode.mul <= '0'; decode.div <= '0';
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_R;
        decode.imm    <= B_imm;
        case decode.funct3 is
          when FCT_BLT | FCT_BGE   => decode.legal <= '1'; decode.sign <= "11"; decode.alu_op <= ALU_OP_SLT;
          when FCT_BLTU | FCT_BGEU => decode.legal <= '1'; decode.sign <= "00"; decode.alu_op <= ALU_OP_SLT;
          when FCT_BEQ | FCT_BNE   => decode.legal <= '1'; decode.sign <= "11"; decode.alu_op <= ALU_OP_BEQ;
          when others              => decode.legal <= '0'; decode.sign <= "11"; decode.alu_op <= ALU_OP_OTHER;
        end case;

      -- Jump & Link
      when OP_JAL =>
        decode.branch <= '0'; decode.jump <= '1'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.legal  <= '1'; decode.arith <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_PC;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_ADD;
        decode.imm    <= J_imm;

      -- Jump & Link Register
      when OP_JALR =>
        decode.branch <= '0'; decode.jump <= '1'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.legal  <= '1'; decode.arith <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_ADD;
        decode.imm    <= I_imm;

      -- Load
      when OP_LOAD =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '1'; decode.store <= '0'; decode.wb <= '1';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.legal  <= '1'; decode.arith <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_ADD;
        decode.imm    <= I_imm;

      -- Store
      when OP_STORE =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '1'; decode.wb <= '0';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.legal  <= '1'; decode.arith <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_ADD;
        decode.imm    <= S_imm;

      -- System
      when OP_SYSTEM =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0';
        decode.fence  <= '0'; decode.sys <= '1'; decode.mul <= '0'; decode.div <= '0';
        decode.arith  <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_R;
        case decode.funct3 is
          when FCT_CSRRW  => decode.src2 <= SRC2_R; decode.wb <= '1'; decode.legal <= '1'; decode.csrwe <= '0';
          when FCT_CSRRWI => decode.src2 <= SRC2_IM; decode.wb <= '1'; decode.legal <= '1'; decode.csrwe <= '0';
          -- Write CSR only if rd =/= x0
          when FCT_CSRRS | FCT_CSRRC =>
            decode.src2 <= SRC2_R; decode.legal <= '1'; decode.wb <= '1';
            if decode.rs1_addr = REG_X0 then
              decode.csrwe <= '0';
            else
              decode.csrwe <= '1';
            end if;
          when FCT_CSRRSI | FCT_CSRRCI =>
            decode.src2 <= SRC2_IM; decode.legal <= '1'; decode.wb <= '1';
            if decode.rs1_addr = REG_X0 then
              decode.csrwe <= '0';
            else
              decode.csrwe <= '1';
            end if;
          when FCT_ECALL_EBREAK => decode.src2 <= SRC2_R; decode.wb <= '0'; decode.legal <= '1'; decode.csrwe <= '0';
          when others           => decode.src2 <= SRC2_R; decode.wb <= '0'; decode.legal <= '0'; decode.csrwe <= '0';
        end case;
        decode.imm    <= I_imm;
        decode.alu_op <= ALU_OP_OTHER;

      -- Fence
      when OP_FENCE =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '0';
        decode.sys    <= '1'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.arith  <= '0'; decode.sign <= "11";
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_OTHER;
        decode.imm    <= I_imm;
        -- Fence is a nop ; Fence.i is a pipeline flush
        case decode.funct3 is
          when FCT_FENCE  => decode.legal <= '1'; decode.fence <= '0';
          when FCT_FENCEI => decode.legal <= '1'; decode.fence <= '1';
          when others     => decode.legal <= '0'; decode.fence <= '0';
        end case;

      -- Illegal Instructions
      when others =>
        decode.branch <= '0'; decode.jump <= '0'; decode.load <= '0'; decode.store <= '0'; decode.wb <= '0';
        decode.fence  <= '0'; decode.sys <= '0'; decode.csrwe <= '0'; decode.mul <= '0'; decode.div <= '0';
        decode.arith  <= '0'; decode.sign <= "11"; decode.legal <= '0';
        decode.src1   <= SRC1_R;
        decode.src2   <= SRC2_IM;
        decode.alu_op <= ALU_OP_OTHER;
        decode.imm    <= I_imm;

    end case;
  end process p_cmb;

  --------------------------------------------------------------------------------
  -- SAVE STATE
  --------------------------------------------------------------------------------
  p_sync : process (i_clk, i_rstn)
  begin
    if i_rstn = '0' then
      s_decode <= init_idecode;
    elsif rising_edge(i_clk) then
      if i_idecode.stall = '0' then
        if i_idecode.flush = '1' then
          s_decode <= init_idecode;
        else
          s_decode <= decode;
        end if;
      end if;
    end if;
  end process p_sync;

end architecture beh;
