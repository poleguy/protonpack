----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
-- 
-- Description:  A wrapper file for calculating ethernet frame check sequence
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------

----- 802.3 CRC-32 FCS Calculation -------
-- To reproduce appropriate CRC-32 in this example frame
-- 1) load 8-bit txd data bit reversed  bit7 becomes bit0, etc
-- 2) Run with en set starting from first MAC address beat through last UDP byte before checksum
-- 3) Next clock is valid crc32 module output BUT,
-- 4a) Need to invert (not) the crc-32 output
-- 4b) Need to reverse the 32 bits (i.e bit 31 becomes but 0, etc)
-- 4c) Swap bytes from big end to little end depending how look at it
-------------------------------------------

library ieee; 
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity eth_fcs_gen is 
    port ( 
        clk     : in std_logic;
        txd     : in std_logic_vector (7 downto 0);  -- as put on the gmii interface
        txd_en  : in std_logic;                      -- as used on the gmii interface
        fcs     : out std_logic_vector(31 downto 0)  -- store entire parallel value on first fcs clock 
                                                     --   (aka 1 clock after last frame pauload bytes) 
                                                     -- fcs is in little-endian so send out MSByte fcs(7:0) first
                                                     -- followed by fcs(15:8) on next clock
    );
end eth_fcs_gen;

architecture arch of eth_fcs_gen is	

    signal rst          : std_logic;
    signal txd_en_cnt   : std_logic_vector(2 downto 0) := (others => '0');
    signal crc_in       : std_logic_vector(7 downto 0);
    signal crc_out      : std_logic_vector(31 downto 0);
    signal crc_en       : std_logic;

begin	

    -- the actual value put in the ethernet frame is the not crc-32 value so the receiver
    -- can calculate the crc-32 and add to the receivec fcs and get 0
    -- fcs <= not crc_out;
    gen_fcs_out : for ii in 0 to 31 generate
        fcs(ii) <= not(crc_out(31-ii));
    end generate;

    -- txd_en will be continuous for a frame transmission, so whenever it goes low 
    -- the frame is over and can reset
    rst <= not txd_en;

    -- reverse the bit order going into CRC-32 calcualtor
    -- relates to the fact that msb txd(7) is equavelent to the first bit transmitted
    -- so it really should be "bit 0" in location (0) from a serial perspective
    gen_crc_in : for ii in 0 to 7 generate
        crc_in(ii) <= txd(7-ii);
    end generate;

    -- start calculating CRC after 8-byte preamble/SOFD and starting with MAC address
    process(clk)begin
        if rising_edge(clk) then
            if(txd_en='0')then
                txd_en_cnt <= (others => '0');
                crc_en <= '0';
            elsif(txd_en_cnt="111")then 
                crc_en <= '1';
            else
                crc_en <= '0';
                txd_en_cnt <= txd_en_cnt + '1';
            end if;
        end if;
    end process;

    crc_8in : entity work.eth_crc32_8in
    port map(
        clk                   => clk,
        rst                   => rst,
        data_in               => crc_in,
        crc_en                => crc_en,
        crc_out               => crc_out
    );	

end;
