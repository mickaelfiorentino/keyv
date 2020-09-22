-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : bp.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-20
-- Brief   : Branch predictor
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32_pkg.all;

entity bp is
  port (
    i_clk  : in  std_logic;
    i_rstn : in  std_logic;
    i_bp   : in  keyv_to_bp;
    o_bp   : out keyv_from_bp);
end entity bp;

architecture beh of bp is

  -- 2-bits states prediction scheme
  type t_branch_state is (taken_a, taken_b, ntaken_a, ntaken_b);
  signal branch_state : t_branch_state;

  type t_branch_taken is (taken, not_taken);
  signal branch_next : t_branch_taken;

begin

  --
  -- Output
  --
  o_bp.taken <= '0' when branch_next = not_taken else
                '1';

  o_bp.predict <= '0' when (branch_state = ntaken_a) or (branch_state = ntaken_b) else
                  '1';

  --
  -- Branch Decision process
  --
  --   + Combinational
  --   + BEQ/BLT/BLTU : Check for condition from alu result
  --   + BNE/BGE/BGEU : Check for inverted condition from alu result
  --
  p_decision : process (i_bp.opcode, i_bp.branch, i_bp.condition)
  begin
    if i_bp.branch = '1' then
      case i_bp.opcode is

        -- Check for condition result form alu
        when FCT_BEQ | FCT_BLT | FCT_BLTU =>
          if i_bp.condition = '1' then
            branch_next <= taken;
          else
            branch_next <= not_taken;
          end if;

        -- Check for inverted condition result from alu
        when FCT_BNE | FCT_BGE | FCT_BGEU =>
          if i_bp.condition = '1' then
            branch_next <= not_taken;
          else
            branch_next <= taken;
          end if;

        -- Default to Taken
        when others => branch_next <= taken;
      end case;
    else
      branch_next <= taken;
    end if;
  end process p_decision;

  --
  -- Branch Prediction Process
  --
  --   + Sequential
  --   + Default to taken_a
  --   + 2-bit prediction scheme :
  --
  --  CONDITION     : taken
  --  -----------------------------------------------------------
  --  CURRENT_STATE | taken_a  | taken_b  | ntaken_a | ntaken_b |
  --  NEXT_STATE    | taken_a  | taken_a  | ntaken_b | taken_b  |
  --  -----------------------------------------------------------
  --  CONDITION     : not_taken
  --  -----------------------------------------------------------
  --  CURRENT_STATE | taken_a  | taken_b  | ntaken_a | ntaken_b |
  --  NEXT_STATE    | taken_b  | ntaken_b | ntaken_a | ntaken_a |
  --  -----------------------------------------------------------
  --
  p_prediction : process (i_clk, i_rstn)
  begin
    if i_rstn = '0' then
      branch_state <= taken_a;
    elsif rising_edge(i_clk) then

      if i_bp.branch = '1' then
        case branch_state is

          -- Taken states
          when taken_a =>
            if branch_next = not_taken then
              branch_state <= taken_b;
            else
              branch_state <= branch_state;
            end if;
          when taken_b =>
            if branch_next = not_taken then
              branch_state <= ntaken_b;
            else
              branch_state <= taken_a;
            end if;

          -- Not Taken states
          when ntaken_b =>
            if branch_next = not_taken then
              branch_state <= ntaken_a;
            else
              branch_state <= taken_b;
            end if;
          when ntaken_a =>
            if branch_next = not_taken then
              branch_state <= branch_state;
            else
              branch_state <= ntaken_b;
            end if;
        end case;
      else
        branch_state <= branch_state;
      end if;  -- i_bp.branch
    end if;  -- i_clk
  end process p_prediction;

end architecture beh;
