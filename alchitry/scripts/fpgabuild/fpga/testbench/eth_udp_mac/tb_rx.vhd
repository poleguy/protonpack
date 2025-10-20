-- Ming Fong
-- Shure inc.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use STD.textio.all;             -- file i/0
USE std.env.all;                -- for stop()
use ieee.std_logic_unsigned.all;

use work.eth_test_pkg.all;

entity tb_rx is
    generic(
        TEST_MAC    : integer := 0;
        TEST_REG_RD : integer := 0;
        TEST_REG_WR : integer := 0
    );
end tb_rx;

architecture arch of tb_rx is

    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal rxd_en        : std_logic := '0';
    signal rxd           : std_logic_vector(7 downto 0) := (others => '0');

    signal tdata          : std_logic_vector(7 downto 0);
    signal tvalid         : std_logic;
    signal tlast          : std_logic;
    signal tready         : std_logic;
    signal tready_mac     : std_logic;
    signal tready_reg     : std_logic;

    signal result_trig : std_logic;

    signal reg_tx_mac_dest    : std_logic_vector(47 downto 0);
    signal reg_tx_ip_id       : std_logic_vector(15 downto 0);
    signal reg_tx_payload_len : std_logic_vector(15 downto 0);
    signal reg_tx_ip_dest     : std_logic_vector(31 downto 0);
    signal reg_tx_udp_src     : std_logic_vector(15 downto 0);
    signal reg_tx_udp_dest    : std_logic_vector(15 downto 0);

    signal reg_tx_tdata       : std_logic_vector(7 downto 0);
    signal reg_tx_tvalid      : std_logic;
    signal reg_tx_tlast       : std_logic;
    signal reg_tx_tready      : std_logic;

    signal reg_data_rd     : std_logic_vector(31 downto 0);
    signal reg_data_wr     : std_logic_vector(31 downto 0);
    signal reg_addr        : std_logic_vector(23 downto 0);
    signal reg_re          : std_logic;
    signal reg_wr          : std_logic;

    signal mac_gmii_en   : std_logic;
    signal done          : std_logic;

    signal fcs_err       : std_logic;
    signal frame_len_err : std_logic;

    signal rx_mac_src     : std_logic_vector(47 downto 0);
    signal rx_ip_id       : std_logic_vector(15 downto 0);
    signal rx_payload_len : std_logic_vector(15 downto 0);
    signal rx_ip_src      : std_logic_vector(31 downto 0);
    signal rx_udp_dest    : std_logic_vector(15 downto 0);
    signal rx_udp_src     : std_logic_vector(15 downto 0);

    signal mac_dest  : std_logic_vector(47 downto 0);
    signal mac_src   : std_logic_vector(47 downto 0);
    signal ip_src    : std_logic_vector(31 downto 0);
    signal ip_dest   : std_logic_vector(31 downto 0);
    signal udp_src   : std_logic_vector(15 downto 0);
    signal udp_dest  : std_logic_vector(15 downto 0);
    signal pkt_bytes : std_logic_vector(15 downto 0);

    shared variable pkt       : t_pkt;
    shared variable test_pass : boolean;
    
begin

    -- Hardcode header fields
    mac_dest  <= X"5A0001020304";
    mac_src   <= X"5A000A0B0C0D";
    ip_src    <= X"11223344";
    ip_dest   <= X"AABBCCDD";
    udp_src   <= X"1234";
    udp_dest  <= X"ABCD";
    pkt_bytes <= X"0012";

    -- Clock process
    process begin
        wait for 4 ns;
        clk <= not clk;
    end process;

    -- Reset process
    process begin
        rst<='1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst<='0';
        wait;
    end process;
        
    -- Procedures for MAC RX test
    g_TEST_MAC : if TEST_MAC = 1 generate
    
        tready      <= tready_mac;
        result_trig <= tvalid;
        
        process begin
            wait until rst = '0';
            wait until rising_edge(clk);
            encode_gmii(clk, mac_gmii_en, mac_dest, mac_src, ip_src, ip_dest, udp_src, udp_dest, pkt_bytes, rxd_en, rxd, done, "", pkt);
        end process;

        process begin
            decode_axis(clk, pkt, tdata, tvalid, tlast, tready_mac, rx_mac_src, rx_ip_id, rx_payload_len, rx_ip_src, rx_udp_dest, rx_udp_src, test_pass);
        end process;

        process begin
            wait until falling_edge(rxd_en);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            stop(0);
        end process;
    end generate g_TEST_MAC;

    -- Procedures for register read test
    g_TEST_REG_RD : if TEST_REG_RD = 1 generate
    
        tready      <= tready_reg;
        result_trig <= reg_tx_tlast;
        
        process begin
            wait until rst = '0';
            wait until rising_edge(clk);
            encode_gmii(clk, mac_gmii_en, mac_dest, mac_src, ip_src, ip_dest, udp_src, udp_dest, pkt_bytes, rxd_en, rxd, done, "reg_rd", pkt);
        end process;

        process begin
            decode_reg(clk, tdata, tvalid, tlast, tready, reg_data_rd, reg_data_wr, reg_addr, reg_re, reg_wr, reg_tx_tdata, reg_tx_tvalid, reg_tx_tlast, reg_tx_tready, test_pass);
        end process;

        process begin
            wait until falling_edge(reg_tx_tlast);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            stop(0);
        end process;
    end generate g_TEST_REG_RD;

    -- Procedures for register write test
    g_TEST_REG_WR : if TEST_REG_WR = 1 generate
    
        tready      <= tready_reg;
        result_trig <= reg_wr;
    
        process begin
            wait until rst = '0';
            wait until rising_edge(clk);
            encode_gmii(clk, mac_gmii_en, mac_dest, mac_src, ip_src, ip_dest, udp_src, udp_dest, pkt_bytes, rxd_en, rxd, done, "reg_wr", pkt);
        end process;

        process begin
            decode_reg(clk, tdata, tvalid, tlast, tready, reg_data_rd, reg_data_wr, reg_addr, reg_re, reg_wr, reg_tx_tdata, reg_tx_tvalid, reg_tx_tlast, reg_tx_tready, test_pass);
        end process;

        process begin
            wait until falling_edge(reg_wr);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            stop(0);
        end process;
    end generate g_TEST_REG_WR;

    -- GMII enable process
    process begin
        mac_gmii_en <= '0';
        wait until rst = '0';
        mac_gmii_en <= '1';
        wait until done = '1';
        mac_gmii_en <= '0';
    end process;

    -- Timeout process
    process begin
        wait for 1 ms;
        LOG("timeout stop");
        stop(0);
    end process;
    
    -- Ethernet RX MAC
    eth_udp_mac_rx : entity work.eth_udp_mac_rx
    port map(
        rst                   => rst,
        clk                   => clk,
        mac_gmii_en           => mac_gmii_en,

        cfg_this_dev_mac_addr => X"5A0001020304",
        cfg_this_dev_ip_addr  => X"AABBCCDD",

        fcs_err               => fcs_err,
        frame_len_err         => frame_len_err,

        rx_mac_src            => rx_mac_src,
        rx_ip_id              => rx_ip_id,
        rx_payload_len        => rx_payload_len,
        rx_ip_src             => rx_ip_src,
        rx_udp_dest           => rx_udp_dest,
        rx_udp_src            => rx_udp_src,

        m_axis_tdata          => tdata,
        m_axis_tvalid         => tvalid,
        m_axis_tlast          => tlast,
        m_axis_tready         => tready,

        rxd_en                => rxd_en,
        rxd                   => rxd
        );

    -- Ethernet register handler
    eth_reg_handler : entity work.eth_reg_handler
    port map(
        rst            => rst,
        clk            => clk,

        rx_mac_src     => rx_mac_src,
        rx_ip_id       => rx_ip_id,
        rx_payload_len => rx_payload_len,
        rx_ip_src      => rx_ip_src,
        rx_udp_dest    => rx_udp_dest,
        rx_udp_src     => rx_udp_src,

        s_axis_tdata   => tdata,
        s_axis_tvalid  => tvalid,
        s_axis_tlast   => tlast,
        s_axis_tready  => tready_reg,

        tx_mac_dest    => reg_tx_mac_dest,
        tx_ip_id       => reg_tx_ip_id,
        tx_payload_len => reg_tx_payload_len,
        tx_ip_dest     => reg_tx_ip_dest,
        tx_udp_src     => reg_tx_udp_src,
        tx_udp_dest    => reg_tx_udp_dest,

        m_axis_tdata   => reg_tx_tdata,
        m_axis_tvalid  => reg_tx_tvalid,
        m_axis_tlast   => reg_tx_tlast,
        m_axis_tready  => reg_tx_tready,

        reg_data_rd    => reg_data_rd,
        reg_data_wr    => reg_data_wr,
        reg_addr       => reg_addr,
        reg_re         => reg_re,
        reg_wr         => reg_wr
        );
        
    -- Testbench results text file
    write_results : process is
      file test_out : text open write_mode is "results.txt";
      variable row  : line;
    begin
        wait until falling_edge(result_trig);
        wait until rising_edge(clk);
        if (test_pass = True) then
            write(row, string'("Pass"));
            writeline(test_out, row);
        else
            write(row, string'("Fail"));
            writeline(test_out, row);
        end if;
    end process;
end;
