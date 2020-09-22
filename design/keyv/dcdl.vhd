-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : dcdl.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Digitally Controlled Delay Line. i_sel='0' pass; i_sel='1' stop
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.stdcells.all;

entity dcdl is
  generic(
    DL : positive := 10);
  port(
    i_sel   : in  std_logic_vector(DL-1 downto 0);
    i_logic : in  std_logic;
    o_logic : out std_logic);
end entity dcdl;

-------------------------------------------------------------------------------
--
-- MUX
--
-------------------------------------------------------------------------------
architecture mux_arch of dcdl is
  signal ckbf, ckmx: std_logic_vector(DL downto 0);
begin

  u_obf : CLKBUF port map (Y => o_logic, A => ckmx(DL));

  ckbf(0) <= i_logic;
  ckmx(0) <= ckbf(DL);

  g_dcdl : for i in 0 to DL-1 generate
    -- u_ckbf : DELX port map (Y => ckbf(i+1), A => ckbf(i));
    u_ckbf : CLKBUF port map (Y => ckbf(i+1), A => ckbf(i));
    u_ckmx : CLKMX21 port map (Y => ckmx(DL-i), A => ckmx(DL-i-1), B => ckbf(i+1), S => i_sel(i));
  end generate g_dcdl;

end architecture mux_arch;
