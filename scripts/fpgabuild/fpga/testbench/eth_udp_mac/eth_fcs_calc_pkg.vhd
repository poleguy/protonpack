----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
-- 
-- Description:  A test package for testing Ethernet streams including GMII interface
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

LIBRARY std;
    USE std.textio.all;

package eth_fcs_calc_pkg is

    procedure reset_fcs;

    procedure update_fcs_calc(
         signal txd     : in std_logic_vector(7 downto 0);
         fcs_calc       : out std_logic_vector(31 downto 0)
         );

    shared variable lfsr_q : std_logic_vector(31 downto 0) := (others => '0');

end package;

package body eth_fcs_calc_pkg is

    procedure reset_fcs is
    begin
        lfsr_q := (others => '1');
    end procedure;

    procedure update_fcs_calc(
         signal txd     : in std_logic_vector(7 downto 0);
         fcs_calc       : out std_logic_vector(31 downto 0)
     )
     is
         variable data_in : std_logic_vector(7 downto 0);
         variable lfsr_c    : std_logic_vector(31 downto 0); 
     begin

         for ii in 0 to 7 loop
             data_in(0+ii) := txd(7-ii);
         end loop;

        lfsr_c(0) := lfsr_q(24) xor lfsr_q(30) xor data_in(0) xor data_in(6);
        lfsr_c(1) := lfsr_q(24) xor lfsr_q(25) xor lfsr_q(30) xor lfsr_q(31) xor data_in(0) xor data_in(1) xor data_in(6) xor data_in(7);
        lfsr_c(2) := lfsr_q(24) xor lfsr_q(25) xor lfsr_q(26) xor lfsr_q(30) xor lfsr_q(31) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(6) xor data_in(7);
        lfsr_c(3) := lfsr_q(25) xor lfsr_q(26) xor lfsr_q(27) xor lfsr_q(31) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(7);
        lfsr_c(4) := lfsr_q(24) xor lfsr_q(26) xor lfsr_q(27) xor lfsr_q(28) xor lfsr_q(30) xor data_in(0) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(6);
        lfsr_c(5) := lfsr_q(24) xor lfsr_q(25) xor lfsr_q(27) xor lfsr_q(28) xor lfsr_q(29) xor lfsr_q(30) xor lfsr_q(31) xor data_in(0) xor data_in(1) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7);
        lfsr_c(6) := lfsr_q(25) xor lfsr_q(26) xor lfsr_q(28) xor lfsr_q(29) xor lfsr_q(30) xor lfsr_q(31) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(6) xor data_in(7);
        lfsr_c(7) := lfsr_q(24) xor lfsr_q(26) xor lfsr_q(27) xor lfsr_q(29) xor lfsr_q(31) xor data_in(0) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(7);
        lfsr_c(8) := lfsr_q(0) xor lfsr_q(24) xor lfsr_q(25) xor lfsr_q(27) xor lfsr_q(28) xor data_in(0) xor data_in(1) xor data_in(3) xor data_in(4);
        lfsr_c(9) := lfsr_q(1) xor lfsr_q(25) xor lfsr_q(26) xor lfsr_q(28) xor lfsr_q(29) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5);
        lfsr_c(10) := lfsr_q(2) xor lfsr_q(24) xor lfsr_q(26) xor lfsr_q(27) xor lfsr_q(29) xor data_in(0) xor data_in(2) xor data_in(3) xor data_in(5);
        lfsr_c(11) := lfsr_q(3) xor lfsr_q(24) xor lfsr_q(25) xor lfsr_q(27) xor lfsr_q(28) xor data_in(0) xor data_in(1) xor data_in(3) xor data_in(4);
        lfsr_c(12) := lfsr_q(4) xor lfsr_q(24) xor lfsr_q(25) xor lfsr_q(26) xor lfsr_q(28) xor lfsr_q(29) xor lfsr_q(30) xor data_in(0) xor data_in(1) xor data_in(2) xor data_in(4) xor data_in(5) xor data_in(6);
        lfsr_c(13) := lfsr_q(5) xor lfsr_q(25) xor lfsr_q(26) xor lfsr_q(27) xor lfsr_q(29) xor lfsr_q(30) xor lfsr_q(31) xor data_in(1) xor data_in(2) xor data_in(3) xor data_in(5) xor data_in(6) xor data_in(7);
        lfsr_c(14) := lfsr_q(6) xor lfsr_q(26) xor lfsr_q(27) xor lfsr_q(28) xor lfsr_q(30) xor lfsr_q(31) xor data_in(2) xor data_in(3) xor data_in(4) xor data_in(6) xor data_in(7);
        lfsr_c(15) := lfsr_q(7) xor lfsr_q(27) xor lfsr_q(28) xor lfsr_q(29) xor lfsr_q(31) xor data_in(3) xor data_in(4) xor data_in(5) xor data_in(7);
        lfsr_c(16) := lfsr_q(8) xor lfsr_q(24) xor lfsr_q(28) xor lfsr_q(29) xor data_in(0) xor data_in(4) xor data_in(5);
        lfsr_c(17) := lfsr_q(9) xor lfsr_q(25) xor lfsr_q(29) xor lfsr_q(30) xor data_in(1) xor data_in(5) xor data_in(6);
        lfsr_c(18) := lfsr_q(10) xor lfsr_q(26) xor lfsr_q(30) xor lfsr_q(31) xor data_in(2) xor data_in(6) xor data_in(7);
        lfsr_c(19) := lfsr_q(11) xor lfsr_q(27) xor lfsr_q(31) xor data_in(3) xor data_in(7);
        lfsr_c(20) := lfsr_q(12) xor lfsr_q(28) xor data_in(4);
        lfsr_c(21) := lfsr_q(13) xor lfsr_q(29) xor data_in(5);
        lfsr_c(22) := lfsr_q(14) xor lfsr_q(24) xor data_in(0);
        lfsr_c(23) := lfsr_q(15) xor lfsr_q(24) xor lfsr_q(25) xor lfsr_q(30) xor data_in(0) xor data_in(1) xor data_in(6);
        lfsr_c(24) := lfsr_q(16) xor lfsr_q(25) xor lfsr_q(26) xor lfsr_q(31) xor data_in(1) xor data_in(2) xor data_in(7);
        lfsr_c(25) := lfsr_q(17) xor lfsr_q(26) xor lfsr_q(27) xor data_in(2) xor data_in(3);
        lfsr_c(26) := lfsr_q(18) xor lfsr_q(24) xor lfsr_q(27) xor lfsr_q(28) xor lfsr_q(30) xor data_in(0) xor data_in(3) xor data_in(4) xor data_in(6);
        lfsr_c(27) := lfsr_q(19) xor lfsr_q(25) xor lfsr_q(28) xor lfsr_q(29) xor lfsr_q(31) xor data_in(1) xor data_in(4) xor data_in(5) xor data_in(7);
        lfsr_c(28) := lfsr_q(20) xor lfsr_q(26) xor lfsr_q(29) xor lfsr_q(30) xor data_in(2) xor data_in(5) xor data_in(6);
        lfsr_c(29) := lfsr_q(21) xor lfsr_q(27) xor lfsr_q(30) xor lfsr_q(31) xor data_in(3) xor data_in(6) xor data_in(7);
        lfsr_c(30) := lfsr_q(22) xor lfsr_q(28) xor lfsr_q(31) xor data_in(4) xor data_in(7);
        lfsr_c(31) := lfsr_q(23) xor lfsr_q(29) xor data_in(5);

        lfsr_q := lfsr_c;

         for ii in 0 to 31 loop
             fcs_calc(0+ii) := not lfsr_q(31-ii);
         end loop;

     end procedure;

end package body;
    
