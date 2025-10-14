-------------------------------------------------
-- gt_unpack_telemetry.vhd
--------------------------------------------------
--
-- Copyright © 2021 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
-- expects byte aligned 32bit data
--
-- pulls out the 11 byte payload and passes it along unmodified.
--
--------------------------------------------------
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

entity gt_unpack_telemetry is
  generic (
    g_debug     : std_logic             := '0';
    g_match_cnt : unsigned(19 downto 0) := x"4ffff";
    -- turn on led after data is good for this number of valid periods
    -- valid period of 1.6 usec means 500msec is about 4ffff

    g_timeout_cnt : unsigned(15 downto 0) := x"ffff"
   -- timeout to turn off led if no valids are seen for a short period
    );
  port
    (

      clk_128M       : in  std_logic;  -- clock from gt
      rst_128M       : in  std_logic;  -- to reset pll
      -- will be multiplied up to generate
      -- 1024 mbit data stream
      -- 512 MHz clock for DDR output
      -- 256 MHz clock for data processing at 10bit or 8bit with valid 
      -- GT Transceiver input at 32MHz (treated async to clk_128M/clk_256M)
      gt_clk         : in  std_logic;
      gt_data        : in  std_logic_vector(31 downto 0);
      gt_data_is_k   : in  std_logic_vector(3 downto 0);
      clk_256M_out   : out std_logic;
      pll_locked_out : out std_logic;
      okay_led_out   : out std_logic;
      cnt_led_out    : out std_logic;
      data_out       : out std_logic_vector(87 downto 0);
      valid_out      : out std_logic
      );

end gt_unpack_telemetry;

architecture rtl of gt_unpack_telemetry is

  attribute ASYNC_REG : string;
  signal clk_256M : std_logic;



  -- set this longer for a longer test
  --constant c_test_len : integer := 2000;


  signal r_data_E : unsigned(31 downto 0) := (others => '0');
  signal r_data_F : unsigned(31 downto 0) := (others => '0');
  -- pack
--  signal r_valid_in : std_logic                     := '0';
--  signal r_data_in  : std_logic_vector(55 downto 0) := (others => '0');

  -- dec
  signal r_valid      : std_logic_vector(3 downto 0)  := (others => '0');
  signal r_valid_dec  : std_logic                     := '0';
--  signal rdisp_dec    : std_logic;
  -- signal k_dec_out    : std_logic;
  signal r_data       : std_logic_vector(31 downto 0) := (others => '0');
  signal r_data_is_k  : std_logic_vector(3 downto 0)  := (others => '0');
  signal r_data_dec   : std_logic_vector(7 downto 0)  := (others => '0');
  signal r_data_dec_k : std_logic                     := '0';



  -- unpack
  signal valid_unpack_out : std_logic;
  signal data_unpack_out  : std_logic_vector(87 downto 0);


  -- check
  signal r_data_match  : std_logic             := '0';
  signal r_timeout_cnt : unsigned(15 downto 0) := x"0000";
  signal r_match_cnt   : unsigned(19 downto 0) := x"00000";

  signal r_okay_led_out : std_logic := '0';

  signal pll_locked : std_logic;


--  signal r_byte_cnt : unsigned(1 downto 0) := (others => '0');

  signal clk_128M_buf : std_logic;

  signal r_gt_clk        : std_logic                     := '0';
  signal r1_gt_clk       : std_logic                     := '0';
  signal r2_gt_clk       : std_logic                     := '0';
  signal r_gt_data       : std_logic_vector(31 downto 0) := x"00000000";
  signal r_gt_data_is_k  : std_logic_vector(3 downto 0)  := "0000";
  signal r_gt_data_valid : std_logic                     := '0';

  attribute ASYNC_REG of r_gt_clk : signal is "TRUE"; -- meta
  attribute ASYNC_REG of r1_gt_clk : signal is "TRUE"; -- sync

  
begin

  mmcm_128M_256M_1 : entity work.mmcm_128M_256M
    port map (
      clk_in1  => clk_128M,
      clk_out1 => clk_128M_buf,
      clk_out2 => clk_256M,
      reset    => rst_128M,
      locked   => pll_locked);

--pll_locked <= '1';


-- expecting 50% ones if the data is good.
-- so we will get an average of 5 ones every valid
-- each valid comes at 102.4 Mhz
-- so 2**28 bits should give a 1/2 second toggle
--  cnt_led_out <= r_cnt(27);
  cnt_led_out <= '0';

---------------------------------------------------------------------------------------------


  -- note, clkout0 from the clock recovery is driving gt_data and gt_data_is_k
  -- at 25.6 MHz... it's not clear why it wasn't being timed in 2018.2
  -- but now in 2025.1 it is being timed and failing timing.
  -- but we are treating it asynchronously, so it is added as an async clock
  -- group. Be careful therefore to treat all the signals asynchronously.
  
    
  -- reclock in to 256M domain
  -- because 128M domain is asynchronous and might not be fast enough
  proc_reclock : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      r_gt_clk  <= gt_clk;
      r1_gt_clk <= r_gt_clk;
      r2_gt_clk <= r1_gt_clk;

      -- rising edge of slow clock
      if (r2_gt_clk = '0' and r1_gt_clk = '1') then
        r_gt_data       <= gt_data;
        r_gt_data_is_k  <= gt_data_is_k;
        r_gt_data_valid <= '1';
      else
        r_gt_data_valid <= '0';
      end if;
    end if;
  end process;


--  cycle through the 4 bytes of input data

  -- count rising edges in input stream
--  proc_byte_cnt: process(clk_128M_buf)
--  begin
--    if rising_edge(clk_128M_buf) then
--      if (valid = '1') then
--        r_byte_cnt <= "00";
--      else
--        r_byte_cnt <= r_byte_cnt + 1;
--      end if;        
--    end if;
--  end process;


  -- we get 4 bytes at a time
  -- we need to stream them out one at a time with valids
  -- the low byte is the oldest data and should be processed first.
  proc_buffer_data : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (r_gt_data_valid = '1' and pll_locked = '1') then
        r_valid     <= "1111";
        r_data      <= r_gt_data(31 downto 0);
        r_data_is_k <= r_gt_data_is_k(3 downto 0);
      else
        r_valid     <= '0' & r_valid(3 downto 1);
        r_data      <= x"00" & r_data(31 downto 8);
        r_data_is_k <= '0' & r_data_is_k(3 downto 1);
      end if;
    end if;
  end process;

  proc_grab_byte : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (r_valid(0) = '1') then
        r_valid_dec  <= '1';
        r_data_dec   <= r_data(7 downto 0);
        r_data_dec_k <= r_data_is_k(0);
      else
        r_valid_dec  <= '0';
        r_data_dec   <= x"00";
        r_data_dec_k <= '0';
      end if;
    end if;
  end process;



  -- this will only decode data if it sees a valid k character before the data

  unpack_1 : entity work.unpack_telemetry
    port map(
      clk       => clk_256M,
      -- using valid from previous block, so first input will be invalid and missed
      k_in      => r_data_dec_k,
      data_in   => r_data_dec,
      valid_in  => r_valid_dec,
      data_out  => data_unpack_out,
      valid_out => valid_unpack_out
      );


  -- check result

-- grab the last data and increment it, to check next data
-- only checking class_id = E for now
-- only checking count
  proc_data_sync_E : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (valid_unpack_out = '1') then
        if data_unpack_out(83 downto 80) = x"E" then
          -- counter is only for the lower 9 bits, and wraps
          r_data_E(8 downto 0) <= unsigned(data_unpack_out(8 downto 0)) + 1;
        end if;
      end if;
    end if;
  end process;

  proc_data_sync_F : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (valid_unpack_out = '1') then
        if data_unpack_out(83 downto 80) = x"F" then
          r_data_F(8 downto 0) <= unsigned(data_unpack_out(8 downto 0)) + 1;
        end if;
      end if;
    end if;
  end process;




  proc_data_check_E : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (valid_unpack_out = '1') then
        if data_unpack_out(83 downto 80) = x"E" then
          if (data_unpack_out(31 downto 0) = std_logic_vector(r_data_E)) then
            -- data arriving matches expected data
            r_data_match <= '1';
          else
            r_data_match <= '0';
          end if;
        elsif data_unpack_out(83 downto 80) = x"F" then
          if (data_unpack_out(31 downto 0) = std_logic_vector(r_data_F)) then
            -- data arriving matches expected data
            r_data_match <= '1';
          else
            r_data_match <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;


  -- generate led that goes on if data is good for > 500 msec
  proc_led : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (valid_unpack_out = '1') then
        r_timeout_cnt <= x"0000";
        if (r_data_match = '1') then
          -- valid period of 1.6 usec means 500msec is about 4ffff
--          if (r_match_cnt >= x"4ffff") then
          if (r_match_cnt >= g_match_cnt) then
            r_okay_led_out <= '1';
          else
            r_match_cnt <= r_match_cnt + 1;
          end if;
        else
          r_okay_led_out <= '0';
          r_match_cnt    <= x"00000";
        end if;
      else
        -- timeout if no valids seen in a bit
        if r_timeout_cnt = g_timeout_cnt then
          r_okay_led_out <= '0';
        end if;
        r_timeout_cnt <= r_timeout_cnt + 1;
      end if;
    end if;
  end process;


  -- outputs 

  okay_led_out   <= r_okay_led_out;
  clk_256M_out   <= clk_256M;
  pll_locked_out <= pll_locked;
  data_out       <= data_unpack_out;
  valid_out      <= valid_unpack_out;
end architecture rtl;
