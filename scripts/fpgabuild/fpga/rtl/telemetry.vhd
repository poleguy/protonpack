-------------------------------------------------
-- telemetry.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- Top module for the ethernet telmetry
--    Contains round robin async fifos and packet
--    stream generation.  eth udp mac is separate.
--
--------------------------------------------------
-- Engineer: Alex Stezskal
-- see version control for rev info
--------------------------------------------------
--  

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all;

use work.telemetry_cfg_pkg.all; 

ENTITY telemetry IS
port(
    eth_rst         : in std_logic;
    -- Interface to the Eth UDP MAC Tx
    eth_clk     : in std_logic;
    eth_telem_en : in std_logic;
    -- Packet Payload - AXI-Streaming
    eth_tdata   : out std_logic_vector(7 downto 0);  
    eth_tvalid  : out std_logic;
    eth_tlast   : out std_logic;
    eth_tready  : in  std_logic;
    -- Packet Configuration
    eth_len     : out std_logic_vector(15 downto 0); -- only need to configure length, ip_id, and dest port
    eth_ip_id   : out std_logic_vector(15 downto 0); -- other packet config should be hard coded or control
    eth_udp_dest: out std_logic_vector(15 downto 0); -- via registers

    -- Application Stream Inputs (declared in pkg)
    stream_data     : in t_stream_data;--    := stream_data_init;  -- AS 9/17/20 some weird msim issue where input port disappears when initialized
    stream_clks     : in t_stream_clks    := stream_clks_init;
    stream_valids   : in t_stream_valids  := stream_valids_init;
    stream_enables  : in t_stream_enables := stream_enables_init;
    stream_user_error : in t_stream_user_error := stream_user_error_init;
    stream_ts       : out t_stream_ts     := stream_ts_init;

    fpga_rev  : in std_logic_vector(31 downto 0):=(others=>'0');
    fpga_date : in std_logic_vector(31 downto 0):=(others=>'0');
    fpga_time : in std_logic_vector(31 downto 0):=(others=>'0');

    sys_time_clk : in std_logic;
    sys_time_en :  in std_logic := '1'
    );
END telemetry;

    ARCHITECTURE rtl OF telemetry IS 

        type StateType is (IDLE,ROUND_ROBIN_SEARCH,PKT_START,PKT_READ_AS_TREADY,PKT_DONE);
        signal state : StateType := IDLE;

        type t_fifo_out is array (MAX_NUM_STREAMS downto 0) of std_logic_vector(7 downto 0);
        signal rd_data     : t_fifo_out;
        signal rd_en       : std_logic_vector(ROUND_ROBIN_ITEMS-1 downto 0);
        signal rd_pipe_en  : std_logic;
        signal rd_en_cfg : std_logic;
        signal robin_cnt   : integer range 0 to ROUND_ROBIN_ITEMS-1; --(8) is config pkt

        signal rd_rdy      : std_logic_vector(ROUND_ROBIN_ITEMS-1 downto 0);
        signal eth_clk_cnt : std_logic_vector(26 downto 0) := (26=>'0', 2=>'0',others => '1'); --2^27= 134M counts --use (26 downto 24) for cfg pkts init value for sim send cfg early
        signal sys_time_gray    : std_logic_vector(31 downto 0);
        signal sys_time_gray_pre    : std_logic_vector(31 downto 0);
        signal pkt_byte_cnt : std_logic_vector(eth_len'left downto 0);
        signal cfg_rdy     : std_logic := '0';
        signal cfg_rdy_d     : std_logic := '0';


        signal rst_cfg_rom : std_logic;

        signal eth_tvalid_i : std_logic;
        signal eth_tlast_i : std_logic;

        signal eth_ip_id_i : std_logic_vector(15 downto 0) := (others => '0');

        signal pkt_size_mux : integer range 0 to 2**(eth_len'left+1);

        signal eth_clk_bit_d : std_logic := '0';

        signal sys_time_gray_meta     : t_stream_ts := stream_ts_init;
        signal sys_time_gray_sync     : t_stream_ts := stream_ts_init;
        signal sys_time_bin           : t_stream_ts := stream_ts_init;
        signal sys_time_gray_eth_meta : std_logic_vector(31 downto 0);
        signal sys_time_gray_eth_sync : std_logic_vector(31 downto 0);
        signal sys_time_bin_eth       : std_logic_vector(31 downto 0);

        signal rd_en_cfg_last_byte : std_logic := '0';

        attribute ASYNC_REG : string;
        attribute ASYNC_REG of sys_time_gray_meta     : signal is "TRUE";
        attribute ASYNC_REG of sys_time_gray_sync     : signal is "TRUE";
        attribute ASYNC_REG of sys_time_gray_eth_meta : signal is "TRUE";
        attribute ASYNC_REG of sys_time_gray_eth_sync : signal is "TRUE";

        function or_reduce(a : std_logic_vector) return std_logic is
            variable ret : std_logic := '0';
        begin
            for i in a'range loop
                ret := ret or a(i);
            end loop;
            return ret;
        end function or_reduce;

    BEGIN


        ------------------------------------
        -- OUTPUTS TO MAC 
        ------------------------------------
        eth_tvalid <= eth_tvalid_i;
        eth_tlast  <= eth_tlast_i;

        process(eth_clk)begin
            if rising_edge(eth_clk) then
                -- -2 because we are registering this value and end up with a clk delay
                -- last byte is pkt_size_mux-1 and eth_tlast_i will be high when pkt_byte_cnt=pkt_size_mux-1
                if(pkt_byte_cnt=pkt_size_mux-2)then
                    eth_tlast_i <= '1';
                else
                    eth_tlast_i <= '0';
                end if;
            end if;
        end process;

        -- Safe to truncate because packet size will never go above 1472, unless jumbo
        eth_len <= std_logic_vector(to_unsigned(pkt_size_mux,eth_len'length));

        eth_ip_id <= eth_ip_id_i;

        eth_udp_dest <= PORT_DEST_CONFIG when robin_cnt>=MAX_NUM_STREAMS else
                        PORT_DEST_STREAM_BASE+robin_cnt; --port number base for config and increment for streams

        eth_tdata <= (others => '0')          when eth_tvalid_i='0' else 
                     rd_data(MAX_NUM_STREAMS) when robin_cnt >= MAX_NUM_STREAMS else -- support more than 1 pkt fragment for cfg 
                     rd_data(robin_cnt);


        --setup pkt sizes slv array for use
        -- mux out the active stream pkt being checked by round robin
        pkt_size_mux <= PktPayloadSizeBytes(robin_cnt);

        -- Multiple config packet fragments in round-robin counter all come from same ROM though
        -- Cfg pkt fragments are at the end of the round_robin cnt
        -- MAX_NUM_STREAMS is the first one.
        rd_en_cfg <= or_reduce(rd_en(rd_en'left downto MAX_NUM_STREAMS))  or rd_en_cfg_last_byte;

        -- rd_en logic was designed for stream fifos where stream fifo takes care of priming the pipeline
        -- and rd_en is not high on the last byte beat.  For 1 config packet this works OK but not for 
        rd_en_cfg_last_byte <= '0' when robin_cnt < MAX_NUM_STREAMS else
                               eth_tlast_i;


        -- confirm we are going to start the config ROM off at address 0 
        -- by toggling the reset at the start of cfg_rdy flag
        rst_cfg_rom <= cfg_rdy and not cfg_rdy_d;
                         

        telem_cfg_pkt : entity work.cfg_pkt
        port map(
            rst            => rst_cfg_rom,
            rd_clk         => eth_clk,
            rd_data        => rd_data(MAX_NUM_STREAMS),
            rd_en          => rd_en_cfg,

            fpga_rev       => fpga_rev,
            fpga_date      => fpga_date,
            fpga_time      => fpga_time
        );
        
        gen_fifo_loop : for ff in 0 to MAX_NUM_STREAMS-1 generate
            gen_fifo_if_fields : if getStreamNumFields(ff)>0 generate
                stream_fifo_i : entity work.stream_fifo
                generic map(
                    STREAM_NUM       => ff,
                    STREAM_NUM_WORDS => getStreamNumFifoWords(ff),
                    STREAM_FIELDS    => getStreamNumFields(ff),
                    FIFO_ADDR_WIDTH  => getFifoAddrWidths(ff), -- 11 ==> 2048 depth for BRAM18 implementation
                    FIFO_DATA_WIDTH  => getFifoDataWidths(ff)
                )
                port map(
                    s_clk       => stream_clks(ff),
                    s_valid     => stream_valids(ff),
                    s_en        => stream_enables(ff),
                    s_data      => stream_data(ff)(getStreamFifoSDataWidth(ff)-1 downto 0),

                    s_user_error=> stream_user_error(ff),

                    pkt_size    => PktPayloadSizeBytes(ff),

                    sys_time    => sys_time_bin_eth,

                    rd_clk      => eth_clk,
                    rd_data     => rd_data(ff),
                    rd_en       => rd_en(ff),
                    rd_rdy      => rd_rdy(ff),
                    rd_rst      => eth_rst
                );
            end generate;

            gen_fifo_if_no_fields : if getStreamNumFields(ff)=0 generate
                rd_rdy(ff)  <= '0';
                rd_data(ff) <= (others => '0');
            end generate;
        end generate;

    -- generate the muxing for the rd_en signals
    gen_rd_en : for ii in 0 to ROUND_ROBIN_ITEMS-1 generate
        rd_en(ii)<= rd_pipe_en when robin_cnt=ii else '0';
    end generate;

    -- round robin counter, includes entires for the configuration packets
    process(eth_clk)begin
        if rising_edge(eth_clk) then
            if(state=ROUND_ROBIN_SEARCH and rd_rdy(robin_cnt)='1')then
                robin_cnt <= robin_cnt; --don't increase cnt we got a live one
            elsif(state=ROUND_ROBIN_SEARCH or state=PKT_DONE)then
                if(robin_cnt=ROUND_ROBIN_ITEMS-1) then --roll over count
                    robin_cnt <= 0;
                else
                    robin_cnt <= robin_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    process(eth_clk)begin
        if rising_edge(eth_clk) then
            if state=PKT_START then
                eth_ip_id_i <= eth_ip_id_i + 1;
            end if; 
        end if;
    end process;

    -- Set rd_rdy for multiple cfg fragment pkts if necessary.
    -- Only set the rd_rdy bits for config packets at certain time in the robin count.
    -- We don't want to set them high in the middle of the robin_cnt of the config packet.
    process(eth_clk)begin
        if rising_edge(eth_clk) then
            if(robin_cnt=MAX_NUM_STREAMS-1)then
                rd_rdy(rd_rdy'left downto MAX_NUM_STREAMS) <= (others => cfg_rdy);
            end if;
        end if;
    end process;

    process(eth_clk)begin
        if rising_edge(eth_clk) then
            if(eth_rst='1')then
                state <= IDLE;
            else
                case(state)is
                    when IDLE =>
                        if(eth_telem_en='1')then
                            state <= ROUND_ROBIN_SEARCH;
                        end if;

                    -- rotate round-robin through the stream fifos until one of them
                    -- indicates that it is ready (aka depth has crossed the treshold)
                    when ROUND_ROBIN_SEARCH =>
                        if(eth_telem_en='0')then
                            state <= IDLE;
                        elsif(rd_rdy(robin_cnt)='1')then 
                            state <= PKT_START;
                        end if;

                    when PKT_START =>
                        state <= PKT_READ_AS_TREADY;

                    when PKT_READ_AS_TREADY =>
                        if(pkt_byte_cnt=pkt_size_mux-1)then
                            state <= PKT_DONE;
                        end if;

                    when PKT_DONE =>
                        state <= ROUND_ROBIN_SEARCH;

                    when others => 
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    -- hold valid high while in PKT_READ_AS_TREADY, data can always be available out of fifo
    eth_tvalid_i <= '1' when state=PKT_READ_AS_TREADY else '0';
    -- support back pressure from eth mac
    -- only set rd_en to read the next byte if current beat was ack by mac via eth_redy
    rd_pipe_en      <= '1' when eth_tvalid_i='1' and eth_tready='1' and eth_tlast_i='0' else   --dont read the very last time bc we are ahead a clock
                       '0';
                       

    -- rd_byte counter, increase when axis streaming beat is valid (valid high and ready high)
    process(eth_clk)begin
        if rising_edge(eth_clk) then
            if(state=IDLE or state=PKT_DONE or state=ROUND_ROBIN_SEARCH)then
                pkt_byte_cnt <= (others=>'0');
            elsif(eth_tready='1' and eth_tvalid_i='1')then --only increase cnt when beat is ack'd
                pkt_byte_cnt <= pkt_byte_cnt + 1;
            end if;
        end if;
    end process;

    -- Configuration packet process, determine when a cfg packet should be sent
    process(eth_clk)begin
        if rising_edge(eth_clk) then
            cfg_rdy_d <= cfg_rdy;
            -- count to send packets at ~1Hz
            if(eth_rst='1')then
                eth_clk_cnt <= (26=>'0', 2=>'0',others => '1'); --reset to value s.t. config pkt comes right after reset
            else
                eth_clk_cnt <= eth_clk_cnt + 1;
            end if;

            eth_clk_bit_d <= eth_clk_cnt(eth_clk_cnt'left);


            if(eth_rst='1')then
                cfg_rdy <= '0';

            elsif(eth_clk_cnt(eth_clk_cnt'left)='1' and eth_clk_bit_d='0')then
                cfg_rdy <= '1';

            -- config packet rdy was set, wait for robin and packets to complete
            -- robin_cnt=ROUND_ROBIN_ITEMS-1 supports multiple cfg pkts fragmented
            elsif(cfg_rdy='1' and robin_cnt=ROUND_ROBIN_ITEMS-1 and state=PKT_DONE)then
                cfg_rdy <= '0';
            end if;
        end if;
    end process;
    
    ------------------------------------
    -- Timestamp
    ------------------------------------
    
    sys_time_gray_cnt : entity work.gray_cnt
    generic map(
        COUNTER_WIDTH   => 32
    )
    port map(
        GrayCount_out   => sys_time_gray_pre,
        Enable_in       => sys_time_en,
        Clear_in        => '0',  --gray cnt for sys time can keep free running
        clk             => sys_time_clk
    );

    -- put sys_time_gray through FF to ensure Flop'd output before syncrhonizer
    process(sys_time_clk)begin
        if rising_edge(sys_time_clk) then
            sys_time_gray <= sys_time_gray_pre;
        end if;
    end process;
    

    -- now we are dealing with each individual stream's clock domain
    gen_ts_sync : for ii in 0 to MAX_NUM_STREAMS-1 generate
        -- OK to sync multi-bit signal because of gray counter. At most it'll be off by one count,
        -- which is acceptable precision. Any previous transitions between slower clock edges
        -- will already be sync'd by the time it is sampled at the slower rate.
        process(stream_clks(ii))begin
            if rising_edge(stream_clks(ii)) then
                -- sync into this clock domain
                sys_time_gray_meta(ii) <= sys_time_gray;
                sys_time_gray_sync(ii) <= sys_time_gray_meta(ii);

            end if;
        end process;

        -- convert from gray code to binary count now that we are in the destination time domain
        --      B(31) <= G(31)
        --      B(30) <= B(31) xor G(30)
        --      B(29) <= B(30) xor G(29)
        --      ...
        sys_time_bin(ii)(sys_time_gray'left) <= sys_time_gray_sync(ii)(sys_time_gray'left);
        gen_logic : for i in sys_time_gray'left-1 downto 0 generate
            sys_time_bin(ii)(i) <= sys_time_bin(ii)(i+1) xor sys_time_gray_sync(ii)(i);
        end generate;

        process(stream_clks(ii))begin
            if rising_edge(stream_clks(ii)) then
                stream_ts(ii) <= sys_time_bin(ii);
            end if;
        end process;

    end generate;

    -- also syncrhnozie to eth clock domain and convert to binary for payload header timetag
    process(eth_clk)begin
        if rising_edge(eth_clk) then
            sys_time_gray_eth_meta <= sys_time_gray;
            sys_time_gray_eth_sync <= sys_time_gray_eth_meta;
        end if;
    end process;
    sys_time_bin_eth(sys_time_gray'left) <= sys_time_gray_eth_sync(sys_time_gray'left);
    gen_logic : for i in sys_time_gray'left-1 downto 0 generate
        sys_time_bin_eth(i) <= sys_time_bin_eth(i+1) xor sys_time_gray_eth_sync(i);
    end generate;


    
END;
