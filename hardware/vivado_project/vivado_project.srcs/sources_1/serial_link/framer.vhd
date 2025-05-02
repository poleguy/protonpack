 -------------------------------------------------
-- framer.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- receive unaligned stream in parallel
-- send out the stream in parallel aligned to k characters
-- extract frame via k 28.5 character

--------------------------------------------------
-- see version control for rev info
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library work;
--library UNISIM;
--use UNISIM.vcomponents.all; -- not for lattice

entity framer is
  port
    (

      clk : in std_logic;

      -- parallel input
      data_in     : in  std_logic_vector(9 downto 0);
      valid_in    : in  std_logic;
      -- parallel output
      data_out    : out std_logic_vector(9 downto 0);
      valid_out   : out std_logic;
      aligned_out : out std_logic
      );

end framer;

architecture rtl of framer is


  signal r_data_in    : std_logic_vector(9 downto 0) := (others => '0');
  signal r1_data_in    : std_logic_vector(9 downto 1) := (others => '0');
  signal r_unlock     : std_logic                    := '0';
  signal r_unlock_cnt : unsigned(15 downto 0)        := (others => '0');

  -- default to values that don't match to prevent false lock at start
  signal r_alignment  : unsigned(3 downto 0)         := "0001";
  signal r1_alignment  : unsigned(3 downto 0)         := "0010";
  signal r2_alignment  : unsigned(3 downto 0)         := "0011";
  signal r_alignment_locked  : unsigned(3 downto 0)         := (others => '0');
  signal r_data_shift : std_logic_vector(9 downto 0) := (others => '0');
  signal r_k_char     : std_logic                    := '0';

  signal r_valid     : std_logic                    := '0';
  signal r1_valid    : std_logic                    := '0';
  signal r2_valid    : std_logic                    := '0';
  signal r2_valid_and_aligned    : std_logic                    := '0';
  signal r_data_out  : std_logic_vector(9 downto 0) := (others => '0');
--  signal r_data      : std_logic_vector(9 downto 0) := (others => '0');
  signal r_locked    : std_logic                    := '0';
  signal r1_locked   : std_logic                    := '0';

  signal r_0_match_p : std_logic := '0';
  signal r_0_match_n : std_logic := '0';
  signal r_1_match_p : std_logic := '0';
  signal r_1_match_n : std_logic := '0';
  signal r_2_match_p : std_logic := '0';
  signal r_2_match_n : std_logic := '0';
  signal r_3_match_p : std_logic := '0';
  signal r_3_match_n : std_logic := '0';
  signal r_4_match_p : std_logic := '0';
  signal r_4_match_n : std_logic := '0';
  signal r_5_match_p : std_logic := '0';
  signal r_5_match_n : std_logic := '0';
  signal r_6_match_p : std_logic := '0';
  signal r_6_match_n : std_logic := '0';
  signal r_7_match_p : std_logic := '0';
  signal r_7_match_n : std_logic := '0';
  signal r_8_match_p : std_logic := '0';
  signal r_8_match_n : std_logic := '0';
  signal r_9_match_p : std_logic := '0';
  signal r_9_match_n : std_logic := '0';

  
begin


  process(clk)
  begin
    if rising_edge(clk) then
      r_valid   <= valid_in;
      r1_valid  <= r_valid;
      r2_valid  <= r1_valid;
      r2_valid_and_aligned  <= r1_valid and r1_locked;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if (valid_in = '1') then
        r_data_in <= data_in;
      end if;
      r1_data_in(9 downto 1) <= r_data_in(9 downto 1);
    end if;
  end process;

  
  process(clk)
  begin
    if rising_edge(clk) then
      if (r_valid = '1') then
        if r_alignment_locked = x"0" then
          r_data_shift <= r_data_in(9 downto 0);
        elsif r_alignment_locked = x"1" then
          r_data_shift <= r_data_in(8 downto 0) & r1_data_in(9);
        elsif r_alignment_locked = x"2" then
          r_data_shift <= r_data_in(7 downto 0) & r1_data_in(9 downto 8);
        elsif r_alignment_locked = x"3" then      
          r_data_shift <= r_data_in(6 downto 0) & r1_data_in(9 downto 7);
        elsif r_alignment_locked = x"4" then      
          r_data_shift <= r_data_in(5 downto 0) & r1_data_in(9 downto 6);
        elsif r_alignment_locked = x"5" then      
          r_data_shift <= r_data_in(4 downto 0) & r1_data_in(9 downto 5);
        elsif r_alignment_locked = x"6" then    
          r_data_shift <= r_data_in(3 downto 0) & r1_data_in(9 downto 4);
        elsif r_alignment_locked = x"7" then      
          r_data_shift <= r_data_in(2 downto 0) & r1_data_in(9 downto 3);
        elsif r_alignment_locked = x"8" then      
          r_data_shift <= r_data_in(1 downto 0) & r1_data_in(9 downto 2);
        elsif r_alignment_locked = x"9" then
          r_data_shift <= r_data_in(0) & r1_data_in(9 downto 1);
        end if;
      end if;
      
    end if;
  end process;

  -- framer
  -- feed bits into 8b10b framer
  -- look for k character match
  -- optional look for n additional k character match(es) at same alignment
  -- declare lock at that alignment (if already locked, just move alignment)
  -- unlock if 8b10b reports a code error (or n code errors? in a row?)

  -- frame on 10bit, 8b10b encoded data at input
  -- using k28.5 character
  --
  -- should this be fast, or small?
  -- fast dumb framer. no error tolerance.

  -- todo: this could use feedback from the 8b10b decoder...

  process(clk)
  begin
    if rising_edge(clk) then
      if (r1_valid = '1') then
      if (r_0_match_n = '1') or
         (r_0_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"0";
      elsif (r_1_match_n = '1') or
         (r_1_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"1";
      elsif (r_2_match_n = '1') or
         (r_2_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"2";
      elsif (r_3_match_n = '1') or
         (r_3_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"3";
      elsif (r_4_match_n = '1') or
         (r_4_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"4";
      elsif (r_5_match_n = '1') or
         (r_5_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"5";
      elsif (r_6_match_n = '1') or
         (r_6_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"6";
      elsif (r_7_match_n = '1') or
         (r_7_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"7";
      elsif (r_8_match_n = '1') or
         (r_8_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"8";
      elsif (r_9_match_n = '1') or
         (r_9_match_p = '1') then 
        r_k_char <= '1';
        r_alignment <= x"9";
      else
        r_k_char <= '0';
      end if;
      end if;      
    end if;
  end process;


  -- 
  process(clk)
  begin
    if rising_edge(clk) then
      if (valid_in = '1') then
        r_0_match_n <= '0';
        if (data_in(9 downto 0) = "0101111100") then
          r_0_match_n <= '1';
        end if;
        r_0_match_p <= '0';
        if (data_in(9 downto 0) = "1010000011") then
          r_0_match_p <= '1';
        end if;

        -- k28.5 input is "10111100"
        r_1_match_n <= '0';
        if (data_in(8 downto 0) & r_data_in(9) = "0101111100") then
          r_1_match_n <= '1';
        end if;
        r_1_match_p <= '0';
        if (data_in(8 downto 0) & r_data_in(9)  = "1010000011") then 
          r_1_match_p <= '1';
        end if;
        
        r_2_match_n <= '0';
        if (data_in(7 downto 0) & r_data_in(9 downto 8) = "0101111100") then
          r_2_match_n <= '1';
        end if;

        r_2_match_p <= '0';
        if (data_in(7 downto 0) & r_data_in(9 downto 8)  = "1010000011") then
          r_2_match_p <= '1';
        end if;
        
        r_3_match_n <= '0';
        if (data_in(6 downto 0) & r_data_in(9 downto 7) = "0101111100") then
          r_3_match_n <= '1';
        end if;
        r_3_match_p <= '0';
        if (data_in(6 downto 0) & r_data_in(9 downto 7)  = "1010000011") then
          r_3_match_p <= '1';
        end if;
        
        r_4_match_n <= '0';
        if (data_in(5 downto 0) & r_data_in(9 downto 6) = "0101111100") then
          r_4_match_n <= '1';
        end if;    
        r_4_match_p <= '0';
        if (data_in(5 downto 0) & r_data_in(9 downto 6)  = "1010000011") then
          r_4_match_p <= '1';
        end if;
        
        r_5_match_n <= '0';
        if (data_in(4 downto 0) & r_data_in(9 downto 5) = "0101111100") then
          r_5_match_n <= '1';
        end if;      
        r_5_match_p <= '0';
        if (data_in(4 downto 0) & r_data_in(9 downto 5)  = "1010000011") then
          r_5_match_p <= '1';
        end if;
        
        r_6_match_n <= '0';
        if (data_in(3 downto 0) & r_data_in(9 downto 4) = "0101111100") then
          r_6_match_n <= '1';
        end if;
        r_6_match_p <= '0';
        if (data_in(3 downto 0) & r_data_in(9 downto 4)  = "1010000011") then
          r_6_match_p <= '1';
        end if;
        
        r_7_match_n <= '0';
        if (data_in(2 downto 0) & r_data_in(9 downto 3) = "0101111100") then
          r_7_match_n <= '1';
        end if;
        r_7_match_p <= '0';
        if (data_in(2 downto 0) & r_data_in(9 downto 3)  = "1010000011") then
          r_7_match_p <= '1';
        end if;

        r_8_match_n <= '0';
        if (data_in(1 downto 0) & r_data_in(9 downto 2) = "0101111100") then
          r_8_match_n <= '1';
        end if;
        r_8_match_p <= '0';
        if (data_in(1 downto 0) & r_data_in(9 downto 2)  = "1010000011") then
          r_8_match_p <= '1';
        end if;
        r_9_match_n <= '0';
        if (data_in(0) & r_data_in(9 downto 1) = "0101111100") then
          r_9_match_n <= '1';
        end if;
        r_9_match_p <= '0';
        if (data_in(0) & r_data_in(9 downto 1)  = "1010000011") then
          r_9_match_p <= '1';
        end if;
      end if;      
    end if;
  end process;

  

  -- three in a row to lock
  process(clk)
  begin
    if rising_edge(clk) then
      if (r1_valid = '1') then
      
      if (r_k_char = '1') then
        r1_alignment <= r_alignment;
        r2_alignment <= r1_alignment;
      end if;
      end if;      
      
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if (r2_valid = '1') then
      if (r_alignment = r1_alignment) and
         (r1_alignment = r2_alignment) then  
        r_locked <= '1';
        -- todo: flag changes in alignment as errors?
        r_alignment_locked <= r_alignment; -- use new alignment
      elsif (r_unlock = '1') then
        --once aligned, stay in alignment unless unlocked by unlock detector
        r_locked <= '0';
      end if;
      end if;
    end if;
  end process;

  
-- unlock detector
  process(clk)
  begin
    if rising_edge(clk) then
      if (r2_valid = '1') then
        if (r_k_char = '1') then
          -- if we see a k character, reset the count
          r_unlock_cnt <= x"0000";  --we won't be able to handle packets longer than 64k
          r_unlock     <= '0';
        elsif (r_unlock_cnt = x"FFFF") then
          -- if we saw no k characters, force unlock
          r_unlock_cnt <= r_unlock_cnt + 1;
          r_unlock     <= '1';
        else
          -- count non k characters
          r_unlock_cnt <= r_unlock_cnt + 1;
          r_unlock     <= '0';
        end if;
      end if;
    end if;
  end process;

  -- hold output data
  process(clk)
  begin
    if rising_edge(clk) then
      if (r1_valid = '1') then
        r_data_out <= r_data_shift;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      r1_locked   <= r_locked;
    end if;
  end process;

  data_out  <= r_data_out;
  valid_out <= r2_valid_and_aligned;


  aligned_out <= r1_locked;
  -- once in sync
  -- feed 10b chunks into 8b10b

  -- https://opencores.org/projects/8b10b_encdec
  -- this is gpl is that okay? seems not.
  -- will have to roll my own or use lattice/xilinx ip.
  -- yuck
  


end architecture rtl;
