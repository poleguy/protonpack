----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Ming Fong
--
-- Description: Register command handler
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity eth_reg_handler is
    port
    (
        rst                 : in std_logic;
        clk                 : in std_logic;

        rx_mac_src          : in std_logic_vector(47 downto 0);  -- Header information from RX MAC
        rx_ip_id            : in std_logic_vector(15 downto 0);
        rx_payload_len      : in std_logic_vector(15 downto 0);
        rx_ip_src           : in std_logic_vector(31 downto 0);
        rx_udp_dest         : in std_logic_vector(15 downto 0);
        rx_udp_src          : in std_logic_vector(15 downto 0);

        s_axis_tdata        : in  std_logic_vector(7 downto 0);  -- Payload data from RX MAC
        s_axis_tvalid       : in  std_logic;
        s_axis_tlast        : in  std_logic;
        s_axis_tready       : out std_logic;

        tx_mac_dest         : out std_logic_vector(47 downto 0); -- Header information for TX MAC
        tx_ip_id            : out std_logic_vector(15 downto 0);
        tx_payload_len      : out std_logic_vector(15 downto 0);
        tx_ip_dest          : out std_logic_vector(31 downto 0);
        tx_udp_src          : out std_logic_vector(15 downto 0);
        tx_udp_dest         : out std_logic_vector(15 downto 0);

        m_axis_tdata        : out std_logic_vector(7 downto 0);  -- Response packet for register reads
        m_axis_tvalid       : out std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tready       : in  std_logic;

        reg_en              : out std_logic;                     -- Simple bus to registers
        reg_data_rd         : in  std_logic_vector(31 downto 0);
        reg_data_wr         : out std_logic_vector(31 downto 0);
        reg_addr            : out std_logic_vector(23 downto 0); -- FIXME or (14 downto 0)?
        reg_re              : out std_logic;
        reg_wr              : out std_logic
    );
end eth_reg_handler;


architecture behavioral of eth_reg_handler is

    constant REG_RD_TYPE : std_logic_vector(7 downto 0) := x"01";
    constant REG_WR_TYPE : std_logic_vector(7 downto 0) := x"10";

    type bytes is array (integer range <>) of std_logic_vector(7 downto 0);

    type state_type is (IDLE,
                        GET_ADDR,
                        GET_DATA,
                        WAIT_LAST_S,
                        SEND_CMD,
                        GET_RD_DATA,
                        SEND_RESP_FIST,
                        SEND_RD_RESP,
                        WAIT_LAST_RESP,
                        DROP
                        );
    signal state      : state_type;
    signal state_next : state_type;

    signal save_hdr       : std_logic;
    signal incr_byte_cnt  : std_logic;
    signal clr_byte_cnt   : std_logic;
    signal save_cmd_type  : std_logic;
    signal save_addr      : std_logic;
    signal save_data      : std_logic;
    signal send_reg_cmd   : std_logic;
    signal save_rd_data   : std_logic;
    signal update_data    : std_logic;
    signal send_valid     : std_logic;
    signal send_last      : std_logic;
    signal tdata_32       : std_logic_vector(31 downto 0);
    signal tlast_32       : std_logic;
    signal byte_cnt       : std_logic_vector(5 downto 0);
    signal cmd_type       : std_logic_vector(7 downto 0);
    signal reg_data_rd_i  : std_logic_vector(31 downto 0);

begin

    process_seq : process (clk, rst) begin

        if (rising_edge(clk)) then
            if (rst = '1') then
                state    <= IDLE;
                byte_cnt <= (others => '0');
            else
                state <= state_next;

                if (s_axis_tvalid = '1') then
                    tdata_32 <= tdata_32(23 downto 0) & s_axis_tdata;
                    tlast_32 <= s_axis_tlast;
                end if;

                if (save_hdr = '1') then
                    tx_mac_dest    <= rx_mac_src;
                    tx_ip_id       <= rx_ip_id;
                    tx_payload_len <= rx_payload_len;
                    tx_ip_dest     <= rx_ip_src;
                    tx_udp_src     <= rx_udp_dest;
                    tx_udp_dest    <= rx_udp_src;
                end if;

                if (clr_byte_cnt = '1') then
                    byte_cnt <= (others => '0');
                elsif (incr_byte_cnt = '1') then
                    byte_cnt <= byte_cnt + 1;
                end if;

                if (save_cmd_type = '1') then
                    cmd_type <= s_axis_tdata;
                end if;

                if (save_addr = '1') then
                    reg_addr <= tdata_32(23 downto 0); -- FIXME width
                end if;

                if (save_data = '1') then
                    reg_data_wr <= tdata_32;
                end if;

                if (save_rd_data = '1') then
                    reg_data_rd_i <= reg_data_rd;
                elsif (cmd_type = REG_WR_TYPE) then
                    reg_data_rd_i <= (others => '0');
                end if;

                if (send_valid = '1') then
                    m_axis_tvalid <= '1';
                else
                    m_axis_tvalid <= '0';
                end if;

                if (send_last = '1') then
                    m_axis_tlast <= '1';
                else
                    m_axis_tlast <= '0';
                end if;

                if (update_data = '1') then
                    case conv_integer(byte_cnt) is
                        when 0 => m_axis_tdata <= cmd_type;
                        when 1 => m_axis_tdata <= x"00";
                        when 2 => m_axis_tdata <= x"00";
                        when 3 => m_axis_tdata <= x"00";
                        when 4 => m_axis_tdata <= reg_data_rd_i(31 downto 24);
                        when 5 => m_axis_tdata <= reg_data_rd_i(23 downto 16);
                        when 6 => m_axis_tdata <= reg_data_rd_i(15 downto 8);
                        when 7 => m_axis_tdata <= reg_data_rd_i(7 downto 0);
                        when others => m_axis_tdata <= x"00";
                    end case;
                end if;

            end if;
        end if;

    end process process_seq;


    process_comb : process (state, byte_cnt, s_axis_tvalid, m_axis_tready, tlast_32, cmd_type) begin

        state_next    <= state;
        save_hdr      <= '0';
        s_axis_tready <= '0';
        incr_byte_cnt <= '0';
        clr_byte_cnt  <= '0';
        save_cmd_type <= '0';
        save_addr     <= '0';
        save_data     <= '0';
        send_reg_cmd  <= '0';
        reg_re        <= '0';
        reg_wr        <= '0';
        save_rd_data  <= '0';
        update_data   <= '0';
        send_valid    <= '0';
        send_last     <= '0';
        reg_en        <= '0';

        case (state) is
        -- Payload data needs to be at least 18 bytes. (preamble doesn't count, CRC does)
        -- 14 eth header, 20 ip header, 8 udp header, 18 payload, 4 crc = 64 bytes

            -- IDLE
            -- Wait for incoming AXI4s data is valid. All header information should be available immediately.
            when IDLE =>
                if (s_axis_tvalid = '1') then
                    s_axis_tready <= '1';
                    save_hdr      <= '1';
                    save_cmd_type <= '1';
                    state_next    <= GET_ADDR;
                else
                    clr_byte_cnt <= '1';
                end if;

            -- GET_ADDR
            -- Shift bytes in until we reach the register command type and address.
            -- Move to the correct state based on the command type.
            when GET_ADDR => -- FIXME multi command?
                s_axis_tready <= '1';
                if (byte_cnt = 7) then
                    save_addr     <= '1';
                    clr_byte_cnt  <= '1';
                    if (cmd_type = REG_RD_TYPE) then
                        state_next <= WAIT_LAST_S;
                    elsif (cmd_type = REG_WR_TYPE) then
                        state_next <= GET_DATA;
                    end if;
                else
                    incr_byte_cnt <= '1';
                end if;

            -- GET_DATA
            -- For register writes, save the write data.
            when GET_DATA =>
                s_axis_tready <= '1';
                if (byte_cnt = 7) then
                    save_data    <= '1';
                    clr_byte_cnt <= '1';
                    state_next   <= WAIT_LAST_S;
                else
                    incr_byte_cnt <= '1';
                end if;

            -- WAIT_LAST_S
            -- Wait until tlast flag befoe moving on.
            when WAIT_LAST_S =>
                if (tlast_32 = '1') then
                    state_next <= SEND_CMD;
                else
                    s_axis_tready <= '1';
                end if;

            -- SEND_CMD
            -- Send the register command over the simple bus to the register interface.
            when SEND_CMD =>
                reg_en       <= '1';
                send_reg_cmd <= '1';
                if (cmd_type = REG_RD_TYPE) then
                    reg_re     <= '1';
                    state_next <= GET_RD_DATA;
                elsif (cmd_type = REG_WR_TYPE) then
                    reg_wr     <= '1';
                    state_next <= IDLE;
                end if;

            -- GET_RD_DATA
            -- Save read data from the simple bus.
            when GET_RD_DATA =>
                reg_en       <= '1';
                save_rd_data <= '1';
                state_next   <= SEND_RESP_FIST;

            -- SEND_RESP_FIST
            -- Present first valid data downstream.
            when SEND_RESP_FIST =>
                send_valid    <= '1';
                update_data   <= '1';
                incr_byte_cnt <= '1';
                state_next    <= SEND_RD_RESP;

            -- SEND_RD_RESP
            -- Continue sending the read response to the TX MAC. Valid must not go low
            -- for the duration of the packet. State is sensitive to back pressure via tready.
            when SEND_RD_RESP =>
                send_valid <= '1';
                if (m_axis_tready = '1') then
                    update_data   <= '1';
                    incr_byte_cnt <= '1';
                    if (conv_integer(byte_cnt) = 17) then
                        send_last    <= '1';
                        state_next   <= WAIT_LAST_RESP;
                    else
                        state_next    <= SEND_RD_RESP;
                    end if;
                end if;

            -- WAIT_LAST_RESP
            -- After presenting last data downstream, wait for final handshake.
            when WAIT_LAST_RESP =>
                if (m_axis_tready = '1') then
                    clr_byte_cnt <= '1';
                    state_next   <= IDLE;
                else
                    send_valid <= '1';
                    send_last  <= '1';
                end if;

            -- DROP
            -- Signal ready but don't do anything until tlast.
            when DROP =>
                if (tlast_32 = '1') then
                    state_next <= IDLE;
                else
                    s_axis_tready <= '1';
                end if;

        end case;
    end process process_comb;

end behavioral;
