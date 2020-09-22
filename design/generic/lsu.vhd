-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : lsu.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Load Store Unit
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity lsu is
  port (
    i_clk  : in  std_logic;
    i_rstn : in  std_logic;
    i_dmem : in  std_logic_vector(XLEN-1 downto 0);
    i_lsu  : in  keyv_to_lsu;
    o_lsu  : out keyv_from_lsu);
end entity lsu;

architecture beh of lsu is

  signal alignment       : std_logic_vector(1 downto 0);
  signal alignment_latch : std_logic_vector(1 downto 0);
  signal funct_latch     : std_logic_vector(FUNCT3_WIDTH-1 downto 0);
  signal mem_we          : std_logic_vector(BYTE_NB-1 downto 0);
  signal we_mask         : std_logic_vector(BYTE_NB-1 downto 0);

  signal read0  : std_logic_vector(BYTE_SIZE-1 downto 0);
  signal read1  : std_logic_vector(BYTE_SIZE-1 downto 0);
  signal read2  : std_logic_vector(BYTE_SIZE-1 downto 0);
  signal read3  : std_logic_vector(BYTE_SIZE-1 downto 0);
  signal read10 : std_logic_vector(2*BYTE_SIZE-1 downto 0);

begin

  --
  -- Align address
  --
  o_lsu.mem_addr <= i_lsu.base_addr(XLEN-1 downto 2) & "00";
  alignment      <= i_lsu.base_addr(1 downto 0);

  --
  -- Enable memory
  --
  o_lsu.mem_en <= i_lsu.load or i_lsu.store;

  --
  -- Set write-enable flags (little endian)
  --
  mem_we <= "0001" when i_lsu.funct = FCT_SB and alignment = "00" else
            "0010" when i_lsu.funct = FCT_SB and alignment = "01" else
            "0100" when i_lsu.funct = FCT_SB and alignment = "10" else
            "1000" when i_lsu.funct = FCT_SB and alignment = "11" else
            "0011" when i_lsu.funct = FCT_SH and alignment = "00" else
            "1100" when i_lsu.funct = FCT_SH and alignment = "10" else
            "1111";

  we_mask      <= (others => i_lsu.store);
  o_lsu.mem_we <= mem_we and we_mask;

  --
  -- Sort write-data
  --
  o_lsu.mem_write(31 downto 24) <= i_lsu.base_data(7 downto 0) when alignment = "11" else
                                   i_lsu.base_data(15 downto 8) when alignment = "10" else
                                   i_lsu.base_data(31 downto 24);

  o_lsu.mem_write(23 downto 16) <= i_lsu.base_data(7 downto 0) when alignment = "10" else
                                   i_lsu.base_data(23 downto 16);

  o_lsu.mem_write(15 downto 8) <= i_lsu.base_data(7 downto 0) when alignment = "01" else
                                  i_lsu.base_data(15 downto 8);

  o_lsu.mem_write(7 downto 0) <= i_lsu.base_data(7 downto 0);

  --
  -- Latch inputs
  --
  p_latch_inputs : process (i_clk, i_rstn)
  begin
    if i_rstn = '0' then
      alignment_latch <= (others => '0');
      funct_latch     <= (others => '0');
    elsif rising_edge(i_clk) then
      alignment_latch <= alignment;
      funct_latch     <= i_lsu.funct;
    end if;
  end process p_latch_inputs;

  --
  -- Sort read-data
  --
  read3 <= i_dmem(31 downto 24);
  read2 <= i_dmem(23 downto 16);

  read1 <= i_dmem(15 downto 8) when alignment_latch = "00" else
           i_dmem(31 downto 24);

  read0 <= i_dmem(7 downto 0) when alignment_latch = "00" else
           i_dmem(15 downto 8)  when alignment_latch = "01" else
           i_dmem(23 downto 16) when alignment_latch = "10" else
           i_dmem(31 downto 24);

  read10 <= read1 & read0;

  --
  -- sign/zero extend read output
  --
  o_lsu.mem_read <= std_logic_vector(resize(signed(read0), XLEN)) when funct_latch = FCT_LB else
                    std_logic_vector(resize(unsigned(read0), XLEN))  when funct_latch = FCT_LBU else
                    std_logic_vector(resize(signed(read10), XLEN))   when funct_latch = FCT_LH else
                    std_logic_vector(resize(unsigned(read10), XLEN)) when funct_latch = FCT_LHU else
                    read3 & read2 & read1 & read0;

end architecture beh;
