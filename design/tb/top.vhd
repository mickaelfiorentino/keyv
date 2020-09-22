-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : top.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Top level core interface with main memory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.tb_pkg.all;

entity top is
  generic (
    MEM_INIT_FILE        : string := "mem.hex";
    CORE_INTERFACE_DELAY : time   := 0 ps);
  port (
    i_rstn      : in std_logic;
    i_clk       : in std_logic;
    i_delay_cfg : in std_logic;
    i_delay_en  : in std_logic);
end entity top;

architecture str of top is

  ------------------------------------------------------------------------------
  -- CORE
  ------------------------------------------------------------------------------
  component core is
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
  end component core;

  ------------------------------------------------------------------------------
  -- DUAL PORT MEMORY
  ------------------------------------------------------------------------------
  component dpm is
    generic (
      XLEN      : integer;
      DEPTH     : integer;
      RESET     : integer;
      INIT_FILE : string);
    port (
      i_a_clk   : in  std_logic;
      i_a_rstn  : in  std_logic;
      i_a_en    : in  std_logic;
      i_a_we    : in  std_logic_vector((XLEN/8)-1 downto 0);
      i_a_addr  : in  std_logic_vector(DEPTH-1 downto 0);
      i_a_write : in  std_logic_vector(XLEN-1 downto 0);
      o_a_read  : out std_logic_vector(XLEN-1 downto 0);
      i_b_clk   : in  std_logic;
      i_b_rstn  : in  std_logic;
      i_b_en    : in  std_logic;
      i_b_we    : in  std_logic_vector((XLEN/8)-1 downto 0);
      i_b_addr  : in  std_logic_vector(DEPTH-1 downto 0);
      i_b_write : in  std_logic_vector(XLEN-1 downto 0);
      o_b_read  : out std_logic_vector(XLEN-1 downto 0));
  end component dpm;

  ------------------------------------------------------------------------------
  -- TRANSPORT_INTERFACE
  --
  -- Transport signals between components with a delay D
  -- Allow to handle post-synthesis/pnr simulations timing issues
  ------------------------------------------------------------------------------
  procedure transport_interface (
    constant D   : in time;
    signal i_sig : in  std_logic_vector;
    signal o_sig : out std_logic_vector) is
  begin
      o_sig <= inertial i_sig after D;
  end procedure transport_interface;

  procedure transport_interface (
    constant D   : in time;
    signal i_sig : in  std_logic;
    signal o_sig : out std_logic) is
  begin
      o_sig <= inertial i_sig after D;
  end procedure transport_interface;

  ------------------------------------------------------------------------------
  -- INTERFACES
  ------------------------------------------------------------------------------
  signal rstn_d : std_logic;

  -- Imem interface
  signal core_imem_addr    : std_logic_vector(XLEN-1 downto 0);
  signal core_imem_effaddr : std_logic_vector(MEM_DEPTH-1 downto 0);
  signal core_imem_write   : std_logic_vector(XLEN-1 downto 0);
  signal core_imem_read    : std_logic_vector(XLEN-1 downto 0);
  signal core_imem_read_d  : std_logic_vector(XLEN-1 downto 0);
  signal core_imem_clk     : std_logic;
  signal core_imem_en      : std_logic;
  signal core_imem_we      : std_logic_vector(BYTE_NB-1 downto 0);

  -- Dmem interface
  signal core_dmem_addr    : std_logic_vector(XLEN-1 downto 0);
  signal core_dmem_effaddr : std_logic_vector(MEM_DEPTH-1 downto 0);
  signal core_dmem_write   : std_logic_vector(XLEN-1 downto 0);
  signal core_dmem_read    : std_logic_vector(XLEN-1 downto 0);
  signal core_dmem_read_d  : std_logic_vector(XLEN-1 downto 0);
  signal core_dmem_clk     : std_logic;
  signal core_dmem_en      : std_logic;
  signal core_dmem_ena     : std_logic;
  signal core_dmem_we      : std_logic_vector(BYTE_NB-1 downto 0);

  -- IOpad interface
  signal core_pad_effaddr : std_logic_vector(PAD_DEPTH-1 downto 0);
  signal core_pad_write   : std_logic_vector(XLEN-1 downto 0);
  signal core_pad_read    : std_logic_vector(XLEN-1 downto 0);
  signal core_pad_clk     : std_logic;
  signal core_pad_en      : std_logic;
  signal core_pad_we      : std_logic_vector(BYTE_NB-1 downto 0);

begin

  -------------------------------------------------------------------------------
  -- CORE
  -------------------------------------------------------------------------------
  u_core : core
    port map (
      i_rstn       => rstn_d,
      i_clk        => i_clk,
      i_delay_cfg  => i_delay_cfg,
      i_delay_en   => i_delay_en,
      o_imem_clk   => core_imem_clk,
      o_imem_en    => core_imem_en,
      o_imem_addr  => core_imem_addr,
      i_imem_read  => core_imem_read_d,
      o_dmem_clk   => core_dmem_clk,
      o_dmem_en    => core_dmem_en,
      o_dmem_we    => core_dmem_we,
      o_dmem_addr  => core_dmem_addr,
      o_dmem_write => core_dmem_write,
      i_dmem_read  => core_dmem_read_d);

  -- Transport core interface
  transport_interface(CORE_INTERFACE_DELAY, i_rstn, rstn_d);
  transport_interface(CORE_INTERFACE_DELAY, core_imem_read, core_imem_read_d);
  transport_interface(CORE_INTERFACE_DELAY, core_dmem_read, core_dmem_read_d);

  -------------------------------------------------------------------------------
  -- CORE MEMORY (IMEM + DMEM)
  -------------------------------------------------------------------------------

  -- IMEM is read only
  core_imem_we    <= (others => '0');
  core_imem_write <= (others => '0');

  core_imem_effaddr <= core_imem_addr(MEM_DEPTH+1 downto 2);
  core_dmem_effaddr <= core_dmem_addr(MEM_DEPTH+1 downto 2);

  core_dmem_ena <= core_dmem_en and not core_dmem_addr(PAD_BIT_SELECT);

  u_mem : dpm
    generic map (
      XLEN      => XLEN,
      DEPTH     => MEM_DEPTH,
      RESET     => RESET,
      INIT_FILE => MEM_INIT_FILE)
    port map (
      i_a_clk   => core_imem_clk,
      i_a_rstn  => i_rstn,
      i_a_en    => core_imem_en,
      i_a_we    => core_imem_we,
      i_a_addr  => core_imem_effaddr,
      i_a_write => core_imem_write,
      o_a_read  => core_imem_read,
      i_b_clk   => core_dmem_clk,
      i_b_rstn  => i_rstn,
      i_b_en    => core_dmem_ena,
      i_b_we    => core_dmem_we,
      i_b_addr  => core_dmem_effaddr,
      i_b_write => core_dmem_write,
      o_b_read  => core_dmem_read);

  -------------------------------------------------------------------------------
  -- IOPAD MEMORY
  --
  --   At the core interface, iopad uses dmem address bus
  --   but is only enabled when in range
  -------------------------------------------------------------------------------
  core_pad_en      <= core_dmem_en and core_dmem_addr(PAD_BIT_SELECT);
  core_pad_we      <= core_dmem_we;
  core_pad_clk     <= core_dmem_clk;
  core_pad_effaddr <= core_dmem_addr(PAD_DEPTH+1 downto 2);
  core_pad_write   <= core_dmem_write;

  u_iopad : dpm
    generic map (
      XLEN      => XLEN,
      DEPTH     => PAD_DEPTH,
      RESET     => RESET,
      INIT_FILE => "")
    port map (
      i_a_clk   => core_pad_clk,
      i_a_rstn  => i_rstn,
      i_a_en    => core_pad_en,
      i_a_we    => core_pad_we,
      i_a_addr  => core_pad_effaddr,
      i_a_write => core_pad_write,
      o_a_read  => core_pad_read,
      i_b_clk   => '0',
      i_b_rstn  => '0',
      i_b_en    => '0',
      i_b_we    => (others => '0'),
      i_b_addr  => (others => '0'),
      i_b_write => (others => '0'),
      o_b_read  => open);

end architecture str;
