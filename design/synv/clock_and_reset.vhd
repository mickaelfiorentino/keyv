-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : clock_and_reset.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-03-25
-- Brief   : Clock management & Reset synchronizer
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clock_and_reset is
  generic (
    RST_INI : std_logic := '0');
  port (
    i_rstn : in std_logic;
    i_clk  : in std_logic;
    o_rstn : out std_logic;
    o_clk  : out std_logic);
end entity clock_and_reset;

architecture rtl of clock_and_reset is

  signal clk  : std_logic;
  signal rstn : std_logic_vector(1 downto 0);

begin

  -- Outputs
  o_rstn <= rstn(1);
  o_clk  <= clk;

  -- Clock management
  clk <= i_clk;

  -- Reset synchronizer
  p_rstn : process (clk, i_rstn)
  begin
    if (i_rstn = '0') then
      rstn <= (others => RST_INI);
    elsif rising_edge(clk) then
      rstn(0) <= not(RST_INI);
      rstn(1) <= rstn(0);
    end if;
  end process p_rstn;

end architecture rtl;
