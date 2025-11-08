-------------------------------------------------
-- tb_telemetry.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- Testench top for testing the ethernet telem 
--
--------------------------------------------------
-- Engineer: Alex Stezskal
-- see version control for rev info
--------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY std;
    USE std.env.all;                -- for stop()
    use std.textio.all;             -- file i/0

use work.telemetry_cfg_pkg.all;
use work.tb_telemetry_pkg.all;
use work.eth_test_pkg.decode_gmii;
use work.eth_test_pkg.t_pkt;
use work.eth_test_pkg.display_pkt;

ENTITY tb_telemetry IS
END tb_telemetry;

    ARCHITECTURE behavior OF tb_telemetry IS 

        signal rx_raw_i : std_logic_vector(31 downto 0) := X"A1A2_A3A4";
        signal rx_raw_q : std_logic_vector(31 downto 0) := X"B1B2_B3B4";
        signal rx_filt_i : std_logic_vector(23 downto 0):= X"C1C2C3";
        signal rx_filt_q : std_logic_vector(23 downto 0):= X"D1D2D3";
        signal rx_status : std_logic_vector(7 downto 0) := X"EE";

        signal rx_clk   : std_logic;
        signal rx_frame_valid : std_logic;

        signal temp : std_logic_vector(31 downto 0);

        signal audio_ch0 : std_logic_vector(23 downto 0):= X"A00000";
        signal audio_ch1 : std_logic_vector(23 downto 0):= X"A00001";
        signal audio_ch2 : std_logic_vector(23 downto 0):= X"A00002";
        signal audio_ch3 : std_logic_vector(23 downto 0):= X"A00003";

        signal audio_lrclk_re : std_logic;
        signal audio_bitclk : std_logic;

        signal eth_clk : std_logic := '0';
        signal eth_tdata : std_logic_vector(7 downto 0);
        signal eth_tvalid : std_logic;
        signal eth_tlast : std_logic;
        signal eth_tready : std_logic := '1';

        signal eth_len     : std_logic_vector(15 downto 0); -- only need to configure length, ip_id, and dest port
        signal eth_ip_id   : std_logic_vector(15 downto 0); -- other packet config should be hard coded or control
        signal eth_udp_dest: std_logic_vector(15 downto 0); -- via registers

        signal eth_overflow : std_logic_vector(7 downto 0); -- indicates if a stream FIFO overflowed (full)

        signal sys_clk : std_logic;

        signal eth_telem_en : std_logic := '1';

        signal rst : std_logic := '1';
       
        signal txd : std_logic_vector(7 downto 0);
        signal txd_en : std_logic;

        signal stream_clks     : t_stream_clks    ;
        signal stream_valids   : t_stream_valids  ;
        signal stream_enables  : t_stream_enables ;
        signal stream_data     : t_stream_data    ;

        shared variable errors : integer := 0;

    BEGIN

   -- process begin
   --     wait until falling_edge(txd_en);
   --     wait until falling_edge(txd_en);
   --     wait until falling_edge(txd_en);
   --     wait until falling_edge(txd_en);
   --     wait until falling_edge(txd_en);
   --     wait for 50 ns;
   --     LOG("call stop after a few processes");
   --    stop(0);
   -- end process;
    process is
        variable F : integer;
        begin
        wait for 1 ns;
        LOG("getNumActiveStreams="&integer'image(getNumActiveStreams));
        print_config_rom(CONFIG_PKT_ROM);
        for s in 0 to getNumActiveStreams-1 loop
            F := getStreamNumFields(s);
            LOG("== Stream "&integer'image(s)&" ==");
            LOG(" Total Bytes=" & integer'image(getStreamTotalBytes(s)));
            --for f in 0 to F-1 loop
            --    LOG("  Field "&integer'image(f)&" size="&integer'image(getStreamFieldBytes(s,f))&" id="&getStreamFieldIDstr(s,f));
            --end loop;
        end loop;
        LOG("ROM length = "&integer'image(CONFIG_PKT_ROM'length));
        LOG("ROM(3 downto 0)="&to_hstring(CONFIG_PKT_ROM(3))&to_hstring(CONFIG_PKT_ROM(2))&to_hstring(CONFIG_PKT_ROM(1))&to_hstring(CONFIG_PKT_ROM(0)));
        LOG("ROM(7 downto 4)="&to_hstring(CONFIG_PKT_ROM(7))&to_hstring(CONFIG_PKT_ROM(6))&to_hstring(CONFIG_PKT_ROM(5))&to_hstring(CONFIG_PKT_ROM(4)));
        wait;
    end process;

    rst <= '0' after 100 ns;

    process begin
        wait for 4 ns;
        eth_clk <= not eth_clk;
    end process;


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
   ---    eth_overflow => eth_overflow,
        base_udp_port => std_logic_vector(to_unsigned(5000,16)),

        stream_clks => stream_clks,
        stream_valids => stream_valids,
        stream_enables => stream_enables,
        stream_data => stream_data,
        
        sys_time_clk => sys_clk,

        rst         => rst
    );

   eth_udp_mac_tx : entity work.eth_udp_mac_tx
   port map(
        rst                 => rst,
        clk                 => eth_clk,
        mac_gmii_en         => '1',

        cfg_src_mac_addr    => X"5A0001020304",
        cfg_ip_src_addr     => X"AABBCCDD",

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


    sys_clk <= stream_clks(0);

    process is
        variable pkt : t_pkt;
    begin
        decode_gmii(eth_clk, txd_en, txd, 
                    False,  --do not check the payload against pattern
                    pkt, errors);
        display_pkt(pkt);
    end process;

    --  Modem Receiver Telem Interface
    --
--     0,4,IQ_R,Raw IQ Data I
--     0,4,IQ_I,RaW IQ Data Q
--     0,3,IQ2R,Filtered IQ Data I
--     0,3,IQ2I,Filtered IQ Data Q
--     0,1,MSTA,Modem Status byte
    -----------------------------------------
     --  stream_0.data    <= rx_status & rx_filt_q & rx_filt_i & rx_raw_q & rx_raw_i;
     --  stream_0.enable  <= rx_field_enable_reg;
     --  stream_0.valid   <= rx_frame_valid;
     --  stream_0.clk     <= rx_clk;

    stream_source( stream_clks(0),  
                    stream_valids(0),
                    stream_enables(0),
                    stream_data(0),
                    0,  --stream number
                    10 ns, --clk period
                    32 ); --valid period in clocks

    stream_source( stream_clks(1),  
                    stream_valids(1),
                    stream_enables(1),
                    stream_data(1),
                    1,  --stream number
                    20.456 ns, --clk period
                    24 ); --valid period in clocks

    stream_source( stream_clks(2),  
                    stream_valids(2),
                    stream_enables(2),
                    stream_data(2),
                    2,  --stream number
                    10 ns, --clk period
                    32 ); --valid period in clocks

    -----------------------------------------
    --  Audio Telem Interface
    --
--     1,3,ATX0,Audio Tx Ch 0
--     1,3,ATX1,Audio Tx Ch 1
--     1,3,ATX2,Audio Tx Ch 2
--     1,3,ATX3,Audio Tx Ch 3
    -----------------------------------------
     --  stream_1.data    <= audio_ch3 & audio_ch2 & audio_ch1 & audio_ch0;
     --  stream_1.enable  <= audio_field_enable_reg;
     --  stream_1.valid   <= audio_lrclk_re;
     --  stream_1.clk     <= audio_bitclk;
                    
    process is 
        variable next_time : time := 2 ns;
    begin
        while(now < 10 ms) loop
            capture_pcapng("capture.pcapng", txd_en, txd, eth_clk);
            if(now > next_time)then
                LOG(" <-- Capture duration ");
                next_time := next_time + 1 ms;
            end if;
        end loop;
        stop(0);
    end process;

   -------------------------------------
   -- Example steps for reading from binary file, conv to slv, then write slv to binary file
   -------------------------------------

   -- Keep this...
                                 --  process is
                                 --      type char_file is file of character;
                                 --      file ptr : char_file;
                                 --      file ptr2 : char_file;
                                 --      variable char : character;
                                 --      variable char2 : character;
                                 --      variable byte : std_logic_vector(7 downto 0);
                                 --  begin
                                 --      file_open (ptr, "/home/fpga/data/eth_udp/pkt3", read_mode);
                                 --      file_open (ptr2, "/home/fpga/data/eth_udp/vhdl.bin", write_mode);
                                 --      for ii in 1 to 10 loop
                                 --          read(ptr, char);
                                 --          byte := std_logic_vector(to_unsigned(character'pos(char),8));
                                 --          char2 := character'val(to_integer(unsigned(byte)));
                                 --          write(ptr2, char2);
                                 --          LOG("read binary test="&to_hstring(byte));
                                 --      end loop;
                                 --    file_close(ptr);
                                 --    file_close(ptr2);
                                 --      wait;
                                 --  end process;
   -------------------------------------
   -------------------------------------

END;
