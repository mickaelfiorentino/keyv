-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : xbs.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Crossbar Switch
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.utils_pkg.all;
use work.keyv_pkg.all;

entity xbs is
  port (
    i_rstn       : in  std_logic;
    i_delay_cfg  : in  std_logic;
    i_delay_en   : in  std_logic;
    i_imem       : in  std_logic_vector(XLEN-1 downto 0);
    i_dmem       : in  std_logic_vector(XLEN-1 downto 0);
    from_keyring : in  keyv_from_keyring;
    to_keyring   : out keyv_to_keyring;
    from_xu      : in  keyv_from_xu_x;
    to_xu        : out keyv_to_xu_x;
    from_pc      : in  keyv_from_pc;
    to_pc        : out keyv_to_pc;
    from_idecode : in  keyv_from_idecode;
    to_idecode   : out keyv_to_idecode;
    from_rf      : in  keyv_from_rf;
    to_rf        : out keyv_to_rf;
    from_alu     : in  keyv_from_alu;
    to_alu       : out keyv_to_alu;
    from_perf    : in  keyv_from_perf;
    to_perf      : out keyv_to_perf;
    from_sys     : in  keyv_from_sys;
    to_sys       : out keyv_to_sys;
    from_lsu     : in  keyv_from_lsu;
    to_lsu       : out keyv_to_lsu);
end entity xbs;

architecture beh of xbs is

  signal F_sel, D_sel, R_sel, E_sel, M_sel, W_sel : std_logic_vector(KEYRING_E-1 downto 0);

  signal rf          : keyv_to_rf;
  signal alu         : keyv_to_alu;
  signal fwd_a       : keyv_fwd_xu_x;
  signal fwd_b       : keyv_fwd_xu_x;
  signal xu_to_alu   : keyv_alu_xu;
  signal flush_fwd   : keyv_logic_x;
  signal mul_flush_x : keyv_logic_x;
  signal mul_flush   : std_logic;

begin

  ------------------------------------------------------------------------------
  -- ONE-HOT SELECTION SIGNALS
  ------------------------------------------------------------------------------
  g_sel : for i in 0 to KEYRING_E-1 generate
    F_sel(i) <= from_keyring.states(i)(keyv_clk'pos(F));
    D_sel(i) <= from_keyring.states(i)(keyv_clk'pos(D));
    R_sel(i) <= from_keyring.states(i)(keyv_clk'pos(R));
    E_sel(i) <= from_keyring.states(i)(keyv_clk'pos(E));
    M_sel(i) <= from_keyring.states(i)(keyv_clk'pos(M));
    W_sel(i) <= from_keyring.states(i)(keyv_clk'pos(W));
  end generate g_sel;

  ------------------------------------------------------------------------------
  -- KEYRING DELAYS
  ------------------------------------------------------------------------------
  to_keyring.delay_cfg <= i_delay_cfg;
  to_keyring.delay_en  <= i_delay_en;

  ------------------------------------------------------------------------------
  -- PROGRAM COUNTER
  ------------------------------------------------------------------------------
  p_pc_sel : process (all)
    variable pc : keyv_to_pc;
  begin
    pc := from_xu(0).to_pc;
    for i in 1 to KEYRING_E-1 loop
      if W_sel(i) = '1' then
        pc := from_xu(i).to_pc;
      end if;
    end loop;
    to_pc <= pc;
  end process p_pc_sel;

  g_pc_xu : for e in 0 to KEYRING_E-1 generate
    to_xu(e).from_pc <= from_pc;
  end generate g_pc_xu;

  ------------------------------------------------------------------------------
  -- IDECODE
  ------------------------------------------------------------------------------
  p_idecode_sel : process (all)
    variable idecode : keyv_to_idecode;
  begin
    idecode := from_xu(0).to_idecode;
    for i in 1 to KEYRING_E-1 loop
      if R_sel(i) = '1' then
        idecode := from_xu(i).to_idecode;
      end if;
    end loop;
    to_idecode <= idecode;
  end process p_idecode_sel;

  g_id_xu : for e in 0 to KEYRING_E-1 generate
    to_xu(e).imem         <= i_imem;
    to_xu(e).from_idecode <= from_idecode;
  end generate g_id_xu;

  ------------------------------------------------------------------------------
  -- RF
  ------------------------------------------------------------------------------
  p_rf_sel : process (all)
    variable rfv : keyv_to_rf;
  begin
    rfv := from_xu(0).to_rf;
    for i in 1 to KEYRING_E-1 loop
      if R_sel(i) = '1' then
        rfv := from_xu(i).to_rf;
      end if;
    end loop;
    rf <= rfv;
  end process p_rf_sel;

  to_rf <= rf;

  g_rf : for e in 0 to KEYRING_E-1 generate
    to_xu(e).from_rf.data_a <= from_rf.data_a;
    to_xu(e).from_rf.data_b <= from_rf.data_b;
  end generate g_rf;

  ------------------------------------------------------------------------------
  -- ALU
  ------------------------------------------------------------------------------
  p_alu_sel : process (all)
    variable xualu : keyv_alu_xu;
  begin
    xualu := from_xu(0).to_alu;
    for i in 1 to KEYRING_E-1 loop
      if E_sel(i) = '1' then
        xualu := from_xu(i).to_alu;
      end if;
    end loop;
    xu_to_alu <= xualu;
  end process p_alu_sel;

  g_mul_flush : for e in 0 to KEYRING_E-1 generate
    p_mul_flush : process(all)
      variable flush : std_logic;
    begin
      flush := '0';
      for i in KEYRING_E-1 downto 2 loop
        if (from_xu(get_click(e-i, KEYRING_E)).flush = '1') then
          flush := '1';
        end if;
      end loop;
      mul_flush_x(e) <= flush;
    end process p_mul_flush;
  end generate g_mul_flush;

  p_mulflush_sel : process (all)
    variable mulflush : std_logic;
  begin
    mulflush := mul_flush_x(0);
    for i in 1 to KEYRING_E-1 loop
      if E_sel(i) = '1' then
        mulflush := mul_flush_x(i);
      end if;
    end loop;
    mul_flush <= mulflush;
  end process p_mulflush_sel;

  alu.arith  <= from_idecode.arith;
  alu.sign   <= from_idecode.sign;
  alu.opcode <= from_idecode.alu_op;
  alu.mul    <= xu_to_alu.mul and not(mul_flush);
  alu.div    <= xu_to_alu.div and not(mul_flush);

  alu.port_a <= xu_to_alu.pc when (from_idecode.src1 = SRC1_PC) else
                xu_to_alu.fwd_a.data when (xu_to_alu.fwd_a.flag = '1') else
                from_rf.data_a;

  alu.port_b <= from_idecode.imm when (from_idecode.src2 = SRC2_IM) else
                xu_to_alu.fwd_b.data when (xu_to_alu.fwd_b.flag = '1') else
                from_rf.data_b;

  alu.shamt <= alu.port_b(SHAMT_WIDTH-1 downto 0) when (from_idecode.src2 = SRC2_R) else
               from_idecode.shamt;

  to_alu <= alu;

  g_alu_xu : for e in 0 to KEYRING_E-1 generate
    to_xu(e).from_alu <= from_alu;
  end generate g_alu_xu;

  to_keyring.m_start <= alu.mul or alu.div;
  to_keyring.m_stop  <= from_alu.mul_valid or from_alu.div_valid;

  ------------------------------------------------------------------------------
  -- FORWARD
  --
  --    Each XU can receive forwarded value from any other XU (port a & b)
  --    Priority to the closest XU in the dependency list
  ------------------------------------------------------------------------------
  g_fwd : for e in 0 to KEYRING_E-1 generate

    p_fwd_a : process (all) is
      variable fwd : keyv_fwd_xu;
    begin
      fwd.flag := '0';
      fwd.busy := '0';
      fwd.data := from_rf.data_a;
      if (from_xu(e).to_rf.addr_a /= REG_X0) then
        for i in KEYRING_E-1 downto 1 loop
          if (from_xu(get_click(e-i, KEYRING_E)).to_rf.we = '1') then
            if (flush_fwd(get_click(e-i, KEYRING_E)) = '0') then
              if (from_xu(get_click(e-i, KEYRING_E)).to_rf.addr_w = from_xu(e).to_rf.addr_a) then
                fwd.flag := '1';
                fwd.busy := from_xu(get_click(e-i, KEYRING_E)).busy;
                fwd.data := from_xu(get_click(e-i, KEYRING_E)).to_rf.data_w;
              end if;
            end if;
          end if;
        end loop;
        for i in KEYRING_E-1 downto 3 loop
          if (from_xu(get_click(e-i, KEYRING_E)).flush = '1') then
            fwd.flag := '0';
            fwd.busy := '0';
          end if;
        end loop;
      end if;
      fwd_a(e) <= fwd;
    end process p_fwd_a;

    p_fwd_b : process (all) is
      variable fwd : keyv_fwd_xu;
    begin
      fwd.flag := '0';
      fwd.busy := '0';
      fwd.data := from_rf.data_b;
      if (from_xu(e).to_rf.addr_b /= REG_X0) then
        for i in KEYRING_E-1 downto 1 loop
          if (from_xu(get_click(e-i, KEYRING_E)).to_rf.we = '1') then
            if (flush_fwd(get_click(e-i, KEYRING_E)) = '0') then
              if (from_xu(get_click(e-i, KEYRING_E)).to_rf.addr_w = from_xu(e).to_rf.addr_b) then
                fwd.flag := '1';
                fwd.busy := from_xu(get_click(e-i, KEYRING_E)).busy;
                fwd.data := from_xu(get_click(e-i, KEYRING_E)).to_rf.data_w;
              end if;
            end if;
          end if;
        end loop;
        for i in KEYRING_E-1 downto 3 loop
          if (from_xu(get_click(e-i, KEYRING_E)).flush = '1') then
            fwd.flag := '0';
            fwd.busy := '0';
          end if;
        end loop;
      end if;
      fwd_b(e) <= fwd;
    end process p_fwd_b;

    to_xu(e).from_fwd_a <= fwd_a(e);
    to_xu(e).from_fwd_b <= fwd_b(e);

  end generate g_fwd;

  ------------------------------------------------------------------------------
  -- STALLS
  --
  --    Stall XU @R
  --    - While forwarding XUs are busy
  --    - While previous XU is computing a mul/div
  ------------------------------------------------------------------------------
  g_stalls : for i in 0 to KEYRING_E-1 generate
    to_keyring.stalls(i) <=
      (keyv_clk'pos(R) => (
           (fwd_a(i).flag and fwd_a(i).busy)
        or (fwd_b(i).flag and fwd_b(i).busy)
        or from_xu(get_click(i-1, KEYRING_E)).to_alu.mul
        or from_xu(get_click(i-1, KEYRING_E)).to_alu.div),
       others => '0');
  end generate g_stalls;

  ------------------------------------------------------------------------------
  -- FLUSH
  --
  --    An XU flush all other XUs @M
  --    Target instruction is fetched into flushing XU
  --    A flushed XU is 'deflushed' @next-cycle using flush_n @D
  ------------------------------------------------------------------------------
  g_flushs : for e in 0 to KEYRING_E-1 generate

    p_flushs : process(all)
      variable flush : std_logic;
    begin
      flush := '0';
      for s in 1 to KEYRING_S-1 loop
        if (from_xu(get_click(e-s, KEYRING_E)).flush = '1') then
          flush := '1';
        end if;
      end loop;
      flush_fwd(e)   <= flush and not(from_xu(e).flushed);
      to_xu(e).flush <= flush;
    end process p_flushs;

  end generate g_flushs;

  ------------------------------------------------------------------------------
  -- PERFORMANCE COUNTERS
  ------------------------------------------------------------------------------
  p_perf_sel : process (all)
    variable perf : keyv_to_perf;
  begin
    perf := from_xu(0).to_perf;
    for i in 1 to KEYRING_E-1 loop
      if M_sel(i) = '1' then
        perf := from_xu(i).to_perf;
      end if;
    end loop;
    to_perf <= perf;
  end process p_perf_sel;

  ------------------------------------------------------------------------------
  -- SYS
  ------------------------------------------------------------------------------
  p_sys_sel : process (all)
    variable sys : keyv_to_sys;
  begin
    sys := from_xu(0).to_sys;
    for i in 1 to KEYRING_E-1 loop
      if M_sel(i) = '1' then
        sys := from_xu(i).to_sys;
      end if;
    end loop;
    to_sys <= sys;
  end process p_sys_sel;

  g_sys_xu : for e in 0 to KEYRING_E-1 generate
    to_xu(e).from_sys <= from_sys;
  end generate g_sys_xu;

  ------------------------------------------------------------------------------
  -- LSU
  ------------------------------------------------------------------------------
  p_lsu_sel : process (all)
    variable lsu : keyv_to_lsu;
  begin
    lsu := from_xu(0).to_lsu;
    for i in 1 to KEYRING_E-1 loop
      if M_sel(i) = '1' then
        lsu := from_xu(i).to_lsu;
      end if;
    end loop;
    to_lsu <= lsu;
  end process p_lsu_sel;

  g_lsu_xu : for e in 0 to KEYRING_E-1 generate
    to_xu(e).from_lsu <= from_lsu;
  end generate g_lsu_xu;

end architecture beh;
