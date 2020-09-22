-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : sync.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Synchronizer (Producer --> Consumer)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library synopsys;
use synopsys.attributes.all;

entity sync is
  generic (
    N : positive := 32);
  port (
    i_rstn   : in  std_logic;
    i_clk_p  : in  std_logic;
    i_data_p : in  std_logic_vector(N-1 downto 0);
    i_clk_c  : in  std_logic;
    o_data_c : out std_logic_vector(N-1 downto 0));
end entity sync;

architecture rtl of sync is

  signal data_p, data_c : std_logic_vector(N-1 downto 0);
  signal sn, sp         : std_logic;
  signal rn, rc         : std_logic;
  signal valid          : std_logic;

  attribute async_set_reset of sn, rn : signal is "true";

begin

  o_data_c <= data_c;

  --------------
  -- SR Latch --
  --------------
  srlat : process (sn, rn)
  begin
    if (rn = '0') then
      valid <= '0';
    elsif (sn = '0') then
      valid <= '1';
    end if;
  end process srlat;

  --------------------
  -- P Synchronizer --
  --------------------
  psync : process (i_rstn, i_clk_p)
  begin
    if i_rstn = '0' then
      sp <= '1';
      sn <= '1';
    elsif rising_edge(i_clk_p) then
      sp <= not(valid);
      sn <= not(sp);
    end if;
  end process psync;

  pdat : process (i_clk_p)
  begin
    if rising_edge(i_clk_p) then
      if valid = '0' then
        data_p <= i_data_p;
      end if;
    end if;
  end process pdat;

  --------------------
  -- C Synchronizer --
  --------------------
  csync : process (i_rstn, i_clk_c)
  begin
    if i_rstn = '0' then
      rc <= '0';
      rn <= '0';
    elsif rising_edge(i_clk_c) then
      rc <= valid;
      rn <= not(rc);
    end if;
  end process csync;

  cdat : process (i_clk_c)
  begin
    if rising_edge(i_clk_c) then
      if valid = '1' then
        data_c <= data_p;
      end if;
    end if;
  end process cdat;

end architecture rtl;
