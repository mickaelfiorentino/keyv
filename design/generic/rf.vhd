-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : rf.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Register File
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity rf is
  port (
    i_clk  : in  std_logic;
    i_rstn : in  std_logic;
    i_rf   : in  keyv_to_rf;
    o_rf  : out keyv_from_rf);
end entity rf;

architecture beh of rf is

  -- Register file
  type regfile_t is array(0 to REG_NB-1) of std_logic_vector(XLEN-1 downto 0);
  signal regfile : regfile_t;

  -- Forwading Data
  signal wb_data: std_logic_vector(XLEN-1 downto 0);
  signal o_ra : std_logic_vector(XLEN-1 downto 0);
  signal o_rb : std_logic_vector(XLEN-1 downto 0);

  -- Forwarding Control
  signal fwd_a, fwd_a_s : std_logic;
  signal fwd_b, fwd_b_s : std_logic;

begin

  --
  -- Output
  --
  o_rf.data_a <= wb_data when fwd_a_s = '1' else o_ra;
  o_rf.data_b <= wb_data when fwd_b_s = '1' else o_rb;

  --
  --  Register File
  --
  p_rf: process (i_clk, i_rstn) is
  begin
    if i_rstn = '0' then

      regfile <= (others => (others => '0'));
      o_ra  <= (others => '0');
      o_rb  <= (others => '0');

    elsif rising_edge(i_clk) then

      -- Write registers
      if (i_rf.we = '1' and i_rf.addr_w /= REG_X0) then
        regfile(to_integer(unsigned(i_rf.addr_w))) <= i_rf.data_w;
      end if;

      -- Read registers
      if i_rf.en = '1' then
        o_ra <= regfile(to_integer(unsigned(i_rf.addr_a)));
        o_rb <= regfile(to_integer(unsigned(i_rf.addr_b)));
      end if;

    end if;
  end process p_rf;

  --
  -- Structural Hazard Handling : Forwarding WB value
  --
  fwd_a <= '1' when i_rf.we = '1' and i_rf.addr_a /= REG_X0 and i_rf.addr_a = i_rf.addr_w else
           '0';

  fwd_b <= '1' when i_rf.we = '1' and i_rf.addr_b /= REG_X0 and i_rf.addr_b = i_rf.addr_w else
           '0';

  p_fwd : process(i_clk, i_rstn) is
  begin
    if i_rstn = '0' then
      fwd_a_s <= '0';
      fwd_b_s <= '0';
      wb_data <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_rf.en = '1' then
        fwd_a_s <= fwd_a;
        fwd_b_s <= fwd_b;
        wb_data <= i_rf.data_w;
      end if;
    end if;
  end process p_fwd;

end architecture beh;
