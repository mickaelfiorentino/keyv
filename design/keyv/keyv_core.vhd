-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : keyv_core.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : KeyV core
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity core is
  port (
    i_rstn       : in  std_logic;
    i_clk        : in  std_logic;
    i_delay_cfg  : in  std_logic;
    i_delay_en   : in  std_logic;
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

architecture keyv of core is

  ------------------------------------------------------------------------------
  -- MODULES
  ------------------------------------------------------------------------------
  signal from_keyring : keyv_from_keyring;
  signal to_keyring   : keyv_to_keyring;
  signal to_xu        : keyv_to_xu_x;
  signal from_xu      : keyv_from_xu_x;
  signal to_pc        : keyv_to_pc;
  signal from_pc      : keyv_from_pc;
  signal to_idecode   : keyv_to_idecode;
  signal from_idecode : keyv_from_idecode;
  signal to_rf        : keyv_to_rf;
  signal from_rf      : keyv_from_rf;
  signal to_alu       : keyv_to_alu;
  signal from_alu     : keyv_from_alu;
  signal to_perf      : keyv_to_perf;
  signal from_perf    : keyv_from_perf;
  signal to_sys       : keyv_to_sys;
  signal from_sys     : keyv_from_sys;
  signal to_lsu       : keyv_to_lsu;
  signal from_lsu     : keyv_from_lsu;

  ------------------------------------------------------------------------------
  -- CLOCKS
  ------------------------------------------------------------------------------
  alias F_clks : std_logic is from_keyring.r_clks(keyv_clk'pos(F));
  alias D_clks : std_logic is from_keyring.r_clks(keyv_clk'pos(D));
  alias R_clks : std_logic is from_keyring.r_clks(keyv_clk'pos(R));
  alias E_clks : std_logic is from_keyring.r_clks(keyv_clk'pos(E));
  alias M_clks : std_logic is from_keyring.r_clks(keyv_clk'pos(M));
  alias W_clks : std_logic is from_keyring.r_clks(keyv_clk'pos(W));

  ------------------------------------------------------------------------------
  -- CYCLE COUNTERS
  ------------------------------------------------------------------------------
  signal C_clks : std_logic;
  signal cycle  : std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);

begin

  ------------------------------------------------------------------------------
  -- I/O Interfaces
  ------------------------------------------------------------------------------
  o_imem_clk   <= F_clks;
  o_imem_en    <= i_rstn;
  o_imem_addr  <= from_pc.pc;
  o_dmem_clk   <= M_clks;
  o_dmem_en    <= from_lsu.mem_en;
  o_dmem_addr  <= from_lsu.mem_addr;
  o_dmem_we    <= from_lsu.mem_we;
  o_dmem_write <= from_lsu.mem_write;

  ------------------------------------------------------------------------------
  -- KEYRING
  ------------------------------------------------------------------------------
  u_keyring : keyring
    port map (
      i_rstn    => i_rstn,
      i_clk     => i_clk,
      i_keyring => to_keyring,
      o_keyring => from_keyring);

  ------------------------------------------------------------------------------
  -- EXECUTION UNITS
  ------------------------------------------------------------------------------
  g_xu : for e in 0 to KEYRING_E-1 generate
    u_xu : xu
      generic map (
        ID => e)
      port map (
        i_rstn => i_rstn,
        i_clks => from_keyring.clks(e),
        i_xu   => to_xu(e),
        o_xu   => from_xu(e));
  end generate g_xu;

  ------------------------------------------------------------------------------
  -- XBAR SWITCH
  ------------------------------------------------------------------------------
  u_xbs : xbs
    port map (
      i_rstn       => i_rstn,
      i_delay_cfg  => i_delay_cfg,
      i_delay_en   => i_delay_en,
      i_imem       => i_imem_read,
      i_dmem       => i_dmem_read,
      from_keyring => from_keyring,
      to_keyring   => to_keyring,
      from_xu      => from_xu,
      to_xu        => to_xu,
      from_pc      => from_pc,
      to_pc        => to_pc,
      from_rf      => from_rf,
      to_rf        => to_rf,
      from_idecode => from_idecode,
      to_idecode   => to_idecode,
      from_alu     => from_alu,
      to_alu       => to_alu,
      from_perf    => from_perf,
      to_perf      => to_perf,
      from_sys     => from_sys,
      to_sys       => to_sys,
      from_lsu     => from_lsu,
      to_lsu       => to_lsu);

  ------------------------------------------------------------------------------
  -- PROGRAM COUNTER
  ------------------------------------------------------------------------------
  u_pc : pc
    port map (
      i_clk  => W_clks,
      i_rstn => i_rstn,
      i_pc   => to_pc,
      o_pc   => from_pc);

  ------------------------------------------------------------------------------
  -- INSTRUCTION DECODE
  ------------------------------------------------------------------------------
  u_idecode : idecode
    port map (
      i_clk     => R_clks,
      i_rstn    => i_rstn,
      i_idecode => to_idecode,
      o_idecode => from_idecode);

  ------------------------------------------------------------------------------
  -- REGISTER FILE
  ------------------------------------------------------------------------------
  u_rf : rf
    port map (
      i_clk  => R_clks,
      i_rstn => i_rstn,
      i_rf   => to_rf,
      o_rf   => from_rf);

  ------------------------------------------------------------------------------
  -- ALU
  ------------------------------------------------------------------------------
  u_alu : alu
    port map (
      i_clk   => E_clks,
      i_clk_m => from_keyring.m_clk,
      i_rstn  => i_rstn,
      i_alu   => to_alu,
      o_alu   => from_alu);

  ------------------------------------------------------------------------------
  -- SYSTEM
  ------------------------------------------------------------------------------

  -- Performance counters
  --
  u_perf : perf
    port map (
      i_clk_c => i_clk,
      i_clk_i => M_clks,
      i_rstn  => i_rstn,
      i_perf  => to_perf,
      o_perf  => from_perf);

  -- Synchronization
  --
  C_clks <= E_clks or M_clks;

  u_cycle_sync : sync
    generic map (
      N => PERFCOUNT_WIDTH)
    port map (
      i_rstn   => i_rstn,
      i_clk_p  => i_clk,
      i_data_p => from_perf.cycle,
      i_clk_c  => C_clks,
      o_data_c => cycle);

  -- System
  --
  u_sys : sys
    port map (
      i_clk     => M_clks,
      i_rstn    => i_rstn,
      i_cycle   => cycle,
      i_instret => from_perf.instret,
      i_sys     => to_sys,
      o_sys     => from_sys);

  ------------------------------------------------------------------------------
  -- LOAD STORE UNIT
  ------------------------------------------------------------------------------
  u_lsu : lsu
    port map (
      i_clk  => M_clks,
      i_rstn => i_rstn,
      i_dmem => i_dmem_read,
      i_lsu  => to_lsu,
      o_lsu  => from_lsu);

end architecture keyv;
