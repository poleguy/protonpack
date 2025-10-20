----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Ming Fong
--
-- Description: Ethernet RX MAC GMII
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity eth_udp_mac_rx is
    port
    (
        rst                   : in std_logic;
        clk                   : in std_logic;
        mac_gmii_en           : in std_logic;

        cfg_this_dev_mac_addr : in std_logic_vector(47 downto 0);
        cfg_this_dev_ip_addr  : in std_logic_vector(31 downto 0);

        fcs_err               : out std_logic;
        frame_len_err         : out std_logic;

        rx_mac_src            : out std_logic_vector(47 downto 0);
        rx_ip_id              : out std_logic_vector(15 downto 0);
        rx_payload_len        : out std_logic_vector(15 downto 0);
        rx_ip_src             : out std_logic_vector(31 downto 0);
        rx_udp_dest           : out std_logic_vector(15 downto 0);
        rx_udp_src            : out std_logic_vector(15 downto 0);

        m_axis_tdata          : out std_logic_vector(7 downto 0);
        m_axis_tvalid         : out std_logic;
        m_axis_tlast          : out std_logic;
        m_axis_tready         : in std_logic;

        rxd_en                : in std_logic;
        rxd                   : in std_logic_vector(7 downto 0)

    );
end eth_udp_mac_rx;


architecture behavioral of eth_udp_mac_rx is

    type bytes is array (integer range <>) of std_logic_vector(7 downto 0);

    signal this_dev_mac    : bytes(5 downto 0);
    signal mac_src         : bytes(5 downto 0);
    signal mac_dest        : bytes(5 downto 0);
    signal this_dev_ip     : bytes(3 downto 0);
    signal ip_id           : bytes(1 downto 0);
    signal ip_src          : bytes(3 downto 0);
    signal ip_dest         : bytes(3 downto 0);
    signal udp_src         : bytes(1 downto 0);
    signal udp_dest        : bytes(1 downto 0);

    signal hdr_csum        : bytes(1 downto 0) := (others => (others => '0')); -- FIXME do we want to check?
    signal udp_csum        : bytes(1 downto 0) := (others => (others => '0'));

    signal rxd_cnt         : std_logic_vector(10 downto 0) := (others => '0');
    signal hold_rxd_cnt    : std_logic;
    signal rx_en           : std_logic;

    signal pkt_udp_btt     : std_logic_vector(15 downto 0);
    signal udp_len         : std_logic_vector(15 downto 0) := (others => '0');
    signal ip_len          : std_logic_vector(15 downto 0) := (others => '0');

    signal pload_cnt       : std_logic_vector(11 downto 0) := (others => '0');

    signal fcs_cnt         : std_logic_vector(1 downto 0) := (others => '0');
    signal fcs_gen_out     : std_logic_vector(31 downto 0);
    signal eth_fcs_calc    : bytes(3 downto 0);

    signal tdata_int       : std_logic_vector(7 downto 0) := (others => '0');
    signal tvalid_i        : std_logic;
    signal tlast_i         : std_logic;

    signal fcs_err_i       : std_logic;
    signal frame_len_err_i : std_logic;


    type state_type is (IDLE,
                        READY,
                        FIND_SFD,
                        HDR,
                        HDR_BROADCAST,
                        PAYLOAD,
                        FCS,
                        DROP
                        );
    signal state : state_type;


begin

        -- drive AXIs outputs
        m_axis_tdata  <= tdata_int when tvalid_i='1' else x"00";
        m_axis_tvalid <= tvalid_i;
        m_axis_tlast  <= tlast_i;

        -- drive error flags
        fcs_err       <= fcs_err_i;
        frame_len_err <= frame_len_err_i;

        -- drive output header fields
        rx_mac_src     <= mac_src(0) & mac_src(1) & mac_src(2) & mac_src(3) & mac_src(4) & mac_src(5);
        rx_ip_id       <= ip_id(0) & ip_id(1);
        rx_payload_len <= pkt_udp_btt;
        rx_ip_src      <= ip_src(0) & ip_src(1) & ip_src(2) & ip_src(3);
        rx_udp_dest    <= udp_dest(0) & udp_dest(1);
        rx_udp_src     <= udp_src(0) & udp_src(1);

        -- calculate necessary lengths based on the udp payload bytes to transfer (btt)
        pkt_udp_btt <= ip_len - 20 - 8;

        -- reassign these input into byte arrays so easier to use
        this_dev_mac(0) <= cfg_this_dev_mac_addr(47 downto 40);
        this_dev_mac(1) <= cfg_this_dev_mac_addr(39 downto 32);
        this_dev_mac(2) <= cfg_this_dev_mac_addr(31 downto 24);
        this_dev_mac(3) <= cfg_this_dev_mac_addr(23 downto 16);
        this_dev_mac(4) <= cfg_this_dev_mac_addr(15 downto 8);
        this_dev_mac(5) <= cfg_this_dev_mac_addr(7 downto 0);
        this_dev_ip(0)  <= cfg_this_dev_ip_addr(31 downto 24);
        this_dev_ip(1)  <= cfg_this_dev_ip_addr(23 downto 16);
        this_dev_ip(2)  <= cfg_this_dev_ip_addr(15 downto 8);
        this_dev_ip(3)  <= cfg_this_dev_ip_addr(7 downto 0);

        process(clk) begin
            if rising_edge(clk) then
                if (rst = '1') then
                    fcs_cnt         <= (others => '0');
                    fcs_err_i       <= '0';
                    frame_len_err_i <= '0';
                    tvalid_i        <= '0';
                    tlast_i         <= '0';
                    rx_en           <= '0';
                    state           <= IDLE;
                else
                    case(state)is

                        when IDLE =>
                            if (mac_gmii_en='1') then
                                state <= READY;
                            end if;

                        when READY =>
                            fcs_cnt         <= (others => '0');
                            fcs_err_i       <= '0';
                            frame_len_err_i <= '0';
                            pload_cnt       <= (others => '0');
                            tvalid_i        <= '0';
                            tlast_i         <= '0';
                            hold_rxd_cnt    <= '1';
                            if (rxd_en='1') then
                                rx_en <= '1';
                                state <= FIND_SFD;
                            end if;

                        when FIND_SFD =>
                            if (tdata_int = x"d5") then
                                hold_rxd_cnt <= '0';
                                state        <= HDR;
                            elsif (tdata_int /= x"55") then
                                state <= DROP;
                            end if;

                        when HDR =>
                            case conv_integer(rxd_cnt) is
                                -- check if dst MAC is our MAC or broadcast
                                when 8  => if (tdata_int = x"FF") then state <= HDR_BROADCAST;
                                           elsif (tdata_int /= this_dev_mac(0)) then state <= DROP; end if;
                                when 9  => if (tdata_int /= this_dev_mac(1)) then state <= DROP; end if;
                                when 10 => if (tdata_int /= this_dev_mac(2)) then state <= DROP; end if;
                                when 11 => if (tdata_int /= this_dev_mac(3)) then state <= DROP; end if;
                                when 12 => if (tdata_int /= this_dev_mac(4)) then state <= DROP; end if;
                                when 13 => if (tdata_int /= this_dev_mac(5)) then state <= DROP; end if;
                                -- check if ethernet II type
                                when 20 => if (tdata_int /= x"08") then state <= DROP; end if;
                                -- check if IPv4
                                when 22 => if (tdata_int /= x"45") then state <= DROP; end if;
                                -- check if dst IP is our IP
                                when 38 => if (tdata_int /= this_dev_ip(0)) then state <= DROP; end if;
                                when 39 => if (tdata_int /= this_dev_ip(1)) then state <= DROP; end if;
                                when 40 => if (tdata_int /= this_dev_ip(2)) then state <= DROP; end if;
                                when 41 => if (tdata_int /= this_dev_ip(3)) then state <= DROP; end if;
                                -- end of header, move along, move along
                                when 49 => tvalid_i  <= '1';
                                           pload_cnt <= pload_cnt + 1;
                                           state     <= PAYLOAD;
                                when others => null;
                            end case;

                        when HDR_BROADCAST =>
                            case conv_integer(rxd_cnt) is
                                -- check if dst MAC is broadcast
                                when 9  => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 10 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 11 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 12 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 13 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                -- check if ethernet II type
                                when 20 => if (tdata_int /= x"08") then state <= DROP; end if;
                                -- check if IPv4
                                when 22 => if (tdata_int /= x"45") then state <= DROP; end if;
                                -- check if dst IP is broadcast
                                when 38 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 39 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 40 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                when 41 => if (tdata_int /= x"FF") then state <= DROP; end if;
                                -- end of header, move along, move along
                                when 49 => tvalid_i  <= '1';
                                           pload_cnt <= pload_cnt + 1;
                                           state     <= PAYLOAD;
                                when others => null;
                            end case;

                        when PAYLOAD =>
                            tvalid_i <= '1';
                            if (pload_cnt=pkt_udp_btt-1) then
                                tlast_i <= '1';
                                state   <= FCS;
                            else
                                pload_cnt <= pload_cnt + 1;
                            end if;

                        when FCS =>
                            tvalid_i <= '0';
                            tlast_i  <= '0';

                            if(fcs_cnt=0)then
                                eth_fcs_calc(3) <= fcs_gen_out(31 downto 24);
                                eth_fcs_calc(2) <= fcs_gen_out(23 downto 16);
                                eth_fcs_calc(1) <= fcs_gen_out(15 downto 8);
                                eth_fcs_calc(0) <= fcs_gen_out(7 downto 0);
                            end if;
                            if (fcs_cnt=3) then
                                rx_en <= '0';
                                state <= IDLE;
                            else
                                fcs_cnt <= fcs_cnt + 1;
                            end if;

                            case conv_integer(fcs_cnt) is
                                -- check FCS, if rxd_en is still high then packet was longer than expected
                                when 0 => if (tdata_int /= eth_fcs_calc(0)) then fcs_err_i <= '1'; end if;
                                when 1 => if (tdata_int /= eth_fcs_calc(1)) then fcs_err_i <= '1'; end if;
                                when 2 => if (tdata_int /= eth_fcs_calc(2)) then fcs_err_i <= '1'; end if;
                                when 3 => if (tdata_int /= eth_fcs_calc(3)) then fcs_err_i <= '1'; end if;
                                          if (rxd_en='1') then frame_len_err_i <= '1'; end if; -- FIXME is this right?
                                when others => null;
                            end case;

                        when DROP =>
                            if (rxd_en='0') then
                                rx_en <= '0';
                                state <= IDLE;
                            else
                                pload_cnt <= pload_cnt + 1;
                            end if;

                    end case;
                end if;
            end if;
        end process;

        process(clk)
        begin
            if rising_edge(clk) then
                if(rxd_en='1')then
                    tdata_int <= rxd;
                    case conv_integer(rxd_cnt) is
                        when 8 =>  mac_dest(0) <= tdata_int;
                        when 9 =>  mac_dest(1) <= tdata_int;
                        when 10 => mac_dest(2) <= tdata_int;
                        when 11 => mac_dest(3) <= tdata_int;
                        when 12 => mac_dest(4) <= tdata_int;
                        when 13 => mac_dest(5) <= tdata_int;
                        when 14 => mac_src(0)  <= tdata_int;
                        when 15 => mac_src(1)  <= tdata_int;
                        when 16 => mac_src(2)  <= tdata_int;
                        when 17 => mac_src(3)  <= tdata_int;
                        when 18 => mac_src(4)  <= tdata_int;
                        when 19 => mac_src(5)  <= tdata_int;

                        when 24 => ip_len(15 downto 8) <= tdata_int;
                        when 25 => ip_len(7 downto 0)  <= tdata_int;
                        when 26 => ip_id(0)    <= tdata_int;
                        when 27 => ip_id(1)    <= tdata_int;

                        when 34 => ip_src(0)   <= tdata_int;
                        when 35 => ip_src(1)   <= tdata_int;
                        when 36 => ip_src(2)   <= tdata_int;
                        when 37 => ip_src(3)   <= tdata_int;
                        when 38 => ip_dest(0)  <= tdata_int;
                        when 39 => ip_dest(1)  <= tdata_int;
                        when 40 => ip_dest(2)  <= tdata_int;
                        when 41 => ip_dest(3)  <= tdata_int;
                        when 42 => udp_src(0)  <= tdata_int;
                        when 43 => udp_src(1)  <= tdata_int;
                        when 44 => udp_dest(0) <= tdata_int;
                        when 45 => udp_dest(1) <= tdata_int;
                        when 46 => udp_len(15 downto 8) <= tdata_int;
                        when 47 => udp_len(7 downto 0)  <= tdata_int;

                        when others => null;
                    end case;
                end if;
            end if;
        end process;

        process(clk)
        begin
            if rising_edge(clk) then
                if (rx_en='0') then
                    rxd_cnt <= (others => '0');
                elsif (hold_rxd_cnt='1') then -- initialize count after preamble and SFD
                    rxd_cnt <= "000" & x"08";
                else
                    rxd_cnt <= rxd_cnt + 1;
                end if;
            end if;
        end process;

    eth_fcs_gen : entity work.eth_fcs_gen
    port map(
        clk    => clk,
        txd    => rxd,
        txd_en => rxd_en,
        fcs    => fcs_gen_out);

end behavioral;

