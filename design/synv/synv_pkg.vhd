-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : synv_pkg.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Synchronous core package
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

package keyv_pkg is

  ------------------------------------------------------------------------------
  --                             CLOCK AND RESET
  ------------------------------------------------------------------------------
  component clock_and_reset is
    port (
      i_rstn : in  std_logic;
      i_clk  : in  std_logic;
      o_rstn : out std_logic;
      o_clk  : out std_logic);
  end component clock_and_reset;

  ------------------------------------------------------------------------------
  --                                  ALU
  ------------------------------------------------------------------------------
  type keyv_to_alu is record
    arith    : std_logic;
    mul      : std_logic;
    div      : std_logic;
    sign     : std_logic_vector(1 downto 0);
    opcode   : std_logic_vector(ALU_OP_WIDTH-1 downto 0);
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
      i_clk  : in  std_logic;
      i_rstn : in  std_logic;
      i_alu  : in  keyv_to_alu;
      o_alu  : out keyv_from_alu);
  end component alu;

  ------------------------------------------------------------------------------
  --                                FORWARD
  ------------------------------------------------------------------------------
  function forward (
    signal en           : in  std_logic;
    signal addr_default : in  std_logic_vector(REG_WIDTH-1 downto 0);
    signal addr_fwd     : in  std_logic_vector(REG_WIDTH-1 downto 0))
  return boolean;

end package keyv_pkg;
package body keyv_pkg is

  function forward (
    signal en           : in  std_logic;
    signal addr_default : in  std_logic_vector(REG_WIDTH-1 downto 0);
    signal addr_fwd     : in  std_logic_vector(REG_WIDTH-1 downto 0))
  return boolean is
  begin
    if ((addr_default /= REG_X0) and en = '1') then
      if (addr_fwd = addr_default) then
        return true;
      else
        return false;
      end if;
    else
      return false;
    end if;
  end function forward;

end package body keyv_pkg;
