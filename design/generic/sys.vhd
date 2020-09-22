-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : sys.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : System calls: TIMER, CSR, CALL, BREAK, FENCE
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity sys is
  port (
    i_clk     : in  std_logic;
    i_rstn    : in  std_logic;
    i_cycle   : in  std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);
    i_instret : in  std_logic_vector(PERFCOUNT_WIDTH-1 downto 0);
    i_sys     : in  keyv_to_sys;
    o_sys     : out keyv_from_sys);
end entity sys;

architecture beh of sys is

  -- CSR
  signal mcycle    : unsigned(PERFCOUNT_WIDTH-1 downto 0);
  signal minstret  : unsigned(PERFCOUNT_WIDTH-1 downto 0);
  signal mcause    : unsigned(XLEN-1 downto 0);
  signal mepc      : unsigned(XLEN-1 downto 0);
  signal mepc_pc   : unsigned(XLEN-1 downto 0);
  signal mepc_flag : std_logic;

  -- CSR Read/Write
  signal csr_read  : std_logic_vector(XLEN-1 downto 0);
  signal csr_write : std_logic_vector(XLEN-1 downto 0);

  -- Instruction invalidate
  signal pctarget   : std_logic_vector(XLEN-1 downto 0);
  signal invalidate : std_logic;
  signal ebreak     : std_logic;

begin

  o_sys.invalidate <= invalidate;
  o_sys.pc         <= pctarget;
  o_sys.rd         <= csr_read;

  ------------------------------------------------------------------------------
  --                                    CSRs
  ------------------------------------------------------------------------------

  mcycle   <= unsigned(i_cycle);
  minstret <= unsigned(i_instret);

  with i_sys.csrsel select csr_read <=
    std_logic_vector(mcycle((PERFCOUNT_WIDTH/2)-1 downto 0))               when CSR_MCYCLE,
    std_logic_vector(mcycle(PERFCOUNT_WIDTH-1 downto PERFCOUNT_WIDTH/2))   when CSR_MCYCLEH,
    std_logic_vector(minstret((PERFCOUNT_WIDTH/2)-1 downto 0))             when CSR_MINSTRET,
    std_logic_vector(minstret(PERFCOUNT_WIDTH-1 downto PERFCOUNT_WIDTH/2)) when CSR_MINSTRETH,
    std_logic_vector(mcause)                                               when CSR_MCAUSE,
    std_logic_vector(mepc)                                                 when CSR_MEPC,
    (others => '0')                                                        when others;

  p_csrw : process(i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      csr_write <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_sys.csrwe = '1' then
        case i_sys.csrfunct is
          when FCT_CSRRW | FCT_CSRRWI => csr_write <= i_sys.rs1;
          when FCT_CSRRS | FCT_CSRRSI => csr_write <= csr_read or i_sys.rs1;
          when FCT_CSRRC | FCT_CSRRCI => csr_write <= csr_read and not i_sys.rs1;
          when others                 => csr_write <= csr_read;
        end case;
      end if;
    end if;
  end process p_csrw;

  p_mepc : process(i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      mepc_pc   <= unsigned(RESET_VECTOR);
      mepc_flag <= '0';
    elsif rising_edge(i_clk) then
      if i_sys.sys = '1' and i_sys.stall = '0' then
        mepc_pc <= unsigned(i_sys.pc);
        if (i_sys.legal = '1' and i_sys.csrfunct /= FCT_ECALL_EBREAK) then
          mepc_flag <= '1';
        else
          mepc_flag <= '0';
        end if;
      end if;
    end if;
  end process p_mepc;

  mepc <= unsigned(csr_write) when mepc_flag = '1' else mepc_pc;

  p_mcause : process(i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      mcause <= (others => '0');
    elsif rising_edge(i_clk) then
      if i_sys.sys = '1' and i_sys.stall = '0' then
        if i_sys.legal = '1' then
          if i_sys.csrfunct = FCT_ECALL_EBREAK then
            mcause <= to_unsigned(CSR_MCAUSE_BREAK, mcause'length);
          end if;
        else
          mcause <= to_unsigned(CSR_MCAUSE_ILLEGAL, mcause'length);
        end if;
      end if;
    end if;
  end process p_mcause;

  ------------------------------------------------------------------------------
  --                           INVALIDATE / PC TARGET
  ------------------------------------------------------------------------------

  ebreak <= '1' when (i_sys.sys = '1' and i_sys.csrfunct = FCT_ECALL_EBREAK) else '0';

  invalidate <= '1' when (i_sys.legal = '0' or ebreak = '1' or i_sys.fence = '1') else
                '0';

  p_pctarget : process (i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      pctarget <= RESET_VECTOR;
    elsif rising_edge(i_clk) then
      if i_sys.sys = '1' and i_sys.stall = '0' then
        if (i_sys.legal = '0' or ebreak = '1') then
          pctarget <= RESET_VECTOR;
        elsif (i_sys.fence = '1') then
          pctarget <= std_logic_vector(unsigned(i_sys.pc) + PC_INCR);
        else
          pctarget <= i_sys.pc;
        end if;
      end if;
    end if;
  end process p_pctarget;

end architecture beh;
