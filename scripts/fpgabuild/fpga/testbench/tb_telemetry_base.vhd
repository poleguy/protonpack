-------------------------------------------------
-- tb_telemetry_base.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- Testench top for testing the ethernet telem.
-- This would be in cocotb if it wasn't for the 
-- capture_pcapng procedure already existing.
--
--------------------------------------------------
-- Engineer: Alex Stezskal
-- see version control for rev info
--------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY std;
    use std.textio.all;             -- file i/0

use work.pcapng_pkg.all; -- capture_pcapng procedure

use work.telemetry_cfg_pkg.all;

ENTITY tb_telemetry_base IS
    generic(
        USE_MOBILE_TELEM_TOP : boolean := false
    );
END tb_telemetry_base;

    ARCHITECTURE behavior OF tb_telemetry_base IS 

        signal mac_gmii_en : std_logic := '1';
        signal eth_clk : std_logic := '0';
        signal eth_tdata : std_logic_vector(7 downto 0);
        signal eth_tvalid : std_logic;
        signal eth_tlast : std_logic;
        signal eth_tready : std_logic := '1';

        signal eth_len     : std_logic_vector(15 downto 0); -- only need to configure length, ip_id, and dest port
        signal eth_ip_id   : std_logic_vector(15 downto 0); -- other packet config should be hard coded or control
        signal eth_udp_dest: std_logic_vector(15 downto 0); -- via registers

        signal sys_clk : std_logic;
        signal sys_clk_en : std_logic := '1';

        signal eth_telem_en : std_logic := '1';

        signal eth_rst : std_logic := '0';
        signal r : std_logic;
       
        signal txd : std_logic_vector(7 downto 0);
        signal txd_en : std_logic;

        signal stream_clks     : t_stream_clks    ;
        signal stream_valids   : t_stream_valids  ;
        signal stream_enables  : t_stream_enables ;
        signal stream_data     : t_stream_data    ;

        signal cfg_extra_wait : std_logic_vector(7 downto 0) := (others=>'0');

        signal mobile_clk          : std_logic := '0';
        signal mobile_pkt_data     : std_logic_vector(11*8-1 downto 0) := (others=>'0');    
        signal mobile_pkt_data_val : std_logic := '0'; -- pulse in mobile_clk domain


    BEGIN
        
      --------------------------------------------------------------
      -- This VHDL procedure captures the ethernet gmii output 
      -- and writes the packets to a pcapng file.
      --------------------------------------------------------------
        capture_pcapng("capture.pcapng", txd_en, txd, eth_clk);
      --------------------------------------------------------------
      --------------------------------------------------------------

      --------------------------------------------------------------
      -- ETH UDP MAC TX
      --
      -- Takes axis payload data from telemetry module (or mobile wrap)
      -- and generates the necesssary eth gmii signaling with ethernet
      -- framing.
      --------------------------------------------------------------
       eth_udp_mac_tx : entity work.eth_udp_mac_tx
       port map(
            rst                 => eth_rst,
            clk                 => eth_clk,
            mac_gmii_en         => mac_gmii_en,

            cfg_src_mac_addr    => X"5A0001020304",
            cfg_ip_src_addr     => X"AABBCCDD",
            cfg_extra_wait      => cfg_extra_wait,

            tx_mac_dest         => (others => '1'),
            tx_ip_id            => eth_ip_id,
            tx_payload_len      => eth_len,
            tx_ip_dest          => (others=>'1'),
            tx_udp_src          => (others => '0'),
            tx_udp_dest         => eth_udp_dest,

            s_axis_tdata        => eth_tdata,
            s_axis_tvalid       => eth_tvalid,
            s_axis_tlast        => eth_tlast,
            s_axis_tready       => eth_tready,

            txd_en              => txd_en,
            txd                 => txd
           );
      --------------------------------------------------------------
      --------------------------------------------------------------


      --------------------------------------------------------------
      -- Test either telemetry top or mobile telemetry wrapper
      --
      --------------------------------------------------------------
       gen_telem : if USE_MOBILE_TELEM_TOP=false generate
            telemetry : entity work.telemetry
            port map(
                eth_clk      => eth_clk,
                eth_tdata    => eth_tdata,
                eth_tvalid   => eth_tvalid,
                eth_tlast    => eth_tlast,
                eth_tready   => eth_tready,
                eth_len      => eth_len,
                eth_ip_id    => eth_ip_id,
                eth_udp_dest => eth_udp_dest,
                eth_telem_en => eth_telem_en,

                stream_clks => stream_clks,
                stream_valids => stream_valids,
                stream_enables => stream_enables,
                stream_data => stream_data,
                
                sys_time_clk => sys_clk,
                sys_time_en  => sys_clk_en,

                eth_rst         => eth_rst
            );
        end generate;

       gen_mobile : if USE_MOBILE_TELEM_TOP=true generate
            mobile_telem_to_eth : entity work.mobile_telem_to_eth
            port map(
                eth_rst      => eth_rst,
                eth_clk      => eth_clk,
                eth_tdata    => eth_tdata,
                eth_tvalid   => eth_tvalid,
                eth_tlast    => eth_tlast,
                eth_tready   => eth_tready,
                eth_len      => eth_len,
                eth_ip_id    => eth_ip_id,
                eth_udp_dest => eth_udp_dest,
                eth_telem_en => eth_telem_en,

                mobile_clk            => mobile_clk,
                mobile_pkt_data       => mobile_pkt_data,
                mobile_pkt_data_val   => mobile_pkt_data_val
            );
        end generate;
      --------------------------------------------------------------
      --------------------------------------------------------------


END;
