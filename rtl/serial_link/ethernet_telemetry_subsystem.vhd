-------------------------------------------------
-- ethernet_telemetry_subsystem.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- Top module for the ethernet telmetry
-- Thin layer which translates the 256MHz pkt valid
-- into the 128MHz domain.
--
--------------------------------------------------
-- Engineer: Nicholas Dietz/Alex Stezskal
-- see version control for rev info
--------------------------------------------------
--  

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.version_pkg.all;

use work.telemetry_cfg_pkg.all;

entity ethernet_telemetry_subsystem is
  generic (
    g_ila : in std_logic := '0'  -- set to 1 to generate ila's for debug
    );
  port(
    -- todo: name this rst_eth_clk to make it more clear it must be synchronous
    -- to eth_clk
    eth_rst          : in  std_logic;
    -- Interface to the Eth UDP MAC Tx
    eth_clk     : in std_logic;
    -- will stop telemetry after completing any current packet
    eth_telem_en : in std_logic;
    -- Packet Payload - AXI-Streaming
    eth_tdata    : out std_logic_vector(7 downto 0);
    eth_tvalid   : out std_logic;
    eth_tlast    : out std_logic;
    eth_tready   : in  std_logic;
    -- Packet Configuration
    eth_len      : out std_logic_vector(15 downto 0);  -- only need to configure length, ip_id, and dest port
    eth_ip_id    : out std_logic_vector(15 downto 0);  -- other packet config should be hard coded or control
    eth_udp_dest : out std_logic_vector(15 downto 0);  -- via registers

    -- Application Stream Inputs (declared in pkg)
    clk_256M     : in std_logic;
    clk_128M     : in std_logic;
    mobile_pkt_data     : in std_logic_vector(11*8-1 downto 0);    
    mobile_pkt_data_val : in std_logic -- @256MHz clk

    );
end ethernet_telemetry_subsystem;

architecture rtl of ethernet_telemetry_subsystem is
  
  signal pkt_hold : std_logic_vector(mobile_pkt_data'left downto 0);
  signal val_toggle : std_logic := '0';
  signal val_toggle_d : std_logic:='0';
  signal val_toggle_d2 : std_logic:='0';

  signal valid : std_logic;

begin

     process(clk_256M)begin
         if rising_edge(clk_256M) then
             if(mobile_pkt_data_val='1')then
                 pkt_hold <= mobile_pkt_data;
             end if;

             if(mobile_pkt_data_val='1')then
                 val_toggle <= not val_toggle;
             end if;
         end if;
     end process;

     -- catch valid occuring in 256MHz clock domain into 128M domain and create some delays
     process(clk_128M)begin
         if rising_edge(clk_128M) then
             val_toggle_d <= val_toggle;
             val_toggle_d2 <= val_toggle_d;

             valid <= val_toggle_d xor val_toggle_d2; -- pulse at 128MHz
         end if;
     end process;

 -- src/shurewireless-telemetry/fpga/rtl/mobile_telem_to_eth.vhd
 mobile_telem_to_eth: entity work.mobile_telem_to_eth
   port map (
     eth_rst          => eth_rst,
     eth_clk          => eth_clk,
     eth_telem_en     => eth_telem_en,
     eth_tdata        => eth_tdata,
     eth_tvalid       => eth_tvalid,
     eth_tlast        => eth_tlast,
     eth_tready       => eth_tready,
     eth_len          => eth_len,
     eth_ip_id        => eth_ip_id,
     eth_udp_dest     => eth_udp_dest,

     fpga_rev         => C_VERSION_MAJOR & C_VERSION_MINOR & C_VERSION_PATCH & C_VERSION_BUILD,
     fpga_date        => C_VERSION_YEAR & C_VERSION_MONTH & C_VERSION_DAY,
     fpga_time        => X"00" & C_VERSION_HOUR & C_VERSION_MINUTE &C_VERSION_SECOND,

     mobile_clk       => clk_128M,
     mobile_pkt_data  => pkt_hold,
     mobile_pkt_data_val => valid
     ); 

end;
