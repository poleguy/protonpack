-------------------------------------------------
-- mobile_telem_to_eth.vhd
--------------------------------------------------
--
-- Copyright © 2022 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
--
-- This is a telemetry wrapper that takes in the
-- 11-byte serial mobile telemetry packets and
-- parses them appropriately into ethernet
-- telemetry streams.
--
-- Note the after 1 ps was necessary to fix simulation
-- gotcha where stream_valid was firing and causing
-- other logic that was clocked to fire on the same edge
-- I think this might be because of the clock assignment
-- statement:
--      stream_clks    <= (others => mobile_clk);
-- I have seen this kind of bug in simulation before
-- and it had to do with assigning clocks.  This 
-- assignment is convenient though because it supports
-- a variable amount of streams.  The after 1 ps
-- has no impact on synthesis.
--
--------------------------------------------------
-- Engineer: Alex Stezskal
-- see version control for rev info
--------------------------------------------------
--  

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.telemetry_cfg_pkg.all;

entity mobile_telem_to_eth is
  port(
    -- to eth_clk
    eth_rst      : in  std_logic;
    -- Interface to the Eth UDP MAC Tx
    eth_clk      : in std_logic;
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

    serial_error_in : in std_logic := '0'; -- level sensitive, any high sets error and resets counter to hold error

    fpga_rev  : in std_logic_vector(31 downto 0):=(others=>'0');
    fpga_date : in std_logic_vector(31 downto 0):=(others=>'0');
    fpga_time : in std_logic_vector(31 downto 0):=(others=>'0');

    mobile_clk          : in std_logic;
    mobile_pkt_data     : in std_logic_vector(11*8-1 downto 0);    
    mobile_pkt_data_val : in std_logic -- pulse in mobile_clk domain

    );
end mobile_telem_to_eth;

architecture rtl of mobile_telem_to_eth is
  -- mobile telemetry serial interface designed for max 16 streams (0 to 15) don't expect this to change
  constant NUM_MOBILE_STREAMS : integer := 16;

  -- bit widths of fields within the 11-byte mobile serial packet
  constant W_DAT : integer := 32; --lsbytes
  constant W_TIM : integer := 32;
  constant W_TDM : integer := 8;
  constant W_FLD : integer := 8;
  constant W_CLA : integer := 4;
  constant W_PNO : integer := 4; --most sig

  signal stream_clks      : t_stream_clks    := stream_clks_init;
  signal stream_valids    : t_stream_valids  := stream_valids_init;
  signal stream_enables   : t_stream_enables := stream_enables_init;
  signal stream_data      : t_stream_data    := stream_data_init;
  signal stream_user_error: t_stream_user_error    := stream_user_error_init;
  
  signal pkt_hold : std_logic_vector(mobile_pkt_data'left downto 0) := (others=>'0');

  signal valid : std_logic_vector(2 downto 0):=(others=>'0');

  signal stream_sel_1hot    : std_logic_vector(NUM_MOBILE_STREAMS-1 downto 0);
  signal valid_stream_1hot    : std_logic_vector(NUM_MOBILE_STREAMS-1 downto 0);

  signal data        : std_logic_vector(W_DAT-1 downto 0);
  signal timestamp   : std_logic_vector(W_TIM-1 downto 0);
  signal tdm         : std_logic_vector(W_TDM-1 downto 0);
  signal field       : std_logic_vector(W_FLD-1 downto 0);
  signal class       : std_logic_vector(W_CLA-1 downto 0);
  signal pkt_no      : std_logic_vector(W_PNO-1 downto 0);

  signal mclk_rst_meta : std_logic := '0';
  signal mclk_rst_sync : std_logic := '0';
  signal mclk_rst      : std_logic := '0';

  attribute ASYNC_REG : string;
  attribute MARK_DEBUG : string;
  attribute ASYNC_REG of mclk_rst_meta     : signal is "TRUE";
  attribute ASYNC_REG of mclk_rst_sync     : signal is "TRUE";


  signal cnt_ms : std_logic_vector(17 downto 0) := (others=>'0');
  signal one_ms_pulse : std_logic;

  signal fault_pkt_chk      : std_logic;
  signal fault_pkt_throttle : std_logic;
  signal valid_fault_stream : std_logic;
  signal fault_user_err : std_logic;
  signal fault_pkt_cnt : std_logic_vector(10 downto 0) := (others=>'0');
  signal fault_ms_cnt : std_logic_vector(8 downto 0):=(others=>'0');


  attribute MARK_DEBUG of pkt_hold    : signal is "TRUE";
  attribute MARK_DEBUG of valid       : signal is "TRUE";
  attribute MARK_DEBUG of data        : signal is "TRUE";
  attribute MARK_DEBUG of timestamp   : signal is "TRUE";
  attribute MARK_DEBUG of tdm         : signal is "TRUE";
  attribute MARK_DEBUG of field       : signal is "TRUE";
  attribute MARK_DEBUG of class       : signal is "TRUE";
  attribute MARK_DEBUG of pkt_no      : signal is "TRUE";
  attribute MARK_DEBUG of stream_valids      : signal is "TRUE";

begin

     -- sync reset
     process(mobile_clk)begin
         if rising_edge(mobile_clk) then
             mclk_rst_meta <= eth_rst;
             mclk_rst_sync <= mclk_rst_meta;
             mclk_rst      <= mclk_rst_sync;
         end if;
     end process;

     -- create valid delays for setting events in time
     process(mobile_clk)begin
         if rising_edge(mobile_clk) then
             if(mclk_rst='1')then
                 valid <= (others=>'0');
             else
                 valid(0) <= mobile_pkt_data_val after 1 ps;   -- see note at header regarding after 1ps
                 valid(2 downto 1) <= valid(1 downto 0) after 1 ps;
             end if;
         end if;
     end process;

     process(mobile_clk)begin
         if rising_edge(mobile_clk) then
             if(mobile_pkt_data_val='1')then
                 pkt_hold <= mobile_pkt_data after 1 ps;
             end if;
         end if;
     end process;

    ---------------------------------------------------------------------
    -- decode  the 11-byte packet
    --
    -- https://bitbucket.shure.com/projects/DPSM_FPGA/repos/telemetry/browse/doc
    ---------------------------------------------------------------------
    data        <= pkt_hold(W_DAT-1                                 downto 0);
    timestamp   <= pkt_hold(W_TIM+W_DAT-1                           downto W_DAT);
    tdm         <= pkt_hold(W_TDM+W_TIM+W_DAT-1                     downto W_TIM+W_DAT);
    field       <= pkt_hold(W_FLD+W_TDM+W_TIM+W_DAT-1               downto W_TDM+W_TIM+W_DAT);
    class       <= pkt_hold(W_CLA+W_FLD+W_TDM+W_TIM+W_DAT-1         downto W_FLD+W_TDM+W_TIM+W_DAT);
    pkt_no      <= pkt_hold(W_PNO+W_CLA+W_FLD+W_TDM+W_TIM+W_DAT-1   downto W_CLA+W_FLD+W_TDM+W_TIM+W_DAT);

    ---------------------------------------------------------------------

    -- FAULT_PACKET[87:0]=0xFFFFFF000000000000000Q
    fault_pkt_chk <= '1' when pkt_hold(87 downto 4)=X"FFFFFF000000000000000" else '0';



    ---------------------------------------------------------------------
    --
    -- Generate data and valid logic for each class/stream.
    --
    ---------------------------------------------------------------------

    gen_stream : for s in 0 to NUM_MOBILE_STREAMS-1 generate

         -- create a 1hot to select which class/stream this packet is from
         stream_sel_1hot(s) <= '0' when fault_pkt_chk='1' else
                               '1' when class=s else 
                               '0';
         -- valid only toggle for that stream
         valid_stream_1hot(s) <= stream_sel_1hot(s) and valid(2);


         -- Capture input fields into a buffer and always write the correct
         -- number of bytes out to ethernet-telemetry.  This is to ensure
         -- byte alignment stays intact regardless of what happens on
         -- the serial side.
         mobile_data_buff: entity work.mobile_data_buff
            generic map(
                BUFFER_SIZE_NUM_FIELDS => MAX_NUM_FIELDS_PER_STREAM
            ) port map (
                 clk        => mobile_clk,
                 rst        => mclk_rst,

                 valid         => valid_stream_1hot(s),
                 field         => field,
                 data          => data,
                 timestamp     => timestamp,
                 num_fields    => std_logic_vector(to_unsigned(getStreamNumFields(s),8))-1, -- -1 remove timestamp field

                 stream_valid => stream_valids(s),
                 stream_data  => stream_data(s)(31 downto 0)
             );

         -- Watch for field out of order error condition and hold the error
         -- for about 1 second.  Also capture serial error indicator and
         -- hold it as well.
         mobile_error: entity work.mobile_error
            port map (
                 clk           => mobile_clk,
                 rst           => mclk_rst,
                 one_ms_pulse  => one_ms_pulse,

                 valid         => valid_stream_1hot(s),
                 field         => field,
                 num_fields    => std_logic_vector(to_unsigned(getStreamNumFields(s),8))-1, -- -1 remove timestamp field

                 serial_error_in  => serial_error_in,

                 field_error_out  => stream_user_error(s)(0),
                 serial_error_out => stream_user_error(s)(1)
             );


         stream_user_error(s)(3 downto 2) <= (others=>'0');

     end generate;

    ------------------------------------------------------------------------
    ------------------------------------------------------------------------
    -- Fault packets are generated when something goes wrong on the serial telem transmitter side.
    -- e.g. too much telemetry is enabled and the telemetry dispatcher is overloaded.
    -- these fault packets do not correspond to a single stream, so it's easier to capture them
    -- as an indepedent stream.
    --
    -- FAULT_PACKET[87:0]=0xFFFFFF000000000000000Q
    --      Q[3:0] = 0x1 - fault_request_not_queued
    --      Q[3:0] = 0x2 - fault_request_not_decoded
    --      Q[3:0] = 0x4 - fault_queue_overflow
    --      Q[3:0] = 0x8 - fault_queue_underflow
    --
    mobile_data_buff_faults: entity work.mobile_data_buff
    generic map(
        BUFFER_SIZE_NUM_FIELDS => MAX_NUM_FIELDS_PER_STREAM
    ) port map (
            clk        => mobile_clk,
            rst        => mclk_rst,

            valid         => valid_fault_stream,
            field         => (others=>'0'),
            data          => data,
            timestamp     => x"DEADBEEF",
            num_fields    => std_logic_vector(to_unsigned(getStreamNumFields(NUM_MOBILE_STREAMS),8))-1, -- -1 remove timestamp field

            stream_valid => stream_valids(NUM_MOBILE_STREAMS),
            stream_data  => stream_data(NUM_MOBILE_STREAMS)(31 downto 0)
        );

    -- Fault packets come out as fast as possible.  This is faster than eth-telem fifo or packets over the link can handle.
    -- Throttle the valid of fault packets so we only take 1/64 fault packets.
    valid_fault_stream <= fault_pkt_chk and fault_pkt_throttle and valid(2);

    -- throttle counter
     process(mobile_clk)begin
         if rising_edge(mobile_clk) then
             if(fault_pkt_cnt(fault_pkt_cnt'left)='1')then
                 fault_pkt_throttle <= '1';
                 fault_pkt_cnt <= (others=>'0');
             elsif(fault_pkt_chk='1' and valid(2)='1')then
                 fault_pkt_throttle <= '1';
                 fault_pkt_cnt <= fault_pkt_cnt + 1;
             end if;
         end if;
     end process;

     -- hold fault packet error for about 1/4 second so that it shows up in telemetry around the time of occurance 
     -- but doesn't indicate an error forever if telem is reset and no fault packets exist
     process(mobile_clk)begin
         if rising_edge(mobile_clk) then
             if(mclk_rst='1')then
                 fault_user_err <= '0';
             else
                 if(fault_pkt_chk='1')then
                     fault_ms_cnt <= (others=>'0');
                     fault_user_err <= '1';
                 elsif(fault_ms_cnt(fault_ms_cnt'left)='1')then   -- ~1second at 2**10 of 1ms pulses
                     fault_user_err <= '0';
                 elsif(one_ms_pulse='1')then
                     fault_ms_cnt <= fault_ms_cnt + 1;
                 end if;
             end if;
         end if;
     end process;

    -- set user error bit 2 to indicate we have fault packets
    stream_user_error(NUM_MOBILE_STREAMS) <= (2=>fault_user_err, others=>'0');

    ----------------------------------------- end fault detection 
    ------------------------------------------------------------------------
    ------------------------------------------------------------------------


     ----------------------------------------
     -- one_ms common counter pulse for 
     -- mobile_error
     ----------------------------------------
     process(mobile_clk)begin
         if rising_edge(mobile_clk) then
             one_ms_pulse <= '0';
             if(cnt_ms(cnt_ms'left)='1')then
                 one_ms_pulse <= '1';
                 cnt_ms <= (others=>'0');
             else
                 cnt_ms <= cnt_ms + 1;
             end if;
         end if;
     end process;


    stream_clks    <= (others => mobile_clk);
    stream_enables <= (others => (others=>'1'));

    ---------------------------------------------------------------------
    ---------------------------------------------------------------------

    
    telemetry: entity work.telemetry
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

         stream_clks      => stream_clks,
         stream_valids    => stream_valids,
         stream_enables   => stream_enables,
         stream_data      => stream_data,
         stream_ts        => open,
         stream_user_error=> stream_user_error,

         fpga_rev         => fpga_rev,
         fpga_date        => fpga_date,
         fpga_time        => fpga_time,

         sys_time_clk     => '0'); --not using system timetag provided by ethernet-telemetry, using mobile serial timetags

end;
