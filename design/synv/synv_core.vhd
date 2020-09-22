-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : synv_core.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Synchronous core
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library synopsys;
use synopsys.attributes.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity core is
  port (
    i_rstn       : in  std_logic;
    i_clk        : in  std_logic;
    i_imem_read  : in  std_logic_vector(XLEN-1 downto 0);
    o_imem_clk   : out std_logic;
    o_imem_en    : out std_logic;
    o_imem_addr  : out std_logic_vector(XLEN-1 downto 0);
    i_dmem_read  : in  std_logic_vector(XLEN-1 downto 0);
    o_dmem_clk   : out std_logic;
    o_dmem_en    : out std_logic;
    o_dmem_we    : out std_logic_vector(BYTE_NB-1 downto 0);
    o_dmem_addr  : out std_logic_vector(XLEN-1 downto 0);
    o_dmem_write : out std_logic_vector(XLEN-1 downto 0));
end entity core;

architecture synv of core is

  -- CLOCK AND RESET
  --
  signal clk  : std_logic;
  signal rstn : std_logic;
  attribute async_set_reset of rstn : signal is "true";

  -- MODULES
  --
  signal to_pc        : keyv_to_pc;
  signal from_pc      : keyv_from_pc;
  signal to_idecode   : keyv_to_idecode;
  signal from_idecode : keyv_from_idecode;
  signal to_rf        : keyv_to_rf;
  signal from_rf      : keyv_from_rf;
  signal to_alu       : keyv_to_alu;
  signal from_alu     : keyv_from_alu;
  signal to_sys       : keyv_to_sys;
  signal from_sys     : keyv_from_sys;
  signal to_perf      : keyv_to_perf;
  signal from_perf    : keyv_from_perf;
  signal to_lsu       : keyv_to_lsu;
  signal from_lsu     : keyv_from_lsu;

  -- F STAGE
  --
  signal F_pc : keyv_from_pc;

  -- D STAGE
  --
  signal D_pc : keyv_from_pc;

  -- R STAGE
  --
  signal R_pc      : keyv_from_pc;
  signal R_idecode : keyv_from_idecode;
  signal R_fwd_W1  : std_logic_vector(XLEN-1 downto 0);
  signal R_fwd_M1  : std_logic_vector(XLEN-1 downto 0);
  signal R_fwd_E1  : std_logic_vector(XLEN-1 downto 0);
  signal R_fwd_W2  : std_logic_vector(XLEN-1 downto 0);
  signal R_fwd_M2  : std_logic_vector(XLEN-1 downto 0);
  signal R_fwd_E2  : std_logic_vector(XLEN-1 downto 0);
  signal R_rs1     : std_logic_vector(XLEN-1 downto 0);
  signal R_rs2     : std_logic_vector(XLEN-1 downto 0);
  signal R_shamt   : std_logic_vector(SHAMT_WIDTH-1 downto 0);
  signal R_rs1_sys : std_logic_vector(XLEN-1 downto 0);

  -- E STAGE
  --
  signal E_pc             : keyv_from_pc;
  signal E_idecode        : keyv_from_idecode;
  signal E_branch         : std_logic;
  signal E_branch_taken   : std_logic;
  signal E_pc_target      : std_logic_vector(XLEN-1 downto 0);
  signal E_load_stall     : std_logic;
  signal E_alu_stall      : std_logic;
  signal E_stall          : std_logic;
  signal E_transfert      : std_logic;
  signal E_invalidate     : std_logic;
  signal E_invalidate_sys : std_logic;
  signal E_mul            : std_logic;
  signal E_div            : std_logic;
  signal E_rd             : std_logic_vector(XLEN-1 downto 0);
  signal E_ra             : std_logic_vector(XLEN-1 downto 0);
  signal E_store          : std_logic_vector(XLEN-1 downto 0);

  -- M STAGE
  --
  signal M_idecode : keyv_from_idecode;
  signal M_mul     : std_logic;
  signal M_div     : std_logic;
  signal M_wb      : std_logic;
  signal M_ra      : std_logic_vector(XLEN-1 downto 0);
  signal M_rd      : std_logic_vector(XLEN-1 downto 0);
  signal M_rd_s    : std_logic_vector(XLEN-1 downto 0);

  -- W STAGE
  --
  signal W_idecode : keyv_from_idecode;
  signal W_rd      : std_logic_vector(XLEN-1 downto 0);

begin

  ------------------------------------------------------------------------------
  --                                CLOCK AND RESET
  ------------------------------------------------------------------------------
  u_clock_and_reset: clock_and_reset
    port map (
      i_rstn => i_rstn,
      i_clk  => i_clk,
      o_rstn => rstn,
      o_clk  => clk);

  ------------------------------------------------------------------------------
  --                                   F STAGE
  ------------------------------------------------------------------------------

  -- Program Counter Interface
  --
  to_pc.origin <= E_pc.pc;
  to_pc.stall  <= E_stall;
  to_pc.target <= E_pc_target;
  to_pc.jump   <= E_idecode.jump;
  to_pc.branch <= E_branch;
  to_pc.sys    <= E_invalidate_sys;

  u_pc : pc
    port map (
      i_clk  => clk,
      i_rstn => rstn,
      i_pc   => to_pc,
      o_pc   => from_pc);

  o_imem_clk  <= clk;
  o_imem_en   <= rstn and not(E_stall);
  o_imem_addr <= from_pc.pc;

  stage_F : process (clk, rstn)
  begin
    if rstn = '0' then
      F_pc <= init_pc;
    elsif rising_edge(clk) then
      if E_stall = '0' then
        if E_invalidate = '0' then
          F_pc <= from_pc;
        else
          F_pc <= init_pc;
        end if;
      end if;
    end if;
  end process stage_F;

  ------------------------------------------------------------------------------
  --                                   D STAGE
  ------------------------------------------------------------------------------

  -- Instruction Decode Interface
  --
  to_idecode.imem  <= i_imem_read;
  to_idecode.flush <= E_invalidate;
  to_idecode.stall <= E_stall or from_pc.invalidate;

  u_idecode : idecode
    port map (
      i_clk     => clk,
      i_rstn    => rstn,
      i_idecode => to_idecode,
      o_idecode => from_idecode);

  stage_D : process (clk, rstn)
  begin
    if rstn = '0' then
      D_pc <= init_pc;
    elsif rising_edge(clk) then
      if E_stall = '0' then
        if E_invalidate = '0' then
          D_pc <= F_pc;
        else
          D_pc <= init_pc;
        end if;
      end if;
    end if;
  end process stage_D;

  ------------------------------------------------------------------------------
  --                                   R STAGE
  ------------------------------------------------------------------------------

  -- Register File (Read) Interface
  --
  to_rf.addr_a <= from_idecode.rs1_addr;
  to_rf.addr_b <= from_idecode.rs2_addr;
  to_rf.en     <= not E_stall;

  u_rf : rf
    port map (
      i_clk  => clk,
      i_rstn => rstn,
      i_rf   => to_rf,
      o_rf   => from_rf);

  stage_R : process (clk, rstn)
  begin
    if rstn = '0' then
      R_pc      <= init_pc;
      R_idecode <= init_idecode;
    elsif rising_edge(clk) then
      if E_stall = '0' then
        if E_invalidate = '0' then
          R_pc      <= D_pc;
          R_idecode <= from_idecode;
        else
          R_pc      <= init_pc;
          R_idecode <= init_idecode;
        end if;
      end if;
    end if;
  end process stage_R;

  -- Operands Selection
  --
  R_fwd_W1 <= W_rd when forward(W_idecode.wb, R_idecode.rs1_addr, W_idecode.rd_addr) else
              from_rf.data_a;

  R_fwd_M1 <= M_rd when forward(M_idecode.wb, R_idecode.rs1_addr, M_idecode.rd_addr) else
              R_fwd_W1;

  R_fwd_E1 <= E_rd when forward(E_idecode.wb, R_idecode.rs1_addr, E_idecode.rd_addr) else
              R_fwd_M1;

  R_rs1 <= R_pc.pc when R_idecode.src1 = SRC1_PC else
           R_fwd_E1;

  R_fwd_W2 <= W_rd when forward(W_idecode.wb, R_idecode.rs2_addr, W_idecode.rd_addr) else
              from_rf.data_b;

  R_fwd_M2 <= M_rd when forward(M_idecode.wb, R_idecode.rs2_addr, M_idecode.rd_addr) else
              R_fwd_W2;

  R_fwd_E2 <= E_rd when forward(E_idecode.wb, R_idecode.rs2_addr, E_idecode.rd_addr) else
              R_fwd_M2;

  R_rs2 <= R_idecode.imm when R_idecode.src2 = SRC2_IM else
           R_fwd_E2;

  R_shamt <= R_fwd_E2(SHAMT_WIDTH-1 downto 0) when R_idecode.src2 = SRC2_R else
             R_idecode.shamt;

  -- CSR use rs1 data; CSRI use zero-extended rs1 address field (zimm)
  R_rs1_sys <= R_rs1 when R_idecode.src2 = SRC2_R else
               std_logic_vector(resize(unsigned(R_idecode.rs1_addr), XLEN));

  ------------------------------------------------------------------------------
  --                                   E STAGE
  ------------------------------------------------------------------------------

  -- ALU Interface
  --
  to_alu.arith  <= R_idecode.arith;
  to_alu.sign   <= R_idecode.sign;
  to_alu.mul    <= R_idecode.mul and not(E_invalidate);
  to_alu.div    <= R_idecode.div and not(E_invalidate);
  to_alu.opcode <= R_idecode.alu_op;
  to_alu.shamt  <= R_shamt;
  to_alu.port_a <= R_rs1;
  to_alu.port_b <= R_rs2;

  u_alu : alu
    port map (
      i_clk  => clk,
      i_rstn => rstn,
      i_alu  => to_alu,
      o_alu  => from_alu);

  -- System Interface
  --
  to_sys.sys      <= R_idecode.sys;
  to_sys.legal    <= R_idecode.legal;
  to_sys.fence    <= R_idecode.fence;
  to_sys.csrwe    <= R_idecode.csrwe;
  to_sys.csrsel   <= E_idecode.csr;
  to_sys.csrfunct <= R_idecode.funct3;
  to_sys.pc       <= R_pc.pc;
  to_sys.rs1      <= R_rs1_sys;
  to_sys.stall    <= E_stall;

  u_sys : sys
    port map (
      i_clk     => clk,
      i_rstn    => rstn,
      i_cycle   => from_perf.cycle,
      i_instret => from_perf.instret,
      i_sys     => to_sys,
      o_sys     => from_sys);

  -- Performance Counters
  --
  to_perf.stall <= F_pc.invalidate or D_pc.invalidate or R_pc.invalidate or E_invalidate or E_stall;

  u_perf : perf
    port map (
      i_clk_c => clk,
      i_clk_i => clk,
      i_rstn  => rstn,
      i_perf  => to_perf,
      o_perf  => from_perf);

  -- Result selection
  --
  E_rd <= from_sys.rd when E_idecode.sys = '1' else from_alu.port_z;

  stage_E : process (clk, rstn)
  begin
    if rstn = '0' then
      E_pc             <= init_pc;
      E_idecode        <= init_idecode;
      E_ra             <= RESET_VECTOR;
      E_store          <= (others => '0');
      E_mul            <= '0';
      E_div            <= '0';
      E_invalidate_sys <= '0';
    elsif rising_edge(clk) then
      if E_invalidate = '0' then
        E_pc             <= R_pc;
        E_idecode        <= R_idecode;
        E_ra             <= std_logic_vector(unsigned(R_pc.pc) + PC_INCR);
        E_store          <= R_fwd_E2;
        E_mul            <= from_alu.mul_valid;
        E_div            <= from_alu.div_valid;
        E_invalidate_sys <= from_sys.invalidate;
      else                              -- flush
        E_pc             <= init_pc;
        E_idecode        <= init_idecode;
        E_ra             <= RESET_VECTOR;
        E_store          <= (others => '0');
        E_mul            <= '0';
        E_div            <= '0';
        E_invalidate_sys <= '0';
      end if;
    end if;
  end process stage_E;

  -- Branch outcome & PC target
  --
  E_branch_taken <= not(from_alu.port_z(0)) when (E_idecode.funct3 = FCT_BNE or
                                                  E_idecode.funct3 = FCT_BGE or
                                                  E_idecode.funct3 = FCT_BGEU) else
                    from_alu.port_z(0);

  E_branch <= E_idecode.branch and E_branch_taken;

  E_pc_target <= E_idecode.B_imm when E_branch = '1' else
                 from_alu.port_z when E_idecode.jump = '1' else
                 from_sys.pc     when from_sys.invalidate = '1' else
                 RESET_VECTOR;

  -- Stall & Flush
  --
  E_load_stall <= '1' when (forward(E_idecode.load, E_idecode.rd_addr, R_idecode.rs1_addr) or
                            forward(E_idecode.load, E_idecode.rd_addr, R_idecode.rs2_addr)) else
                  '0';

  E_alu_stall <= '1' when ((R_idecode.mul = '1' and from_alu.mul_valid = '0') or
                           (R_idecode.div = '1' and from_alu.div_valid = '0')) else
                 '0';

  E_stall      <= E_load_stall or (E_alu_stall and not(E_transfert));
  E_transfert  <= E_branch or E_idecode.jump or E_invalidate_sys;
  E_invalidate <= E_transfert or E_load_stall;

  ------------------------------------------------------------------------------
  --                                 M STAGE
  ------------------------------------------------------------------------------

  -- Load Store Unit Interface
  --
  to_lsu.load      <= E_idecode.load;
  to_lsu.store     <= E_idecode.store;
  to_lsu.funct     <= E_idecode.funct3;
  to_lsu.base_addr <= from_alu.port_z;
  to_lsu.base_data <= E_store;

  u_lsu : lsu
    port map (
      i_clk  => clk,
      i_rstn => rstn,
      i_dmem => i_dmem_read,
      i_lsu  => to_lsu,
      o_lsu  => from_lsu);

  o_dmem_clk   <= clk;
  o_dmem_en    <= from_lsu.mem_en;
  o_dmem_we    <= from_lsu.mem_we;
  o_dmem_addr  <= from_lsu.mem_addr;
  o_dmem_write <= from_lsu.mem_write;

  stage_M : process (clk, rstn)
  begin
    if rstn = '0' then
      M_idecode <= init_idecode;
      M_ra      <= RESET_VECTOR;
      M_rd_s    <= (others => '0');
      M_mul     <= '0';
      M_div     <= '0';
    elsif rising_edge(clk) then
      M_idecode <= E_idecode;
      M_ra      <= E_ra;
      M_rd_s    <= E_rd;
      M_mul     <= not(E_idecode.mul) or E_mul;
      M_div     <= not(E_idecode.div) or E_div;
    end if;
  end process stage_M;

  M_rd <= from_lsu.mem_read when M_idecode.load = '1' else
          M_ra when M_idecode.jump = '1' else
          M_rd_s;

  M_wb <= M_idecode.wb and M_mul and M_div;

  ------------------------------------------------------------------------------
  --                                 W STAGE
  ------------------------------------------------------------------------------

  stage_W : process (clk, rstn)
  begin
    if rstn = '0' then
      W_idecode <= init_idecode;
      W_rd      <= (others => '0');
    elsif rising_edge(clk) then
      W_idecode <= M_idecode;
      W_rd      <= M_rd;
    end if;
  end process stage_W;

  -- Register File (Write) Interface
  --
  to_rf.we     <= M_wb;
  to_rf.addr_w <= M_idecode.rd_addr;
  to_rf.data_w <= M_rd;

end architecture synv;
