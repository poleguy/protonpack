-- Alex Stezskal
-- Shure inc.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use STD.textio.all;             -- file i/0
USE std.env.all;                -- for stop()
use ieee.std_logic_unsigned.all;

use work.eth_test_pkg.all;

entity tb_tx is
end tb_tx;

architecture arch of tb_tx is

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal txd_en   : std_logic := '0';
    signal txd      : std_logic_vector(7 downto 0) := (others => '0');

    signal tdata    : std_logic_vector(7 downto 0);
    signal tvalid   : std_logic;
    signal tlast    : std_logic;
    signal tready   : std_logic;

    signal tx_mac_dest    : std_logic_vector(47 downto 0);
    signal tx_ip_id       : std_logic_vector(15 downto 0);
    signal tx_payload_len : std_logic_vector(15 downto 0);
    signal tx_ip_dest     : std_logic_vector(31 downto 0);
    signal tx_udp_src     : std_logic_vector(15 downto 0);
    signal tx_udp_dest    : std_logic_vector(15 downto 0);

    shared variable errors : integer := 0;

begin

    process begin
        wait for 4 ns;
        clk <= not clk;
    end process;

    process begin
        rst<='1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst<='0';
        wait;
    end process;

    process is
        variable pkt : t_pkt;
    begin
        decode_gmii(clk, txd_en, txd, True, pkt, errors);
        display_pkt(pkt);
    end process;

    process 
    begin
        wait until falling_edge(txd_en);
        wait until falling_edge(txd_en);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        LOG("errors = "&to_string(errors));
        stop(0);
    end process;

    process
    begin
        wait for 1 ms;
        LOG("timeout stop");
        stop(0);
    end process;


   eth_udp_mac_tx : entity work.eth_udp_mac_tx
   port map(
        rst                 => rst,
        clk                 => clk,
        mac_gmii_en         => '1',

        cfg_src_mac_addr    => X"5A0001020304",
        cfg_ip_src_addr     => X"AABBCCDD",

        tx_mac_dest         => tx_mac_dest,
        tx_ip_id            => tx_ip_id,
        tx_payload_len      => tx_payload_len,
        tx_ip_dest          => tx_ip_dest,
        tx_udp_src          => tx_udp_src,
        tx_udp_dest         => tx_udp_dest,
        
        s_axis_tdata        => tdata,
        s_axis_tvalid       => tvalid,
        s_axis_tlast        => tlast, 
        s_axis_tready       => tready,

        txd_en              => txd_en,
        txd                 => txd
       );

   eth_app_test : entity work.eth_app_test
   port map(
        rst                 => rst,
        clk                 => clk,
        cfg_mac_des_addr    => X"DA0001020304",
        cfg_ip_des_addr     => X"10203040",
        cfg_src_port        => X"0005",
        cfg_des_port        => X"000D",
        cfg_pkt_wait_clks   => X"00000010",
        cfg_pkt_bytes       => X"0040",

        tx_mac_dest         => tx_mac_dest,
        tx_ip_id            => tx_ip_id,
        tx_payload_len      => tx_payload_len,
        tx_ip_dest          => tx_ip_dest,
        tx_udp_src          => tx_udp_src,
        tx_udp_dest         => tx_udp_dest,
        
        m_axis_tdata        => tdata,
        m_axis_tvalid       => tvalid,
        m_axis_tlast        => tlast, 
        m_axis_tready       => tready
       );

end;
