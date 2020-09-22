-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : keyv_pkg.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : KeyRing core packages
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- UTILS PACKAGE
--
--    Utility functions to be used with the KeyRing
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package utils_pkg is

  function to_thermometer(val: in natural; n: in positive) return std_logic_vector;
  function get_click (i : in integer; n : in integer) return natural;

end package utils_pkg;
package body utils_pkg is

  -------------------------------------------------------------------------------
  -- to_thermometer
  --
  --    Converts a natural value to thermometer codes of size n
  --    Used for dcdl opcodes
  -------------------------------------------------------------------------------
  function to_thermometer (
    val : in natural;                   -- Value to convert
    n   : in positive)                  -- Size of the output vector
  return std_logic_vector is
    variable val_v : std_logic_vector(n-1 downto 0);
  begin
    if val > 0 then
      val_v(n-1 downto n-val) := (others => '1');
    end if;
    val_v(n-val-1 downto 0) := (others => '0');
    return val_v;
  end function to_thermometer;

  -------------------------------------------------------------------------------
  -- get_click
  --
  --    Returns the index of a dependent click in the KeyRing
  --    Used for the definition of KeyRing with generic sizes
  -------------------------------------------------------------------------------
  function get_click (
    i : in integer;       -- Index of the click from which to find the dependency
    n : in integer)       -- Size of the KeyRing row/column
  return natural is
  begin
    return i mod n;
  end function get_click;

end package body utils_pkg;

------------------------------------------------------------------------------
-- KEYV PACKAGE
--
--    Global KeyRing parameters
--    Dedicated types (arrays & records)
--    Components declarations
--    Dedicated functions
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.utils_pkg.all;

package keyv_pkg is

  ------------------------------------------------------------------------------
  -- KEYRING CONFIGURATION
  --
  --    Define the size of the KeyRing
  --    Define the size of the the delay elements
  ------------------------------------------------------------------------------
  constant KEYRING_E : positive := 6;  -- Number of Execution Unit
  constant KEYRING_S : positive := 6;  -- Number of stages by EU
  constant KEYRING_D : positive := 1;  -- EU Dependency Shift
  constant KEYRING_L : positive := 30; -- Maximum length of delay-elements(x2)
  constant KEYRING_P : positive := 16; -- Pulse Width

  type keyv_clk is (
    F,    -- Fetch
    D,    -- Decode
    R,    -- Register File
    E,    -- Execute
    M,    -- Memory
    W);   -- Write-Back

  subtype keyv_logic is std_logic;
  type keyv_logic_v is array(0 to KEYRING_S-1) of keyv_logic;
  type keyv_logic_x is array(0 to KEYRING_E-1) of keyv_logic;
  type keyv_logic_m is array(0 to KEYRING_E-1) of keyv_logic_v;

  ------------------------------------------------------------------------------
  -- DELAYS
  --
  --    DCDL for Keys use thermometer codes
  ------------------------------------------------------------------------------
  subtype keyv_delay is std_logic_vector(KEYRING_L-1 downto 0);
  type keyv_delay_v  is array(0 to KEYRING_S-1) of keyv_delay;
  type keyv_delay_m  is array(0 to KEYRING_E-1) of keyv_delay_v;

  -- Flat array of DE config: [ExS (keyring) + 3 (mul/div)] * L
  constant KEYRING_DE_FLAT : positive := (KEYRING_E*KEYRING_S+3)*KEYRING_L;
  type keyv_delay_cfg is array (0 to KEYRING_DE_FLAT-1) of std_logic;

  ------------------------------------------------------------------------------
  -- DCDL - Digitally Controlled Delay Line
  --
  --    Glitch free variable delay element used to delay the keys in the KeyRing
  ------------------------------------------------------------------------------
  component dcdl is
    generic (
      DL : positive);                                -- Maximum Length of the DCDL
    port (
      i_sel   : in  std_logic_vector(DL-1 downto 0); -- Delay selection
      i_logic : in  std_logic;                       -- Input signal
      o_logic : out std_logic);                      -- Delayed output signal
  end component dcdl;

  ------------------------------------------------------------------------------
  -- CLICK - Click Element
  --
  --    Basic Unit of the KeyRing. Generates / Manage the clocks.
  ------------------------------------------------------------------------------
  type keyv_to_click is record
    key_e : keyv_logic;                 -- First input key (previous xu, same stage)
    key_s : keyv_logic;                 -- Second input key (previous stage, same xu)
    stall : keyv_logic;                 -- Enable signal
  end record keyv_to_click;

  type keyv_to_click_v is array(0 to KEYRING_S-1) of keyv_to_click;
  type keyv_to_click_m is array(0 to KEYRING_E-1) of keyv_to_click_v;

  type keyv_from_click is record
    key : keyv_logic;                   -- Output key
    clk : keyv_logic;                   -- Clock
  end record keyv_from_click;

  type keyv_from_click_v is array(0 to KEYRING_S-1) of keyv_from_click;
  type keyv_from_click_m is array(0 to KEYRING_E-1) of keyv_from_click_v;

  component click is
    generic (
      E : natural;                      -- E index (which XU)
      S : natural);                     -- S index (which stage)
    port (
      i_rstn  : in  std_logic;
      i_click : in  keyv_to_click;
      o_click : out keyv_from_click);
  end component click;

  ------------------------------------------------------------------------------
  -- KEYRING - Clock generator
  --
  --    E x S organization of clicks (2D torus mesh)
  --    Generates E x S clocks signals to control each stage of each XU
  --    Contains an additional standalone 1x1 keyring for the mul/div unit
  ------------------------------------------------------------------------------
  type keyv_to_keyring is record
    stalls    : keyv_logic_m;           -- Stall signals
    delay_en  : keyv_logic;             -- scan-enable for DE config
    delay_cfg : keyv_logic;             -- scan-in for DE config
    m_start   : keyv_logic;             -- mul/div unit start
    m_stop    : keyv_logic;             -- mul/div unit stop
  end record keyv_to_keyring;

  type keyv_from_keyring is record
    clks   : keyv_logic_m;              -- Output clocks
    states : keyv_logic_m;              -- Output state signals
    r_clks : keyv_logic_v;              -- Resources clocks
    m_clk  : keyv_logic;                -- mul/div unit clock
  end record keyv_from_keyring;

  component keyring is
    port (
      i_rstn    : in  std_logic;
      i_clk     : in  std_logic;
      i_keyring : in  keyv_to_keyring;
      o_keyring : out keyv_from_keyring);
  end component keyring;

  -- Concurrency
  function click_concurrency (e : in natural; s : in natural) return natural;
  function init_key (e : in natural; s : in natural) return std_logic;

  ------------------------------------------------------------------------------
  -- ALU
  --
  --    add / sub / shift + multiplier / divider
  --    Multiplier / divider work in 32 cycles with a standalone KeyRing
  ------------------------------------------------------------------------------
  type keyv_to_alu is record
    arith    : std_logic;
    sign     : std_logic_vector(1 downto 0);
    opcode   : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
    mul      : std_logic;
    div      : std_logic;
    shamt    : std_logic_vector(SHAMT_WIDTH-1 downto 0);
    port_a   : std_logic_vector(XLEN-1 downto 0);
    port_b   : std_logic_vector(XLEN-1 downto 0);
  end record keyv_to_alu;

  type keyv_from_alu is record
    mul_valid : std_logic;
    div_valid : std_logic;
    port_z    : std_logic_vector(XLEN-1 downto 0);
  end record keyv_from_alu;

  component alu is
    port (
      i_clk   : in  std_logic;
      i_clk_m : in  std_logic;
      i_rstn  : in  std_logic;
      i_alu   : in  keyv_to_alu;
      o_alu   : out keyv_from_alu);
  end component alu;

  ------------------------------------------------------------------------------
  -- EXECUTION UNIT
  --
  --    Multicycle pipeline
  ------------------------------------------------------------------------------
  type keyv_fwd_xu is record
    flag : std_logic;
    busy : std_logic;
    data : std_logic_vector(XLEN-1 downto 0);
  end record keyv_fwd_xu;

  function init_fwd return keyv_fwd_xu;

  type keyv_alu_xu is record
    fwd_a : keyv_fwd_xu;
    fwd_b : keyv_fwd_xu;
    mul   : std_logic;
    div   : std_logic;
    pc    : std_logic_vector(XLEN-1 downto 0);
  end record keyv_alu_xu;

  type keyv_fwd_xu_x is array(0 to KEYRING_E-1) of keyv_fwd_xu;

  type keyv_to_xu is record
    imem         : std_logic_vector(XLEN-1 downto 0);
    flush        : keyv_logic;
    from_fwd_a   : keyv_fwd_xu;
    from_fwd_b   : keyv_fwd_xu;
    from_rf      : keyv_from_rf;
    from_pc      : keyv_from_pc;
    from_idecode : keyv_from_idecode;
    from_alu     : keyv_from_alu;
    from_sys     : keyv_from_sys;
    from_lsu     : keyv_from_lsu;
  end record keyv_to_xu;

  type keyv_from_xu is record
    flush      : keyv_logic;
    flushed    : keyv_logic;
    busy       : keyv_logic;
    to_pc      : keyv_to_pc;
    to_idecode : keyv_to_idecode;
    to_rf      : keyv_to_rf;
    to_alu     : keyv_alu_xu;
    to_perf    : keyv_to_perf;
    to_sys     : keyv_to_sys;
    to_lsu     : keyv_to_lsu;
  end record keyv_from_xu;

  type keyv_from_xu_x is array(0 to KEYRING_E-1) of keyv_from_xu;
  type keyv_to_xu_x is array(0 to KEYRING_E-1) of keyv_to_xu;

  component xu is
    generic (
      ID : natural);
    port (
      i_rstn : in  std_logic;
      i_clks : in  keyv_logic_v;
      i_xu   : in  keyv_to_xu;
      o_xu   : out keyv_from_xu);
  end component xu;

  ------------------------------------------------------------------------------
  -- XBAR SWITCH
  --
  --    Combinational data transfer between XUs & Resources
  ------------------------------------------------------------------------------
  component xbs is
    port (
      i_rstn       : in  std_logic;
      i_delay_cfg  : in  std_logic;
      i_delay_en   : in  std_logic;
      i_imem       : in  std_logic_vector(XLEN-1 downto 0);
      i_dmem       : in  std_logic_vector(XLEN-1 downto 0);
      from_keyring : in  keyv_from_keyring;
      to_keyring   : out keyv_to_keyring;
      from_xu      : in  keyv_from_xu_x;
      to_xu        : out keyv_to_xu_x;
      from_pc      : in  keyv_from_pc;
      to_pc        : out keyv_to_pc;
      from_idecode : in  keyv_from_idecode;
      to_idecode   : out keyv_to_idecode;
      from_rf      : in  keyv_from_rf;
      to_rf        : out keyv_to_rf;
      from_alu     : in  keyv_from_alu;
      to_alu       : out keyv_to_alu;
      from_perf    : in  keyv_from_perf;
      to_perf      : out keyv_to_perf;
      from_sys     : in  keyv_from_sys;
      to_sys       : out keyv_to_sys;
      from_lsu     : in  keyv_from_lsu;
      to_lsu       : out keyv_to_lsu);
  end component xbs;

end package keyv_pkg;
package body keyv_pkg is

  ------------------------------------------------------------------------------
  -- CLICK_CONCURRENCY
  --
  --    Every click having the same value of (D*e+s)%S are computed concurrently
  ------------------------------------------------------------------------------
  function click_concurrency (e : in natural; s : in natural) return natural is
  begin
    return ((KEYRING_D*e + s) mod KEYRING_S);
  end function click_concurrency;

  ------------------------------------------------------------------------------
  -- INIT_KEY
  --
  --    Initializes clicks on the KeyRing (+starts the ring)
  ------------------------------------------------------------------------------
  function init_key (e : in natural; s : in natural) return std_logic is
  begin
    if click_concurrency(e,s) = 0 then
      return '0';
    else
      return '1';
    end if;
  end function init_key;

  ------------------------------------------------------------------------------
  -- INIT_FWD
  --
  --    Returns an initialized a keyv_fwd_xu record
  ------------------------------------------------------------------------------
  function init_fwd return keyv_fwd_xu is
    variable fwd : keyv_fwd_xu;
  begin
    fwd.flag := '0';
    fwd.busy := '0';
    fwd.data := (others => '0');
    return fwd;
  end function init_fwd;

end package body keyv_pkg;
