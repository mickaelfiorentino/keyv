-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : click.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Click Element
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.stdcells.all;
use work.keyv_pkg.all;

entity click is
  generic (
    E : natural := 0;
    S : natural := 0);
  port (
    i_rstn  : in  std_logic;
    i_click : in  keyv_to_click;
    o_click : out keyv_from_click);
end entity click;

architecture xor_arch of click is

  signal key, keyn, keyf    : std_logic;
  signal clk, rn, sn, stall : std_logic;
  signal xor_e, xor_s       : std_logic;
  signal clkb, keyb         : std_logic;
  signal pulsew             : std_logic_vector(KEYRING_P downto 0);
  signal stallw             : std_logic_vector(KEYRING_P downto 0);

  constant INIT : std_logic := init_key(E,S);

begin

  -- OUTPUTS
  o_click.key <= keyb;
  o_click.clk <= clkb;

  -- CLK/KEY BUFFERS
  u_clkbuf: CLKBUF port map (Y => clkb, A => clk);
  u_keybuf: CLKBUF port map (Y => keyb, A => key);

  -- PULSE-WIDTH BUFFERS
  pulsew(0) <= key;
  g_pulsew: for i in 1 to KEYRING_P generate
    u_pulsew: CLKBUF port map (Y => pulsew(i), A => pulsew(i-1));
  end generate g_pulsew;

  -- STALL BUFFERS (Delayed stall to avoid races @R)
  stallw(0) <= i_click.stall;
  g_stallw: for i in 1 to KEYRING_P generate
    u_stallw: CLKBUF port map (Y => stallw(i), A => stallw(i-1));
  end generate g_stallw;

  -- FEEDBACK (START)
  g_start : if INIT = '1' generate
    u_fb : NAND21 port map (Y => keyf, A => pulsew(KEYRING_P), B => i_rstn);
  end generate g_start;
  g_nstart: if INIT = '0' generate
    u_fb : AND21 port map (Y => keyf, A => pulsew(KEYRING_P), B => i_rstn);
  end generate g_nstart;

  -- CONTROL
  u_xor_e : XOR21 port map (Y => xor_e, A => i_click.key_e, B => keyf);
  u_xor_s : XOR21 port map (Y => xor_s, A => i_click.key_s, B => keyf);
  u_clk   : NOR31 port map (Y => clk, A => xor_e, B => xor_s, C => stallw(KEYRING_P));

  -- RESET
  u_rn : OR21 port map (Y => rn, A => INIT, B => i_rstn);
  u_sn : OR21 port map (Y => sn, A => not(INIT), B => i_rstn);

  -- TOGGLE
  u_toggle : DFFSR1 port map (CK => clkb, D => keyn, RN => rn, SN => sn, Q => key, QN => keyn);

end architecture xor_arch;
