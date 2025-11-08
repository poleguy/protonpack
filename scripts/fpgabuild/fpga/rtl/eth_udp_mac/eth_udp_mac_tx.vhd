----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
--
-- Description: Ethernet TX MAC GMII
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity eth_udp_mac_tx is
    port
    (
        rst             : in std_logic;
        clk             : in std_logic;
        mac_gmii_en     : in std_logic;

        cfg_src_mac_addr : in std_logic_vector(47 downto 0);
        cfg_ip_src_addr  : in std_logic_vector(31 downto 0);

        -- wait an extra number of clocks between packets
        cfg_extra_wait  : in std_logic_vector(7 downto 0) := (others=>'0'); -- in units of eth_clk

        tx_mac_dest     : in std_logic_vector(47 downto 0);
        tx_ip_id        : in std_logic_vector(15 downto 0);
        tx_payload_len  : in std_logic_vector(15 downto 0);
        tx_ip_dest      : in std_logic_vector(31 downto 0);
        tx_udp_src      : in std_logic_vector(15 downto 0);
        tx_udp_dest     : in std_logic_vector(15 downto 0);

        s_axis_tdata    : in std_logic_vector(7 downto 0);
        s_axis_tvalid   : in std_logic;
        s_axis_tlast    : in std_logic;
        s_axis_tready   : out std_logic;


        txd_en          : out std_logic;
        txd             : out std_logic_vector(7 downto 0)

    );
end eth_udp_mac_tx;


architecture behavioral of eth_udp_mac_tx is

    constant MAX_UDP_PAYLOAD_BYTES : integer := 1472;

    type bytes is array (integer range <>) of std_logic_vector(7 downto 0);

    signal app_data         : std_logic_vector(7 downto 0);
    signal ip_id            : bytes(1 downto 0);
    signal mac_src          : bytes(5 downto 0);
    signal ip_src           : bytes(3 downto 0);
    signal eth_fcs_calc     : bytes(3 downto 0);

    signal hdr_csum         : bytes(1 downto 0) := (others => (others => '0'));
    signal udp_csum         : bytes(1 downto 0) := (others => (others => '0'));

    signal txd_cnt          : std_logic_vector(10 downto 0):=(others => '0');
    signal tx_en            : std_logic := '0';
    signal txd_i            : std_logic_vector(7 downto 0);
    signal txd_hdr          : std_logic_vector(7 downto 0);
    signal txd_fcs          : std_logic_vector(7 downto 0);
    signal txd_sel          : std_logic_vector(1 downto 0);

    signal pkt_udp_btt      : std_logic_vector(15 downto 0);
    signal udp_len          : std_logic_vector(15 downto 0);
    signal ip_len           : std_logic_vector(15 downto 0);

    signal pload_cnt        : std_logic_vector(11 downto 0);

    signal fcs_cnt          : std_logic_vector(1 downto 0) := (others=>'0');
    signal gap_wait_cnt     : std_logic_vector(3 downto 0);
    signal extra_wait_cnt   : std_logic_vector(cfg_extra_wait'left downto 0) := (others=>'0');

    signal fcs_gen_out      : std_logic_vector(31 downto 0);
    signal fcs_gen_store    : std_logic_vector(31 downto 0);

    signal app_rdy_pload    : std_logic;
    signal app_rdy_hdr      : std_logic;

    signal s_axis_tready_i  : std_logic;

    type state_type is (IDLE,
                        READY,
                        HDR,
                        PAYLOAD,
                        FCS,
                        GAP_WAIT,
                        EXTRA_WAIT
                        );
    signal state : state_type;



begin

        s_axis_tready <= s_axis_tready_i;

        txd_en <= tx_en;
        txd    <= txd_i;

        -- txd data mux, header, data from app axis, or eth fcs
        txd_i <= txd_hdr  when txd_sel="01" else
                 app_data when txd_sel="10" else
                 txd_fcs  when txd_sel="11" else
                 X"00";

        -- clocked process for timing. Moved app_rdy_hdr and app_rdy_pload one clock earlier to compensate
        process(clk) begin
            if rising_edge(clk) then
                s_axis_tready_i <= app_rdy_hdr or app_rdy_pload;
            end if;
        end process;

        -- count works out such that get a new 4 byte word from axis when cnt[1:0]=01
        app_rdy_pload <= '0' when pload_cnt=pkt_udp_btt-2 else
                         '1' when txd_sel="10" else
                         '0';

        txd_fcs <= fcs_gen_out(7 downto 0) when fcs_cnt = 0 else
                   eth_fcs_calc(conv_integer(fcs_cnt));

        -- calculate necessary lengths based on the udp payload bytes to transfer (btt)
        udp_len    <= pkt_udp_btt + 8;
        ip_len     <= udp_len + 20;

        -- reassign these input into byte arrays so easier to use
        mac_src(0) <= cfg_src_mac_addr(47 downto 40);
        mac_src(1) <= cfg_src_mac_addr(39 downto 32);
        mac_src(2) <= cfg_src_mac_addr(31 downto 24);
        mac_src(3) <= cfg_src_mac_addr(23 downto 16);
        mac_src(4) <= cfg_src_mac_addr(15 downto 8);
        mac_src(5) <= cfg_src_mac_addr(7 downto 0);
        ip_src(0)  <= cfg_ip_src_addr(31 downto 24);
        ip_src(1)  <= cfg_ip_src_addr(23 downto 16);
        ip_src(2)  <= cfg_ip_src_addr(15 downto 8);
        ip_src(3)  <= cfg_ip_src_addr(7 downto 0);

        process(clk) begin
            if rising_edge(clk) then
                if (rst = '1') then
                    fcs_cnt <= (others => '0');
                    tx_en <= '0';
                    state <= IDLE;
                else
                    case(state)is

                        when IDLE =>
                            if(mac_gmii_en='1')then
                                state <= READY;
                            end if;

                        when READY =>
                            fcs_cnt        <= (others => '0');
                            gap_wait_cnt   <= (others => '0');
                            extra_wait_cnt <= (others => '0');
                            pload_cnt <= (others => '0');
                            if(s_axis_tvalid='1')then
                                txd_sel  <= "01";
                                tx_en    <= '1';
                                state    <= HDR;
                            end if;

                        when HDR =>
                            if(txd_cnt=49)then
                                txd_sel <= "10";
                                state <= PAYLOAD;
                            end if;

                        when PAYLOAD =>
                            if(pload_cnt=pkt_udp_btt-1)then
                                txd_sel <= "11";
                                state <= FCS;
                            else
                                pload_cnt <= pload_cnt + 1;
                            end if;

                        when FCS =>
                            if(fcs_cnt=0)then
                                eth_fcs_calc(3)  <= fcs_gen_out(31 downto 24);
                                eth_fcs_calc(2)  <= fcs_gen_out(23 downto 16);
                                eth_fcs_calc(1)  <= fcs_gen_out(15 downto 8);
                                eth_fcs_calc(0)  <= fcs_gen_out(7 downto 0);
                            end if;
                            if(fcs_cnt=3)then
                                tx_en <= '0';
                                state <= GAP_WAIT;
                            else
                                fcs_cnt <= fcs_cnt + 1;
                            end if;

                        when GAP_WAIT =>
                            if(gap_wait_cnt=11)then
                                if(cfg_extra_wait=0)then
                                    state <= IDLE;
                                else
                                    state <= EXTRA_WAIT;
                                end if;
                            else
                                gap_wait_cnt <= gap_wait_cnt + 1;
                            end if;

                        when EXTRA_WAIT =>
                            if(extra_wait_cnt=cfg_extra_wait)then
                                state <= IDLE;
                            else
                                extra_wait_cnt <= extra_wait_cnt + 1;
                            end if;

                    end case;
                end if;
            end if;
        end process;

        process(clk)
        begin
            if rising_edge(clk) then
                if(s_axis_tvalid='1' and s_axis_tready_i='1')then
                    app_data <= s_axis_tdata;
                end if;
                if(s_axis_tvalid='1' and txd_cnt=0)then
                    pkt_udp_btt <= tx_payload_len;
                end if;
            end if;
        end process;

        process(clk)
        begin
            if rising_edge(clk) then
                if(tx_en='0')then
                    txd_cnt <= (others => '0');
                else
                    txd_cnt <= txd_cnt + 1;
                end if;
            end if;
        end process;

        process (txd_cnt,tx_mac_dest,mac_src,ip_len,tx_ip_id,hdr_csum,ip_src,tx_ip_dest,tx_udp_src,tx_udp_dest,udp_len,udp_csum)
        begin
            app_rdy_hdr <= '0';
            case conv_integer(txd_cnt) is

                when 0 =>  txd_hdr <= X"55";
                when 1 =>  txd_hdr <= X"55";
                when 2 =>  txd_hdr <= X"55";
                when 3 =>  txd_hdr <= X"55";
                when 4 =>  txd_hdr <= X"55";
                when 5 =>  txd_hdr <= X"55";
                when 6 =>  txd_hdr <= X"55";
                when 7 =>  txd_hdr <= X"d5"; -- sofd
                when 8 =>  txd_hdr <= tx_mac_dest(47 downto 40); -- mac des addr MSB
                when 9 =>  txd_hdr <= tx_mac_dest(39 downto 32);
                when 10 => txd_hdr <= tx_mac_dest(31 downto 24);
                when 11 => txd_hdr <= tx_mac_dest(23 downto 16);
                when 12 => txd_hdr <= tx_mac_dest(15 downto 8);
                when 13 => txd_hdr <= tx_mac_dest(7 downto 0);   -- mac des addr LSB
                when 14 => txd_hdr <= mac_src(0);
                when 15 => txd_hdr <= mac_src(1);
                when 16 => txd_hdr <= mac_src(2);
                when 17 => txd_hdr <= mac_src(3);
                when 18 => txd_hdr <= mac_src(4);
                when 19 => txd_hdr <= mac_src(5);
                when 20 => txd_hdr <= X"08"; -- eth type II
                when 21 => txd_hdr <= X"00";
                when 22 => txd_hdr <= X"45"; -- ver=x4  hdr=0x5
                when 23 => txd_hdr <= X"00"; -- diff services
                when 24 => txd_hdr <= ip_len(15 downto 8);
                when 25 => txd_hdr <= ip_len(7 downto 0);
                when 26 => txd_hdr <= tx_ip_id(15 downto 8);
                when 27 => txd_hdr <= tx_ip_id(7 downto 0);
                when 28 => txd_hdr <= X"00"; -- fragment and IP flags
                when 29 => txd_hdr <= X"00";
                when 30 => txd_hdr <= X"00"; -- Time to Live (TTL)
                when 31 => txd_hdr <= X"11"; -- Protocol
                when 32 => txd_hdr <= hdr_csum(0);
                when 33 => txd_hdr <= hdr_csum(1);
                when 34 => txd_hdr <= ip_src(0);
                when 35 => txd_hdr <= ip_src(1);
                when 36 => txd_hdr <= ip_src(2);
                when 37 => txd_hdr <= ip_src(3);
                when 38 => txd_hdr <= tx_ip_dest(31 downto 24); -- ip destination addr MSB
                when 39 => txd_hdr <= tx_ip_dest(23 downto 16);
                when 40 => txd_hdr <= tx_ip_dest(15 downto 8);
                when 41 => txd_hdr <= tx_ip_dest(7 downto 0);   -- LSB
                when 42 => txd_hdr <= tx_udp_src(15 downto 8);  -- UDP SRC port MSB
                when 43 => txd_hdr <= tx_udp_src(7 downto 0);   -- LSB
                when 44 => txd_hdr <= tx_udp_dest(15 downto 8); -- UDDP Des port MSB
                when 45 => txd_hdr <= tx_udp_dest(7 downto 0);  -- LSB
                when 46 => txd_hdr <= udp_len(15 downto 8);
                when 47 => txd_hdr <= udp_len(7 downto 0);
                when 48 => txd_hdr <= udp_csum(0);
                           app_rdy_hdr <= '1'; -- since tready is not clocked, start this one count earlier
                when 49 => txd_hdr <= udp_csum(1);
                           app_rdy_hdr <= '1';
                when others =>
                    txd_hdr <= (others => '0');
            end case;
        end process;

    eth_fcs_gen : entity work.eth_fcs_gen
    port map(
        clk     => clk,
        txd     => txd_i,
        txd_en  => tx_en,
        fcs     => fcs_gen_out
           );

end behavioral;

