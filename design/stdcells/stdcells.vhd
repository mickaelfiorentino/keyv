-------------------------------------------------------------------------------
-- Project : KeyV
-- File    : stdcells.vhd
-- Author  : Mickael Fiorentino <mickael.fiorentino@polymtl.ca>
-- Lab     : GRM - Polytechnique Montreal
-- Date    : 2020-02-21
-- Brief   : Standard cells wrapper for direct instanciations
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package stdcells is

  component INV1 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic);
  end component INV1;

  component NAND21 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic);
  end component NAND21;

  component NOR31 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic;
      C : in  std_ulogic);
  end component NOR31;

  component AND21 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic);
  end component AND21;

  component AND31 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic;
      C : in  std_ulogic);
  end component AND31;

  component OR21 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic);
  end component OR21;

  component OR31 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic;
      C : in  std_ulogic);
  end component OR31;

  component XOR21 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic);
  end component XOR21;

  component XNOR21 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic);
  end component XNOR21;

  component MXI21 is
    port (
      A  : in  std_ulogic;
      B  : in  std_ulogic;
      S0 : in  std_ulogic;
      Y  : out std_ulogic);
  end component MXI21;

  component DFFSR1 is
    port (
      CK : in  std_ulogic;
      D  : in  std_ulogic;
      RN : in  std_ulogic;
      SN : in  std_ulogic;
      Q  : out std_ulogic;
      QN : out std_ulogic);
  end component DFFSR1;

  component DFF1 is
    port (
      CK : in  std_ulogic;
      D  : in  std_ulogic;
      RN : in  std_ulogic;
      Q  : out std_ulogic);
  end component DFF1;

  component CLKBUF is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic);
  end component CLKBUF;

  component CLKMX21 is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic;
      B : in  std_ulogic;
      S : in  std_ulogic);
  end component CLKMX21;

  component DELX is
    port (
      Y : out std_ulogic;
      A : in  std_ulogic);
  end component DELX;

end package stdcells;
