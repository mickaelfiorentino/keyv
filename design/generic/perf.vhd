-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : perf.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Performance Counters
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity perf is
  port (
    i_clk_c : in  std_logic;
    i_clk_i : in  std_logic;
    i_rstn  : in  std_logic;
    i_perf  : in  keyv_to_perf;
    o_perf  : out keyv_from_perf);
end entity perf;

architecture beh of perf is

  signal cycle   : unsigned(PERFCOUNT_WIDTH-1 downto 0);
  signal instret : unsigned(PERFCOUNT_WIDTH-1 downto 0);

begin

  o_perf.cycle   <= std_logic_vector(cycle);
  o_perf.instret <= std_logic_vector(instret);

  p_cycle : process (i_rstn, i_clk_c)
  begin
    if i_rstn = '0' then
        cycle <= (others => '0');
    elsif rising_edge(i_clk_c) then
        cycle <= cycle + 1;
    end if;
  end process p_cycle;

  p_instret : process (i_rstn, i_clk_i)
  begin
      if i_rstn = '0' then
        instret <= (others => '0');
      elsif rising_edge(i_clk_i) then
        if i_perf.stall = '0' then
          instret <= instret + 1;
        end if;
      end if;
  end process p_instret;

end architecture beh;
