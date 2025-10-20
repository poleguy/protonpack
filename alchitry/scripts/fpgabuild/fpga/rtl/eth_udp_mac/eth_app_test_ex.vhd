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

entity eth_app_test is
    port 
    (               
        rst                 : in std_logic;
        clk                 : in std_logic;

        cfg_mac_des_addr    : in std_logic_vector(47 downto 0);
        cfg_ip_des_addr     : in std_logic_vector(31 downto 0);
        cfg_src_port        : in std_logic_vector(15 downto 0);
        cfg_des_port        : in std_logic_vector(15 downto 0);
        cfg_pkt_wait_clks   : in std_logic_vector(31 downto 0);
        cfg_pkt_bytes       : in std_logic_vector(15 downto 0);
        
        tx_mac_dest         : out std_logic_vector(47 downto 0);
        tx_ip_id            : out std_logic_vector(15 downto 0);
        tx_payload_len      : out std_logic_vector(15 downto 0);
        tx_ip_dest          : out std_logic_vector(31 downto 0);
        tx_udp_src          : out std_logic_vector(15 downto 0);
        tx_udp_dest         : out std_logic_vector(15 downto 0);
        
        m_axis_tdata        : out std_logic_vector(7 downto 0);
        m_axis_tvalid       : out std_logic;
        m_axis_tlast        : out std_logic;
        m_axis_tready       : in std_logic
    );
end eth_app_test;


architecture behavioral of eth_app_test is

    constant MAX_UDP_PAYLOAD_BYTES : integer := 1472;

    signal wait_cnt          : std_logic_vector(31 downto 0);
    signal byte_cnt          : std_logic_vector(31 downto 0);
    signal btt_held          : std_logic_vector(15 downto 0);
    signal pkt_cnt           : std_logic_vector(31 downto 0);
    signal pattern           : std_logic_vector(7 downto 0);

    type state_type is (IDLE,
                        DATA_CNT1,
                        DATA_CNT2,
                        DATA_CNT3,
                        DATA,
                        DATA_LAST
                        );
    signal state : state_type;      

    
begin

        process(clk) begin
            if rising_edge(clk) then
                if (rst = '1') then
                    tx_mac_dest    <= (others => '0');
                    tx_ip_id       <= (others => '0');
                    tx_payload_len <= (others => '0');
                    tx_ip_dest     <= (others => '0');
                    tx_udp_src     <= (others => '0');
                    tx_udp_dest    <= (others => '0');
                    m_axis_tvalid  <= '0';
                    m_axis_tlast   <= '0';
                    m_axis_tdata   <= (others => '0');
                    wait_cnt       <= (others => '0');
                    pkt_cnt        <= (3=>'1',others => '0');
                    state          <= IDLE;
                else 
                    case(state)is

                        when IDLE =>
                            byte_cnt <= (others => '0');
                            if(wait_cnt > cfg_pkt_wait_clks)then
                                tx_mac_dest     <= cfg_mac_des_addr;
                                tx_ip_id        <= pkt_cnt(15 downto 0);
                                tx_payload_len  <= cfg_pkt_bytes;
                                tx_ip_dest      <= cfg_ip_des_addr;
                                tx_udp_src      <= cfg_src_port;
                                tx_udp_dest     <= cfg_des_port;
                                btt_held        <= cfg_pkt_bytes;
                                m_axis_tvalid   <= '1';
                                m_axis_tdata    <= pkt_cnt(31 downto 24);
                                pattern         <= pkt_cnt(7 downto 0);
                                byte_cnt        <= byte_cnt + 1;
                                wait_cnt        <= (others => '0');
                                state           <= DATA_CNT1;
                            else
                                wait_cnt        <= wait_cnt + 1;
                            end if;

                        when DATA_CNT1 =>
                            if(m_axis_tready='1')then
                                byte_cnt     <= byte_cnt + 1;
                                m_axis_tdata <= pkt_cnt(23 downto 16);
                                state        <= DATA_CNT2;
                            end if;

                        when DATA_CNT2 =>
                            if(m_axis_tready='1')then
                                byte_cnt     <= byte_cnt + 1;
                                m_axis_tdata <= pkt_cnt(15 downto 8);
                                state        <= DATA_CNT3;
                            end if;

                        when DATA_CNT3 =>
                            if(m_axis_tready='1')then
                                byte_cnt     <= byte_cnt + 1;
                                m_axis_tdata <= pkt_cnt(7 downto 0);
                                state        <= DATA;
                            end if;
                            
                        when DATA =>
                            if(m_axis_tready='1')then
                                byte_cnt     <= byte_cnt + 1;
                                m_axis_tdata <= pattern;
                                pattern      <= pattern + 1;
                                if(byte_cnt+1>=btt_held)then
                                    m_axis_tlast <= '1';
                                    state <= DATA_LAST;
                                end if;
                            end if;

                         when DATA_LAST =>
                             if(m_axis_tready='1')then
                                 m_axis_tlast <= '0';
                                 m_axis_tvalid <= '0';
                                 pkt_cnt <= pkt_cnt + 1;
                                 state <= IDLE;
                             end if;


                    end case;
                end if;
            end if;
        end process;
end behavioral;

