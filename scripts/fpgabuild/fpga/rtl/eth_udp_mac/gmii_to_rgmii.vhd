----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
--
-- Description: Convert rgmii signals to mgii signals
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

entity gmii_to_rgmii is
    port
    (
        clk             : in  std_logic; --125MHz

        gmii_txd_en     : in  std_logic;
        gmii_tx_er      : in  std_logic;
        gmii_txd        : in  std_logic_vector(7 downto 0);

        rgmii_txd       : out std_logic_vector(3 downto 0);
        rgmii_tx_ctl    : out std_logic;
        rgmii_txc       : out std_logic

    );
end gmii_to_rgmii;


architecture behavioral of gmii_to_rgmii is

    signal gmii_txd_d        : std_logic_vector(7 downto 0);
    signal gmii_txd_en_d     : std_logic := '0';
    signal gmii_tx_er_d     : std_logic := '0';

    attribute mark_debug : string;
  --  attribute mark_debug of txd_cnt     : signal is "true";

begin

        -- register txd_en and 
        process(clk) begin
            if rising_edge(clk) then
                gmii_txd_en_d <= gmii_txd_en;
                gmii_txd_d    <= gmii_txd;
                gmii_tx_er_d  <= gmii_tx_er;
            end if;
        end process;
        
       oddr_rgmii_txd_gen : for ii in 0 to 3 generate
           oddr_rgmii_txd : ODDR
           generic map(
              DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
              INIT         => '0',   -- Initial value for Q port ('1' or '0')
              SRTYPE       => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
           port map (
              Q  => rgmii_txd(ii),    -- 1-bit DDR output
              C  => clk,              -- 1-bit clock input
              CE => '1',              -- 1-bit clock enable input
              D1 => gmii_txd_d(ii),   -- 1-bit data input (positive edge)
              D2 => gmii_txd_d(ii+4), -- 1-bit data input (negative edge)
              R  => '0',              -- 1-bit reset input
              S  => '0'               -- 1-bit set input
           );
        end generate;

       -- ran example design for xilinx gmii_to_rgmii (only avail for zynq)
       -- clock also goes through an oddr then OBUF
       oddr_rgmii_txc : ODDR
       generic map(
          DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
          INIT         => '0',   -- Initial value for Q port ('1' or '0')
          SRTYPE       => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
       port map (
          Q  => rgmii_txc, -- 1-bit DDR output
          C  => clk,       -- 1-bit clock input
          CE => '1',       -- 1-bit clock enable input
          D1 => '1',       -- 1-bit data input (positive edge)
          D2 => '0',       -- 1-bit data input (negative edge)
          R  => '0',       -- 1-bit reset input
          S  => '0'        -- 1-bit set input
       );

       -- tx_en set on pos edge
       -- tx_err on fall edge
       oddr_rgmii_tx_ctl : ODDR
       generic map(
          DDR_CLK_EDGE => "SAME_EDGE", -- "OPPOSITE_EDGE" or "SAME_EDGE"
          INIT         => '0',   -- Initial value for Q port ('1' or '0')
          SRTYPE       => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
       port map (
          Q  => rgmii_tx_ctl,  -- 1-bit DDR output
          C  => clk,           -- 1-bit clock input
          CE => '1',           -- 1-bit clock enable input
          D1 => gmii_txd_en_d, -- 1-bit data input (positive edge)
          D2 => gmii_tx_er_d,  -- 1-bit data input (negative edge)
          R  => '0',           -- 1-bit reset input
          S  => '0'            -- 1-bit set input
       );

end behavioral;

