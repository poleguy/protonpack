-------------------------------------------------
-- cfg_pkt.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
--
--------------------------------------------------
-- Engineer: Alex Stezskal
-- see version control for rev info
--------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all;

use work.telemetry_cfg_pkg.all;

ENTITY cfg_pkt IS
port(
    rst            : in std_logic;
    rd_clk         : in  std_logic;
    rd_en          : in std_logic;
    rd_data        : out std_logic_vector(7 downto 0);

    fpga_rev       : in std_logic_vector(31 downto 0);
    fpga_date      : in std_logic_vector(31 downto 0);
    fpga_time      : in std_logic_vector(31 downto 0)
    );
END cfg_pkt;

ARCHITECTURE rtl OF cfg_pkt IS 

    signal byte_cnt : integer range 0 to CONFIG_PKT_ROM'length-1;

BEGIN

    rd_data <= fpga_rev(31 downto 24) when byte_cnt=9  else
               fpga_rev(23 downto 16) when byte_cnt=10 else
               fpga_rev(15 downto  8) when byte_cnt=11 else
               fpga_rev( 7 downto  0) when byte_cnt=12 else
               fpga_date(31 downto 24) when byte_cnt=13 else
               fpga_date(23 downto 16) when byte_cnt=14 else
               fpga_date(15 downto  8) when byte_cnt=15 else
               fpga_date( 7 downto  0) when byte_cnt=16 else
               fpga_time(31 downto 24) when byte_cnt=17 else
               fpga_time(23 downto 16) when byte_cnt=18 else
               fpga_time(15 downto  8) when byte_cnt=19 else
               fpga_time( 7 downto  0) when byte_cnt=20 else
               CONFIG_PKT_ROM(byte_cnt);
    ------------------------------------
    -- Byte Counters
    ------------------------------------
    process(rd_clk)begin
        if rising_edge(rd_clk) then
            if(rst='1')then
                byte_cnt <= 0;
            elsif(byte_cnt=CONFIG_PKT_ROM'length-1)then
                byte_cnt <= 0;
            elsif(rd_en='1')then
                byte_cnt <= byte_cnt + 1;
            end if;
        end if;
    end process;

END;
