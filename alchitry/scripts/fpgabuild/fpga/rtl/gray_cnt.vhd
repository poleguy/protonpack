----------------------------------------
-- Function    : Code Gray counter.
----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
-- 
-- Description: 
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_unsigned.all;
    use ieee.std_logic_arith.all;
    
entity gray_cnt is
    generic (
        COUNTER_WIDTH :integer := 4
    );
    port (                                  --'Gray' code count output.
        GrayCount_out :out std_logic_vector (COUNTER_WIDTH-1 downto 0);  
        BinCount_out  :out std_logic_vector (COUNTER_WIDTH-1 downto 0);
        Enable_in     :in  std_logic;       -- Count enable.
        Clear_in      :in  std_logic;       -- Count reset.
        clk           :in  std_logic        -- Input clock
    );
end entity;

architecture rtl of gray_cnt is
    signal BinaryCount :std_logic_vector (COUNTER_WIDTH-1 downto 0):= (others=>'0');
    signal GrayCount : std_logic_vector(COUNTER_WIDTH-1 downto 0);  
begin

    -- Register to FF for good practice output, in case syncronizer outside of module
    process(clk)begin
        if rising_edge(clk)then
            GrayCount_out <= GrayCount;
        end if;
    end process;

    GrayCount   <= (BinaryCount(COUNTER_WIDTH-1) & 
                     (BinaryCount(COUNTER_WIDTH-2 downto 0) xor 
                      BinaryCount(COUNTER_WIDTH-1 downto 1)));

    BinCount_out <= BinaryCount;

    process (clk) begin
        if (rising_edge(clk)) then
            if (Clear_in = '1') then
                BinaryCount   <= (others=>'0');  
            elsif (Enable_in = '1') then
                BinaryCount   <= BinaryCount + 1;
            end if;
        end if;
    end process;
    
end architecture;
