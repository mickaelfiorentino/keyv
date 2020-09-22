-------------------------------------------------------------------------------
-- Project : Key-V
-- File    : dpm.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-25
-- Brief   : Dual Port Memory, dual clock, Byte addressable
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;

entity dpm is
  generic (
    XLEN      : integer := 32;
    DEPTH     : integer := 10;
    RESET     : integer := 16#00000000#;
    INIT_FILE : string  := "mem.hex");
  port (
    -- Port A
    i_a_clk   : in  std_logic;                              -- Clock
    i_a_rstn  : in  std_logic;                              -- Reset Address
    i_a_en    : in  std_logic;                              -- Port enable
    i_a_we    : in  std_logic_vector((XLEN/8)-1 downto 0);  -- Write enable
    i_a_addr  : in  std_logic_vector(DEPTH-1 downto 0);     -- Address port
    i_a_write : in  std_logic_vector(XLEN-1 downto 0);      -- Data write port
    o_a_read  : out std_logic_vector(XLEN-1 downto 0);      -- Data read port
    -- Port B
    i_b_clk   : in  std_logic;                              -- Clock
    i_b_rstn  : in  std_logic;                              -- Reset Address
    i_b_en    : in  std_logic;                              -- Port enable
    i_b_we    : in  std_logic_vector((XLEN/8)-1 downto 0);  -- Write enable
    i_b_addr  : in  std_logic_vector(DEPTH-1 downto 0);     -- Address port
    i_b_write : in  std_logic_vector(XLEN-1 downto 0);      -- Data write port
    o_b_read  : out std_logic_vector(XLEN-1 downto 0));     -- Data read port
end entity dpm;

architecture beh of dpm is

  constant BYTE    : positive := 8;
  constant BYTE_NB : natural  := XLEN / BYTE;
  type memory_t is array(0 to 2**DEPTH-1) of std_logic_vector(XLEN-1 downto 0);

  --
  -- LOAD_MEM Function
  --
  impure function load_mem(constant file_name : in string) return memory_t is

    file ramfile            : text;
    variable file_status    : file_open_status;
    variable L              : line    := null;
    variable Lnum           : natural := 0;
    variable read_ok        : boolean := true;
    variable at_char        : std_logic;
    variable next_address   : natural := 0;
    variable next_address_u : unsigned(XLEN-1 downto 0);
    variable ram            : memory_t;

  begin
    -- Init RAM to 0
    ram := (others => (others => '0'));

    if (file_name /= "") then
      -- Open init file
      file_open(f         => ramfile, external_name => file_name,
                open_kind => read_mode, status => file_status);
      -- Check opening status
      assert file_status = open_ok
        report "load_mem: " & to_string(file_status) & " opening file " & file_name
        severity error;
      -- Read and parse memory .hex file, and fill ram with its content
      loop
        -- Exit condition
        exit when not read_ok or endfile(ramfile);
        -- Read line
        readline(ramfile, L);
        if L(L'left) = '@' then
          -- Read address
          read(L, at_char, read_ok);
          hread(L, next_address_u, read_ok);
          -- Check that read was ok
          assert read_ok = true
            report "load_mem: Error reading address at line: " & to_string(Lnum) & " in file " & file_name
            severity error;
          -- Update next_address
          next_address := to_integer(next_address_u);
        else
          -- Read data
          hread(L, ram(next_address), read_ok);
          -- Check that read was ok
          assert read_ok = true
            report "load_mem: Error reading data at address: " & to_string(next_address) & " in file " & file_name
            severity error;
          -- Update next address
          next_address := next_address + 1;
        end if;
        -- Increment Line number
        Lnum := Lnum + 1;
      end loop;
      -- Close init file
      file_close(f => ramfile);
    end if;

    return ram;
  end function load_mem;

  --
  -- Memory signals
  --
  signal mem      : memory_t := load_mem(INIT_FILE);
  signal a_addr_r : std_logic_vector(DEPTH-1 downto 0);
  signal b_addr_r : std_logic_vector(DEPTH-1 downto 0);

begin

  p_dpm : process (i_a_clk, i_a_rstn, i_b_clk, i_b_rstn) is
    variable iaddr_a : natural;
    variable iaddr_b : natural;
  begin

    -- PORT A
    if i_a_rstn = '0' then
      a_addr_r <= (others => '0');
    elsif rising_edge(i_a_clk) then
      if i_a_en = '1' then
        iaddr_a := to_integer(unsigned(i_a_addr));
        for i in 0 to BYTE_NB-1 loop
          if i_a_we(i) = '1' then
            mem(iaddr_a)((i+1)*BYTE-1 downto i*BYTE) <= i_a_write((i+1)*BYTE-1 downto i*BYTE);
          end if;
        end loop;
        a_addr_r <= i_a_addr;
      end if;
    end if;

    -- PORT B
    if i_b_rstn = '0' then
      b_addr_r <= (others => '0');
    elsif rising_edge(i_b_clk) then
      if i_b_en = '1' then
        iaddr_b := to_integer(unsigned(i_b_addr));
        for j in 0 to BYTE_NB-1 loop
          if i_b_we(j) = '1' then
            mem(iaddr_b)((j+1)*BYTE-1 downto j*BYTE) <= i_b_write((j+1)*BYTE-1 downto j*BYTE);
          end if;
        end loop;
        b_addr_r <= i_b_addr;
      end if;
    end if;

  end process p_dpm;

  o_a_read <= mem(to_integer(unsigned(a_addr_r)));
  o_b_read <= mem(to_integer(unsigned(b_addr_r)));

end architecture beh;
