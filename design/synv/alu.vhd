-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : synv/alu.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : ALU / MUL-DIV (Synchronous Core)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity alu is
  port (
    i_clk  : in  std_logic;
    i_rstn : in  std_logic;
    i_alu  : in  keyv_to_alu;
    o_alu  : out keyv_from_alu);
end entity alu;

architecture beh of alu is

  component shifter is
    port (
      i_type    : in  std_logic;
      i_arith   : in  std_logic;
      i_operand : in  std_logic_vector(XLEN-1 downto 0);
      i_shamt   : in  std_logic_vector(SHAMT_WIDTH-1 downto 0);
      o_res     : out std_logic_vector(XLEN-1 downto 0));
  end component shifter;

  component adder is
    port (
      i_arith : in  std_logic;
      i_sign  : in  std_logic_vector(1 downto 0);
      i_op_a  : in  std_logic_vector(XLEN-1 downto 0);
      i_op_b  : in  std_logic_vector(XLEN-1 downto 0);
      o_res   : out std_logic_vector(XLEN downto 0));
  end component adder;

  component multiplier is
    port (
      i_rstn  : in  std_logic;
      i_clk   : in  std_logic;
      i_en    : in  std_logic;
      i_sign  : in  std_logic_vector(1 downto 0);
      i_op_a  : in  std_logic_vector(XLEN-1 downto 0);
      i_op_b  : in  std_logic_vector(XLEN-1 downto 0);
      o_valid : out std_logic;
      o_res   : out std_logic_vector(XLEN*2-1 downto 0));
  end component multiplier;

  component divider is
    port (
      i_rstn  : in  std_logic;
      i_clk   : in  std_logic;
      i_en    : in  std_logic;
      i_sign  : in  std_logic_vector(1 downto 0);
      i_op_a  : in  std_logic_vector(XLEN-1 downto 0);
      i_op_b  : in  std_logic_vector(XLEN-1 downto 0);
      o_valid : out std_logic;
      o_rem   : out std_logic_vector(XLEN-1 downto 0);
      o_quo   : out std_logic_vector(XLEN-1 downto 0));
  end component divider;

  signal shift_res : std_logic_vector(XLEN-1 downto 0);
  signal adder_res : std_logic_vector(XLEN downto 0);
  signal slt_res   : unsigned(XLEN-1 downto 0);
  signal beq_res   : unsigned(XLEN-1 downto 0);
  signal mul_res   : std_logic_vector(XLEN*2-1 downto 0);
  signal rem_res   : std_logic_vector(XLEN-1 downto 0);
  signal quo_res   : std_logic_vector(XLEN-1 downto 0);
  signal alu_res   : std_logic_vector(XLEN-1 downto 0);

  signal mul_valid : std_logic;
  signal div_valid : std_logic;

begin

  ------------------------------------------------------------------------------
  --                              RESULT SELECTION
  ------------------------------------------------------------------------------

  p_alu : process(i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      alu_res <= (others => '0');
    elsif rising_edge(i_clk) then
      case i_alu.opcode is
        when ALU_OP_ADD  => alu_res <= adder_res(XLEN-1 downto 0);  -- ADD[I]/SUB[I]
        when ALU_OP_SLT  => alu_res <= std_logic_vector(slt_res);  -- SLT[I,U]/BLT[U]/BGE[U]
        when ALU_OP_BEQ  => alu_res <= std_logic_vector(beq_res);  -- BEQ/BNE
        when ALU_OP_SL   => alu_res <= shift_res;  -- SLL[I]
        when ALU_OP_SR   => alu_res <= shift_res;  -- SRL[I]/SRA[I]
        when ALU_OP_XOR  => alu_res <= i_alu.port_a xor i_alu.port_b;  -- XOR[I]
        when ALU_OP_OR   => alu_res <= i_alu.port_a or i_alu.port_b;   -- OR[I]
        when ALU_OP_AND  => alu_res <= i_alu.port_a and i_alu.port_b;  -- AND[I]
        when ALU_OP_MUL  => alu_res <= std_logic_vector(resize(unsigned(mul_res), XLEN));  -- MUL
        when ALU_OP_MULH => alu_res <= mul_res(XLEN*2-1 downto XLEN);  -- MULH[SU]
        when ALU_OP_DIV  => alu_res <= quo_res;    -- DIV[U]
        when ALU_OP_REM  => alu_res <= rem_res;    -- REM[U]
        when others      => alu_res <= i_alu.port_b;               -- Default
      end case;
    end if;
  end process p_alu;

  o_alu.port_z    <= alu_res;
  o_alu.mul_valid <= mul_valid;
  o_alu.div_valid <= div_valid;

  ------------------------------------------------------------------------------
  --                                ADDER / SHIFTER
  ------------------------------------------------------------------------------

  u_shift : shifter
    port map (
      i_type    => i_alu.opcode(FUNCT3_WIDTH-1),
      i_arith   => i_alu.arith,
      i_operand => i_alu.port_a,
      i_shamt   => i_alu.shamt,
      o_res     => shift_res);

  u_add : adder
    port map (
      i_arith => i_alu.arith,
      i_sign  => i_alu.sign,
      i_op_a  => i_alu.port_a,
      i_op_b  => i_alu.port_b,
      o_res   => adder_res);

  slt_res <= to_unsigned(1, slt_res'length) when adder_res(adder_res'left) = '1' else
             to_unsigned(0, slt_res'length);

  beq_res <= to_unsigned(1, beq_res'length) when signed(adder_res) = to_signed(0, adder_res'length) else
             to_unsigned(0, beq_res'length);

  ------------------------------------------------------------------------------
  --                                  MUL / DIV
  ------------------------------------------------------------------------------

  u_mul : multiplier
    port map (
      i_rstn  => i_rstn,
      i_clk   => i_clk,
      i_en    => i_alu.mul,
      i_sign  => i_alu.sign,
      i_op_a  => i_alu.port_a,
      i_op_b  => i_alu.port_b,
      o_valid => mul_valid,
      o_res   => mul_res);

  u_div : divider
    port map (
      i_rstn  => i_rstn,
      i_clk   => i_clk,
      i_en    => i_alu.div,
      i_sign  => i_alu.sign,
      i_op_a  => i_alu.port_a,
      i_op_b  => i_alu.port_b,
      o_valid => div_valid,
      o_rem   => rem_res,
      o_quo   => quo_res);

end architecture beh;

-------------------------------------------------------------------------------
--
-- SHIFTER
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity shifter is
  port (
    i_type    : in  std_logic;
    i_arith   : in  std_logic;
    i_operand : in  std_logic_vector(XLEN-1 downto 0);
    i_shamt   : in  std_logic_vector(SHAMT_WIDTH-1 downto 0);
    o_res     : out std_logic_vector(XLEN-1 downto 0));
end entity shifter;

architecture beh of shifter is

  signal sl_src    : std_logic_vector(XLEN-1 downto 0);
  signal shift_sel : std_logic;
  signal shift_src : std_logic_vector(XLEN-1 downto 0);
  signal srl_res   : unsigned(XLEN-1 downto 0);
  signal sra_res   : signed(XLEN-1 downto 0);
  signal sl_res    : unsigned(XLEN-1 downto 0);
  signal sr_res    : unsigned(XLEN-1 downto 0);

begin

  -- Shift Left : reverse operand bits
  gen_sl_op : for i in 0 to XLEN-1 generate
    sl_src(i) <= i_operand(XLEN-1-i);
  end generate gen_sl_op;

  -- Shift operand selection
  shift_src <= sl_src when (i_type = '0') else i_operand;

  -- Shift operation : shift-right;
  sra_res <= shift_right(signed(shift_src), to_integer(unsigned(i_shamt)));
  srl_res <= shift_right(unsigned(shift_src), to_integer(unsigned(i_shamt)));

  -- Shift-right type (arithmetic or logic)
  sr_res <= unsigned(sra_res) when i_arith = '1' else srl_res;

  -- Shift Left : reverse operand bits
  gen_sl_res : for i in 0 to XLEN-1 generate
    sl_res(i) <= sr_res(XLEN-1-i);
  end generate gen_sl_res;

  -- Shift result selection
  o_res <= std_logic_vector(sl_res) when i_type = '0' else
           std_logic_vector(sr_res);

end architecture beh;

-------------------------------------------------------------------------------
--
-- ADDER
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity adder is
  port (
    i_arith : in  std_logic;
    i_sign  : in  std_logic_vector(1 downto 0);
    i_op_a  : in  std_logic_vector(XLEN-1 downto 0);
    i_op_b  : in  std_logic_vector(XLEN-1 downto 0);
    o_res   : out std_logic_vector(XLEN downto 0));
end entity adder;

architecture beh of adder is

  signal arith_msb1 : std_logic;
  signal arith_msb2 : std_logic;
  signal arith_src1 : signed(XLEN downto 0);
  signal arith_src2 : signed(XLEN downto 0);
  signal result     : signed(XLEN downto 0);

begin

  arith_msb1 <= '0' when (i_sign(0) = '0') else i_op_a(i_op_a'left);
  arith_msb2 <= '0' when (i_sign(1) = '0') else i_op_b(i_op_b'left);

  arith_src1 <= signed(arith_msb1 & i_op_a);
  arith_src2 <= signed(arith_msb2 & i_op_b);

  result <= arith_src1 - arith_src2 when i_arith = '1' else
            arith_src1 + arith_src2;

  o_res <= std_logic_vector(result);

end architecture beh;

-------------------------------------------------------------------------------
--
-- MULTIPLIER (32 cycles)
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity multiplier is
  port (
    i_rstn  : in  std_logic;
    i_clk   : in  std_logic;
    i_en    : in  std_logic;
    i_sign  : in  std_logic_vector(1 downto 0);
    i_op_a  : in  std_logic_vector(XLEN-1 downto 0);
    i_op_b  : in  std_logic_vector(XLEN-1 downto 0);
    o_valid : out std_logic;
    o_res   : out std_logic_vector(XLEN*2-1 downto 0));
end entity multiplier;

architecture beh of multiplier is

  signal mul_init       : unsigned(XLEN*2 downto 0);
  signal mul_src1       : unsigned(XLEN downto 0);
  signal mul_src2       : unsigned(XLEN downto 0);
  signal mul_src2_latch : unsigned(XLEN downto 0);
  signal mul_count      : natural range XLEN-1 downto 0;
  signal mul_neg_src1   : std_logic;
  signal mul_neg_src2   : std_logic;
  signal mul_neg        : std_logic;
  signal mul_neg_latch  : std_logic;
  signal mul_valid      : std_logic;
  signal mul_arith_a    : unsigned(XLEN-1 downto 0);
  signal mul_arith_p    : unsigned(XLEN downto 0);
  signal mul_arith_b    : unsigned(XLEN downto 0);
  signal mul            : unsigned(XLEN*2 downto 0);
  signal mul_arith      : unsigned(XLEN downto 0);
  signal mul_shift      : unsigned(XLEN*2 downto 0);
  signal mul_latch      : unsigned(XLEN*2 downto 0);

begin

  --
  -- Ouputs
  --
  o_res <= std_logic_vector(mul_latch(XLEN*2-1 downto 0)) when mul_neg_latch = '0' else
           std_logic_vector(unsigned(resize(-signed(mul_latch), XLEN*2)));

  o_valid <= mul_valid;

  --
  -- Inputs
  --
  mul_neg_src1 <= i_sign(0) and i_op_a(i_op_a'left);
  mul_neg_src2 <= i_sign(1) and i_op_b(i_op_b'left);
  mul_neg      <= mul_neg_src1 xor mul_neg_src2;

  mul_src1 <= resize(unsigned(i_op_a), XLEN+1) when mul_neg_src1 = '0' else
              resize(unsigned(-signed(i_op_a)), XLEN+1);

  mul_src2 <= resize(unsigned(i_op_b), XLEN+1) when mul_neg_src2 = '0' else
              resize(unsigned(-signed(i_op_b)), XLEN+1);

  mul_init(XLEN*2 downto XLEN) <= (others => '0');
  mul_init(XLEN-1 downto 0)    <= mul_src1(XLEN-1 downto 0);

  mul <= mul_init when mul_count = XLEN-1 else
         mul_latch;

  mul_arith_b <= mul_src2_latch when (mul(0) = '1' and mul_count < XLEN-1) else
                 mul_src2 when (mul(0) = '1' and mul_count = XLEN-1) else
                 (others => '0');

  mul_arith_a <= mul(XLEN-1 downto 0);
  mul_arith_p <= mul(XLEN*2 downto XLEN);

  mul_arith <= mul_arith_p + mul_arith_b;
  mul_shift <= shift_right(mul_arith & mul_arith_a, 1);

  -- mul_valid <= '1' when mul_count = 0 else '0';

  p_mul : process(i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      mul_count      <= XLEN-1;
      mul_latch      <= (others => '0');
      mul_src2_latch <= (others => '0');
      mul_neg_latch  <= '0';
      mul_valid      <= '0';
    elsif rising_edge(i_clk) then
      if i_en = '1' then

        -- Counter: Start = XLEN-1, end = 0
        if mul_count = 0 then
          mul_count <= XLEN-1;
          mul_valid <= '1';
        else
          mul_valid <= '0';
          if mul_valid = '0' then
            mul_count <= mul_count - 1;
          end if;
        end if;

        -- Init
        if mul_count = XLEN-1 then
          mul_src2_latch <= mul_src2;
          mul_neg_latch  <= mul_neg;
        end if;

        -- Multiplication
        mul_latch <= mul_shift;

      end if;
    end if;
  end process p_mul;

end architecture beh;

-------------------------------------------------------------------------------
--
-- DIVIDER (non-restoring division algorithm - 32 cycles)
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;
use work.keyv_pkg.all;

entity divider is
  port (
    i_rstn  : in  std_logic;
    i_clk   : in  std_logic;
    i_en    : in  std_logic;
    i_sign  : in  std_logic_vector(1 downto 0);
    i_op_a  : in  std_logic_vector(XLEN-1 downto 0);
    i_op_b  : in  std_logic_vector(XLEN-1 downto 0);
    o_valid : out std_logic;
    o_rem   : out std_logic_vector(XLEN-1 downto 0);
    o_quo   : out std_logic_vector(XLEN-1 downto 0));
end entity divider;

architecture beh of divider is

  type t_div is (IDLE, WORKING);

  signal div_state      : t_div;
  signal div_init       : unsigned(XLEN*2 downto 0);
  signal div_src1       : unsigned(XLEN downto 0);
  signal div_src1_latch : unsigned(XLEN-1 downto 0);
  signal div_src2       : unsigned(XLEN downto 0);
  signal div_src2_latch : unsigned(XLEN downto 0);
  signal div_count      : natural range XLEN-1 downto 0;
  signal div_stall      : std_logic;
  signal div_valid      : std_logic;
  signal div_en         : std_logic;
  signal div_neg_src1   : std_logic;
  signal div_neg_src2   : std_logic;
  signal div_neg_rem    : std_logic;
  signal div_neg_quo    : std_logic;
  signal div_quo        : unsigned(XLEN-1 downto 0);
  signal div_quotient   : unsigned(XLEN-1 downto 0);
  signal div_rem        : unsigned(XLEN downto 0);
  signal div_remainder  : unsigned(XLEN-1 downto 0);
  signal div_arith_a    : unsigned(XLEN-1 downto 0);
  signal div_arith_p    : unsigned(XLEN downto 0);
  signal div_arith_b    : unsigned(XLEN downto 0);
  signal div_arith      : unsigned(XLEN downto 0);
  signal div            : unsigned(XLEN*2 downto 0);
  signal div_shift      : unsigned(XLEN*2 downto 0);
  signal div_latch      : unsigned(XLEN*2 downto 0);
  signal d_zero         : std_logic;
  signal div_zero       : std_logic;
  signal d_overflow     : std_logic;
  signal div_overflow   : std_logic;

  constant DIV_MASK0         : unsigned(XLEN-1 downto 0) := X"FFFFFFFE";
  constant DIV_MASK1         : unsigned(XLEN-1 downto 0) := X"00000001";
  constant DIV_ZERO_VAL      : unsigned(XLEN-1 downto 0) := X"FFFFFFFF";
  constant DIVIDEND_OVERFLOW : unsigned(XLEN-1 downto 0) := X"80000000";
  constant DIVISOR_OVERFLOW  : unsigned(XLEN-1 downto 0) := X"FFFFFFFF";

begin

  --
  -- Outputs
  --
  o_valid <= div_valid;

  o_quo <= std_logic_vector(DIV_ZERO_VAL) when div_zero = '1' else
           std_logic_vector(DIVIDEND_OVERFLOW) when div_overflow = '1' else
           std_logic_vector(div_quo);

  o_rem <= std_logic_vector(div_src1_latch) when div_zero = '1' else
           (others => '0') when div_overflow = '1' else
           std_logic_vector(div_rem(XLEN-1 downto 0));

  --
  -- Inputs
  --
  div_neg_src1 <= i_sign(0) and i_op_a(i_op_a'left);
  div_neg_src2 <= i_sign(1) and i_op_b(i_op_b'left);

  div_src1 <= resize(unsigned(i_op_a), XLEN+1) when div_neg_src1 = '0' else
              resize(unsigned(-signed(i_op_a)), XLEN+1);

  div_src2 <= resize(unsigned(i_op_b), XLEN+1) when div_neg_src2 = '0' else
              resize(unsigned(-signed(i_op_b)), XLEN+1);

  div_init(XLEN*2 downto XLEN) <= (others => '0');
  div_init(XLEN-1 downto 0)    <= div_src1(XLEN-1 downto 0);

  div <= div_latch when div_state = WORKING else
         div_init;

  div_shift <= shift_left(div, 1);

  div_arith_b <= div_src2_latch when div_state = WORKING else div_src2;
  div_arith_p <= div_shift(XLEN*2 downto XLEN);
  div_arith   <= div_arith_p - div_arith_b;

  div_arith_a <= div_shift(XLEN-1 downto 0) and DIV_MASK0 when div_arith(XLEN) = '1' else
                 div_shift(XLEN-1 downto 0) or DIV_MASK1;

  d_zero <= '1' when unsigned(i_op_b) = to_unsigned(0, XLEN) else
            '0';

  d_overflow <= '1' when (i_sign(1) = '1') and
                (unsigned(i_op_a) = DIVIDEND_OVERFLOW) and
                (unsigned(i_op_b) = DIVISOR_OVERFLOW) else
                '0';

  p_div : process(i_rstn, i_clk)
  begin
    if i_rstn = '0' then
      div_state      <= IDLE;
      div_count      <= XLEN-1;
      div_latch      <= (others => '0');
      div_src2_latch <= (others => '0');
      div_src1_latch <= (others => '0');
      div_neg_rem    <= '0';
      div_neg_quo    <= '0';
      div_zero       <= '0';
      div_overflow   <= '0';
      div_valid      <= '0';
    elsif rising_edge(i_clk) then
      if i_en = '1' then
        if div_arith(XLEN) = '0' then
          div_latch <= div_arith & div_arith_a;
        else
          div_latch <= div_shift(XLEN*2 downto XLEN) & div_arith_a;
        end if;
        case div_state is
          when IDLE =>
            div_valid <= '0';
            if div_valid = '0' then
              div_src2_latch <= div_src2;
              div_src1_latch <= unsigned(i_op_a);
              div_neg_rem    <= div_neg_src1;
              div_neg_quo    <= div_neg_src1 xor div_neg_src2;
              div_zero       <= d_zero;
              div_overflow   <= d_overflow;
              div_state      <= WORKING;
              div_count      <= div_count - 1;
            end if;
          when WORKING =>
            div_src2_latch <= div_src2_latch;
            div_src1_latch <= div_src1_latch;
            div_neg_rem    <= div_neg_rem;
            div_neg_quo    <= div_neg_quo;
            if (div_count = 0 or div_zero = '1' or div_overflow = '1') then
              div_valid <= '1';
              div_state <= IDLE;
              div_count <= XLEN-1;
            else
              div_valid <= '0';
              div_state <= WORKING;
              div_count <= div_count - 1;
            end if;
        end case;
      end if;
    end if;
  end process p_div;

  div_quo <= div_latch(XLEN-1 downto 0) when div_neg_quo = '0' else
             unsigned(-signed(div_latch(XLEN-1 downto 0)));

  div_rem <= div_latch(XLEN*2 downto XLEN) when div_neg_rem = '0' else
             unsigned(-signed(div_latch(XLEN*2 downto XLEN)));

end architecture beh;
