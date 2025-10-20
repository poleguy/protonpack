----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Ming Fong
--
-- Description: Arbitrates between two AXI4 streams
--
-- Revision: subversion.shure.com
--
-- Notes: Passes basic simulation using slightly reworked tb_rx (reworked tb_rx not checked in).
--        Currently there is always a single clock delay before any data is streamed to avoid doubling the first byte of data.
--            Will need work if maximum efficiency is desired.
--        Room for expansion: expand number of slave streams.
--        Cleaner to use a single process FSM?
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity axis_arb_two_one is
    port
    (
        rst                 : in std_logic;
        clk                 : in std_logic;

        s0_mac_dest         : in std_logic_vector(47 downto 0);  -- Header information from slave stream 0
        s0_ip_id            : in std_logic_vector(15 downto 0);
        s0_payload_len      : in std_logic_vector(15 downto 0);
        s0_ip_dest          : in std_logic_vector(31 downto 0);
        s0_udp_src          : in std_logic_vector(15 downto 0);
        s0_udp_dest         : in std_logic_vector(15 downto 0);

        s0_axis_tdata       : in  std_logic_vector(7 downto 0);  -- Payload data from slave stream 0
        s0_axis_tvalid      : in  std_logic;
        s0_axis_tlast       : in  std_logic;
        s0_axis_tready      : out std_logic;

        s1_mac_dest         : in std_logic_vector(47 downto 0);  -- Header information from slave stream 1
        s1_ip_id            : in std_logic_vector(15 downto 0);
        s1_payload_len      : in std_logic_vector(15 downto 0);
        s1_ip_dest          : in std_logic_vector(31 downto 0);
        s1_udp_src          : in std_logic_vector(15 downto 0);
        s1_udp_dest         : in std_logic_vector(15 downto 0);

        s1_axis_tdata       : in  std_logic_vector(7 downto 0);  -- Payload data from slave stream 1
        s1_axis_tvalid      : in  std_logic;
        s1_axis_tlast       : in  std_logic;
        s1_axis_tready      : out std_logic;

        m_mac_dest          : out std_logic_vector(47 downto 0); -- Header information master stream
        m_ip_id             : out std_logic_vector(15 downto 0);
        m_payload_len       : out std_logic_vector(15 downto 0);
        m_ip_dest           : out std_logic_vector(31 downto 0);
        m_udp_src           : out std_logic_vector(15 downto 0);
        m_udp_dest          : out std_logic_vector(15 downto 0);

        m_axis_tdata        : out std_logic_vector(7 downto 0);  -- Payload data master stream
        m_axis_tvalid       : out std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tready       : in  std_logic

    );
end axis_arb_two_one;


architecture behavioral of axis_arb_two_one is

    type state_type is (IDLE,
                        WAIT_LAST
                        );
    signal state      : state_type;
    signal state_next : state_type;

    signal last_valid_ready : std_logic;
    signal s0_tdata_sel     : std_logic;
    signal s1_tdata_sel     : std_logic;
    signal tdata_sel        : std_logic;

begin

----------------------------------------------------------------------------------
--
-- Outpt data MUX
--
----------------------------------------------------------------------------------

    -- For tdata, tlast, and header info, default to stream 0. Don't care if data is presented downstream because of tready/tvalid.
    -- For tvalid, default to '0' to avoid sending first byte twice (because of single clock cycle latency).
    -- FIXME might still be sending first byte twice, seen in hardware test.
    -- For tready, default to '0' so no data streams before FSM is ready.
    m_axis_tdata  <= s1_axis_tdata  when tdata_sel = '1' else s0_axis_tdata;
    m_axis_tlast  <= s1_axis_tlast  when tdata_sel = '1' else s0_axis_tlast;
    m_axis_tvalid <= s1_axis_tvalid when tdata_sel = '1' else
                     s0_axis_tvalid when tdata_sel = '0' else
                     '0';

    m_mac_dest    <= s1_mac_dest    when tdata_sel = '1' else s0_mac_dest;
    m_ip_id       <= s1_ip_id       when tdata_sel = '1' else s0_ip_id;
    m_payload_len <= s1_payload_len when tdata_sel = '1' else s0_payload_len;
    m_ip_dest     <= s1_ip_dest     when tdata_sel = '1' else s0_ip_dest;
    m_udp_src     <= s1_udp_src     when tdata_sel = '1' else s0_udp_src;
    m_udp_dest    <= s1_udp_dest    when tdata_sel = '1' else s0_udp_dest;

    s1_axis_tready <= m_axis_tready when tdata_sel = '1' else '0';
    s0_axis_tready <= m_axis_tready when tdata_sel = '0' else '0';

    -- Last data handshake to signal FSM.
    last_valid_ready <= s1_axis_tlast and s1_axis_tvalid and m_axis_tready when tdata_sel = '1' else
                        s0_axis_tlast and s0_axis_tvalid and m_axis_tready;

----------------------------------------------------------------------------------
--
-- Clocked process for MUX select
--
----------------------------------------------------------------------------------

    process_sel : process (clk, rst) begin

        if (rising_edge(clk)) then
            if (rst = '1') then
                state <= IDLE;
            else
                state <= state_next;

                -- Select for data MUX.
                if (s0_tdata_sel = '1') then
                    tdata_sel <= '0';
                elsif (s1_tdata_sel = '1') then
                    tdata_sel <= '1';
                end if;

            end if;
        end if;

    end process process_sel;

----------------------------------------------------------------------------------
--
-- State Machine
--
----------------------------------------------------------------------------------

    process_fsm : process (state, s0_axis_tvalid, s1_axis_tvalid, last_valid_ready) begin

        state_next    <= state;
        s0_tdata_sel  <= '0';
        s1_tdata_sel  <= '0';

        case (state) is

            -- IDLE
            -- Wait for incoming valid AXI4s data. Switch contol for MUX based on which data is valid.
            when IDLE =>
                if (s0_axis_tvalid = '1') then
                    s0_tdata_sel <= '1';
                    state_next   <= WAIT_LAST;
                elsif (s1_axis_tvalid = '1') then
                    s1_tdata_sel <= '1';
                    state_next   <= WAIT_LAST;
                end if;

            -- WAIT_LAST
            -- Wait for stream to finish. Do not want to switch MUX in middle of transmission.
            when WAIT_LAST =>
                if (last_valid_ready = '1') then
                    state_next    <= IDLE;
                end if;

        end case;
    end process process_fsm;

end behavioral;
