-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : xu.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Execution Unit
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.utils_pkg.all;
use work.keyv_pkg.all;

entity xu is
  generic (
    ID : natural := 0);
  port (
    i_rstn : in  std_logic;
    i_clks : in  keyv_logic_v;
    i_xu   : in  keyv_to_xu;
    o_xu   : out keyv_from_xu);
end entity xu;

architecture beh of xu is

  -- Clocks
  alias F_clk : std_logic is i_clks(keyv_clk'pos(F));
  alias D_clk : std_logic is i_clks(keyv_clk'pos(D));
  alias R_clk : std_logic is i_clks(keyv_clk'pos(R));
  alias E_clk : std_logic is i_clks(keyv_clk'pos(E));
  alias M_clk : std_logic is i_clks(keyv_clk'pos(M));
  alias W_clk : std_logic is i_clks(keyv_clk'pos(W));

  -- F Stage
  signal F_pc     : keyv_from_pc;

  -- D Stage
  signal D_imem    : std_logic_vector(XLEN-1 downto 0);
  signal D_pc      : keyv_from_pc;
  signal D_decode  : keyv_from_idecode;

  -- R Stage
  signal R_pc      : keyv_from_pc;
  signal R_fwd_a   : keyv_fwd_xu;
  signal R_fwd_b   : keyv_fwd_xu;
  signal R_mul     : std_logic;
  signal R_div     : std_logic;

  -- E Stage
  signal E_pc           : keyv_from_pc;
  signal E_idecode      : keyv_from_idecode;
  signal E_branch_taken : std_logic;
  signal E_sys          : std_logic_vector(XLEN-1 downto 0);
  signal E_store        : std_logic_vector(XLEN-1 downto 0);
  signal E_ready        : std_logic;
  signal E_flush_out    : std_logic;

  -- M Stage
  signal M_idecode    : keyv_from_idecode;
  signal M_alu_result : std_logic_vector(XLEN-1 downto 0);
  signal M_pc_target  : std_logic_vector(XLEN-1 downto 0);
  signal M_ra         : std_logic_vector(XLEN-1 downto 0);
  signal M_sys        : std_logic_vector(XLEN-1 downto 0);
  signal M_pc_branch  : std_logic;
  signal M_pc_sys     : std_logic;
  signal M_flushed    : std_logic;
  signal M_flush_out  : std_logic;
  signal M_mul        : std_logic;
  signal M_div        : std_logic;

  -- W Stage
  signal W_load : std_logic_vector(XLEN-1 downto 0);

  -- Stalls
  signal data_ready : std_logic;
  signal R_ready    : std_logic;
  signal M_ready    : std_logic;
  signal W_ready    : std_logic;

begin

  ------------------------------------------------------------------------------
  -- MODULES INTERFACES
  ------------------------------------------------------------------------------

  -- PC
  o_xu.to_pc.stall  <= '0';
  o_xu.to_pc.jump   <= M_idecode.jump;
  o_xu.to_pc.branch <= M_pc_branch;
  o_xu.to_pc.sys    <= M_pc_sys;
  o_xu.to_pc.target <= M_pc_target;
  o_xu.to_pc.origin <= F_pc.pc;

  -- IDECODE
  o_xu.to_idecode.imem  <= D_imem;
  o_xu.to_idecode.flush <= '0';
  o_xu.to_idecode.stall <= '0';

  -- RF (Read @R, Write @R-next-cycle)
  o_xu.to_rf.en     <= '1';
  o_xu.to_rf.addr_a <= D_decode.rs1_addr;
  o_xu.to_rf.addr_b <= D_decode.rs2_addr;

  o_xu.to_rf.we <= D_decode.wb when R_ready /= M_ready else
                   M_idecode.wb;

  o_xu.to_rf.addr_w <= D_decode.rd_addr when R_ready /= M_ready else
                       M_idecode.rd_addr;

  o_xu.to_rf.data_w <= M_ra   when M_idecode.jump = '1' else
                       M_sys  when M_idecode.sys  = '1' else
                       W_load when M_idecode.load = '1' else
                       i_xu.from_alu.port_z when M_ready /= E_ready else
                       M_alu_result;

  -- ALU
  o_xu.to_alu.fwd_a <= R_fwd_a;
  o_xu.to_alu.fwd_b <= R_fwd_b;
  o_xu.to_alu.pc    <= R_pc.pc;
  o_xu.to_alu.mul   <= R_mul xor M_mul;
  o_xu.to_alu.div   <= R_div xor M_div;

  -- PERF
  o_xu.to_perf.stall <= i_xu.flush;

  -- SYS
  o_xu.to_sys.stall    <= '0';
  o_xu.to_sys.sys      <= E_idecode.sys and not(i_xu.flush);
  o_xu.to_sys.legal    <= E_idecode.legal;
  o_xu.to_sys.fence    <= E_idecode.fence;
  o_xu.to_sys.csrwe    <= E_idecode.csrwe;
  o_xu.to_sys.csrsel   <= E_idecode.csr;
  o_xu.to_sys.csrfunct <= E_idecode.funct3;
  o_xu.to_sys.pc       <= E_pc.pc;
  o_xu.to_sys.rs1      <= E_sys;

  -- LSU
  o_xu.to_lsu.load      <= E_idecode.load;
  o_xu.to_lsu.store     <= E_idecode.store and not(i_xu.flush);
  o_xu.to_lsu.funct     <= E_idecode.funct3;
  o_xu.to_lsu.base_addr <= i_xu.from_alu.port_z;
  o_xu.to_lsu.base_data <= E_store;

  -- FLUSH
  --   flush   : This XU is flushing others
  --   flushed : This XU was flushed @previous cycle and shall not be flushed @this cycle
  o_xu.flush   <= M_flush_out;
  o_xu.flushed <= M_flushed and i_xu.flush;

  -- STALLS
  o_xu.busy  <= (R_ready xor data_ready) and D_decode.wb and not(D_decode.jump);
  data_ready <= W_ready;

  ------------------------------------------------------------------------------
  -- F STAGE
  ------------------------------------------------------------------------------
  stage_F : process(F_clk, i_rstn)
  begin
    if i_rstn = '0' then
      F_pc <= init_pc;
    elsif rising_edge(F_clk) then
      F_pc <= i_xu.from_pc;
    end if;
  end process stage_F;

  ------------------------------------------------------------------------------
  -- D STAGE
  ------------------------------------------------------------------------------
  stage_D : process(D_clk, i_rstn)
    variable opcode : std_logic_vector(OPCODE_WIDTH-1 downto 0);
    variable funct  : std_logic_vector(FUNCT3_WIDTH-1 downto 0);
  begin
    if i_rstn = '0' then
      D_imem    <= IMEM_NOP_INST;
      D_pc      <= init_pc;
      D_decode  <= init_idecode;
    elsif rising_edge(D_clk) then
      D_imem    <= i_xu.imem;
      D_pc      <= F_pc;
      --
      -- Early decode required for forwarding + stalls
      opcode := i_xu.imem(OPCODE_H downto OPCODE_L);
      funct  := i_xu.imem(FUNCT3_H downto FUNCT3_L);
      -- RS1
      case opcode is
        when OP_OP | OP_IMM | OP_JALR | OP_LOAD | OP_FENCE | OP_SYSTEM | OP_STORE | OP_BRANCH =>
          D_decode.rs1_addr <= i_xu.imem(RS1_H downto RS1_L);
        when others =>
          D_decode.rs1_addr <= REG_X0;
      end case;
      -- RS2
      case opcode is
        when OP_OP | OP_STORE | OP_BRANCH =>
          D_decode.rs2_addr <= i_xu.imem(RS2_H downto RS2_L);
        when others =>
          D_decode.rs2_addr <= REG_X0;
      end case;
      -- RD
      case opcode is
        when OP_OP | OP_IMM | OP_JALR | OP_LOAD | OP_FENCE | OP_SYSTEM | OP_LUI | OP_AUIPC | OP_JAL =>
          D_decode.rd_addr <= i_xu.imem(RD_H downto RD_L);
        when others =>
          D_decode.rd_addr <= REG_X0;
      end case;
      -- JUMP
      case opcode is
        when OP_JAL | OP_JALR =>
          D_decode.jump <= '1';
        when others =>
          D_decode.jump <= '0';
      end case;
      -- WB
      case opcode is
        when OP_OP | OP_IMM | OP_LUI | OP_AUIPC | OP_JAL | OP_JALR | OP_LOAD =>
          D_decode.wb <= '1';
        when OP_SYSTEM =>
          case funct is
            when FCT_CSRRW | FCT_CSRRWI | FCT_CSRRS | FCT_CSRRC | FCT_CSRRSI | FCT_CSRRCI =>
              D_decode.wb <= '1';
            when others =>
              D_decode.wb <= '0';
          end case;
        when others =>
          D_decode.wb <= '0';
      end case;
      -- MUL / DIV
      if i_xu.imem(INST_MUL_B) = '1' then
        case opcode is
          when OP_OP =>
            case funct is
              when FCT_MUL | FCT_MULH | FCT_MULHSU | FCT_MULHU =>
                D_decode.mul <= '1'; D_decode.div <= '0';
              when FCT_DIV | FCT_DIVU | FCT_REM | FCT_REMU =>
                D_decode.mul <= '0'; D_decode.div <= '1';
              when others =>
                D_decode.mul <= '0'; D_decode.div <= '0';
            end case;
          when others =>
            D_decode.mul <= '0'; D_decode.div <= '0';
        end case;
      else
        D_decode.mul <= '0'; D_decode.div <= '0';
      end if;
    end if;
  end process stage_D;

  ------------------------------------------------------------------------------
  -- R STAGE
  ------------------------------------------------------------------------------
  stage_R : process(R_clk, i_rstn)
  begin
    if i_rstn = '0' then
      R_ready <= '0';
      R_mul   <= '0';
      R_div   <= '0';
      R_pc    <= init_pc;
      R_fwd_a <= init_fwd;
      R_fwd_b <= init_fwd;
    elsif rising_edge(R_clk) then
      R_pc    <= D_pc;
      R_fwd_a <= i_xu.from_fwd_a;
      R_fwd_b <= i_xu.from_fwd_b;
      if (D_decode.mul = '1') then
        R_mul <= not M_mul;
      end if;
      if (D_decode.div = '1') then
        R_div <= not M_div;
      end if;
      R_ready <= not data_ready;
    end if;
  end process stage_R;

  ------------------------------------------------------------------------------
  -- E STAGE
  ------------------------------------------------------------------------------
  stage_E : process(E_clk, i_rstn)
  begin
    if i_rstn = '0' then
      E_pc      <= init_pc;
      E_idecode <= init_idecode;
      E_sys     <= RESET_VECTOR;
      E_store   <= (others => '0');
      E_ready   <= '0';
    elsif rising_edge(E_clk) then
      E_ready   <= R_ready;
      E_pc      <= R_pc;
      E_idecode <= i_xu.from_idecode;
      -- STORE
      if (R_fwd_b.flag = '1') then
        E_store <= R_fwd_b.data;
      else
        E_store <= i_xu.from_rf.data_b;
      end if;
      -- SYS
      if (i_xu.from_idecode.src2 = SRC2_R) then
        if (i_xu.from_idecode.src1 = SRC1_PC) then
          E_sys <= R_pc.pc;
        elsif (R_fwd_a.flag = '1') then
          E_sys <= R_fwd_a.data;
        else
          E_sys <= i_xu.from_rf.data_a;
        end if;
      else
        E_sys <= std_logic_vector(resize(unsigned(i_xu.from_idecode.rs1_addr), XLEN));
      end if;
    end if;
  end process stage_E;

  -- Branch outcome
  E_branch_taken <= not(i_xu.from_alu.port_z(0)) when (E_idecode.funct3 = FCT_BNE   or
                                                       E_idecode.funct3 = FCT_BGE   or
                                                       E_idecode.funct3 = FCT_BGEU) else
                    i_xu.from_alu.port_z(0);

  -- Flush condition
  E_flush_out <= (E_idecode.branch and E_branch_taken) or E_idecode.jump or i_xu.from_sys.invalidate;

  ------------------------------------------------------------------------------
  -- M STAGE
  ------------------------------------------------------------------------------
  stage_M : process(M_clk, i_rstn)
  begin
    if i_rstn = '0' then
      M_idecode    <= init_idecode;
      M_alu_result <= (others => '0');
      M_ra         <= RESET_VECTOR;
      M_sys        <= (others => '0');
      M_pc_branch  <= '0';
      M_pc_sys     <= '0';
      M_ready      <= '0';
      M_flushed    <= '0';
      M_flush_out  <= '0';
      M_mul        <= '0';
      M_div        <= '0';
    elsif rising_edge(M_clk) then
      M_ready   <= E_ready;
      M_flushed <= i_xu.flush;
      --
      if (i_xu.flush = '1') then
        M_flush_out  <= '0';
        M_idecode    <= init_idecode;
        M_alu_result <= (others => '0');
        M_ra         <= RESET_VECTOR;
        M_sys        <= (others => '0');
        M_pc_branch  <= '0';
        M_pc_sys     <= '0';
      else
        M_flush_out  <= E_flush_out;
        M_idecode    <= E_idecode;
        M_ra         <= std_logic_vector(unsigned(R_pc.pc) + PC_INCR);
        M_sys        <= i_xu.from_sys.rd;
        M_alu_result <= i_xu.from_alu.port_z;
        M_pc_branch  <= E_idecode.branch and E_branch_taken;
        M_pc_sys     <= i_xu.from_sys.invalidate;
      end if;
      -- MUL / DIV
      if (D_decode.mul = '1') then
        M_mul <= R_mul;
      end if;
      if (D_decode.div = '1') then
        M_div <= R_div;
      end if;
    end if;
  end process stage_M;

  M_pc_target <= M_idecode.B_imm   when M_pc_branch = '1' else
                 M_alu_result      when M_idecode.jump = '1'   else
                 i_xu.from_sys.pc  when M_pc_sys = '1'    else
                 RESET_VECTOR;

  ------------------------------------------------------------------------------
  -- W STAGE
  ------------------------------------------------------------------------------
  stage_W : process(W_clk, i_rstn)
  begin
    if i_rstn = '0' then
      W_load  <= (others => '0');
      W_ready <= '0';
    elsif rising_edge(W_clk) then
      W_ready <= M_ready;
      W_load  <= i_xu.from_lsu.mem_read;
    end if;
  end process stage_W;

end architecture beh;
