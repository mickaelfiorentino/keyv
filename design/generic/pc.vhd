-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : pc.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Program Counter
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity pc is
  port (
    i_clk  : in  std_logic;
    i_rstn : in  std_logic;
    i_pc   : in  keyv_to_pc;
    o_pc   : out keyv_from_pc);
end entity pc;

architecture beh of pc is

  signal pc         : unsigned(XLEN-1 downto 0);
  signal invalidate : std_logic;

begin

  -- Outputs
  o_pc.pc         <= std_logic_vector(pc);
  o_pc.invalidate <= invalidate;

  -- Next PC
  p_pc : process (i_clk, i_rstn)
  begin
    if i_rstn = '0' then
      pc         <= unsigned(RESET_VECTOR);
      invalidate <= '0';
    elsif rising_edge(i_clk) then
      if i_pc.stall = '0' then
        if i_pc.branch = '1' then
          pc         <= unsigned(i_pc.origin) + unsigned(i_pc.target);
          invalidate <= '1';
        elsif i_pc.sys = '1' then
          pc         <= unsigned(i_pc.target);
          invalidate <= '1';
        elsif i_pc.jump = '1' then
          pc         <= unsigned(i_pc.target and JUMP_MASK);
          invalidate <= '1';
        else
          pc         <= pc + PC_INCR;
          invalidate <= '0';
        end if;
      end if;
    end if;
  end process p_pc;

end architecture beh;
