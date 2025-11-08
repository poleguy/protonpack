-- Alex Stezskal
-- Shure inc.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use STD.textio.all;             -- file i/0
USE std.env.all;                -- for stop()
use ieee.std_logic_unsigned.all;

use work.eth_test_pkg.all;

entity tb is
end tb;

architecture arch of tb is

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal txd_en   : std_logic := '0';
    signal txd      : std_logic_vector(7 downto 0) := (others => '0');

    signal fcs_gen  : std_logic_vector(31 downto 0) := (others => '0');
    signal fcs_gen_store  : std_logic_vector(31 downto 0) := (others => '0');
    signal crc_xil  : std_logic_vector(31 downto 0) := (others => '0');
    signal crc_xil_le  : std_logic_vector(31 downto 0) := (others => '0');

    signal vld_cnt  : integer := 0;

begin

    process begin
        wait for 4 ns;
        clk <= not clk;
    end process;

    process is
        variable pkt : t_pkt;
    begin
        decode_gmii(clk, txd_en, txd, pkt);
        display_pkt(pkt);
    end process;

    process 
        file gmii_src_file : text;
        variable inline : line;
        variable txd_var : std_logic_vector(7 downto 0);
    begin
        file_open(gmii_src_file,"xil_gmii_0.txt", READ_MODE);
        for ii in 0 to 20 loop
            wait until rising_edge(clk);
        end loop;
        while(endfile(gmii_src_file)/=True)loop
            txd_en <= '1';
            readline(gmii_src_file,inline);
            hread(inline, txd_var);
            txd <= txd_var;
            wait until rising_edge(clk);
        end loop;
        txd_en <= '0';
        for ii in 0 to 20 loop
            wait until rising_edge(clk);
        end loop;
       LOG("-- fcs compare rtl uut --:");
       LOG("crc from ila ex 0x"&to_hstring(crc_xil_le));
       LOG("fcs_gen         0x"&to_hstring(fcs_gen_store));
        stop(0);
    end process;

    process 
    begin
        wait until rising_edge(txd_en);
        while(txd_en)loop
            wait until rising_edge(clk);
            vld_cnt <= vld_cnt + 1;
        end loop;
    end process;

    crc_xil         <= X"68913267";
    crc_xil_le      <= X"67329168";

   process begin
       wait until rising_edge(clk);
       if(vld_cnt=114)then
           fcs_gen_store <= fcs_gen;
       end if;
   end process;

   eth_fcs_gen : entity work.eth_fcs_gen
   port map(
        clk => clk,
        txd => txd,
        txd_en => txd_en,
        fcs => fcs_gen
           );

end ;
