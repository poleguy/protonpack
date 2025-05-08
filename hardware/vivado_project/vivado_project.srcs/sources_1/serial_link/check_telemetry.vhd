-------------------------------------------------
-- check_telemetry.vhd
--------------------------------------------------
--
-- Copyright © 2021 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
-- expects 11 byte telemetry data from the rx. passes it along unmodified.
-- this is a step toward eventually:
--
-- pulling out the config data and mapping it into
-- a telemetry packet
-- pulling out the other data and passing it along
-- as the various streams of ethernet-telemetry
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

entity check_telemetry is
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

      clk_102M4      : in  std_logic;  -- 102.4 MHz
      -- will be multiplied up to generate
      -- 1024 mbit data stream
      -- 512 MHz clock for DDR output
      -- 256 MHz clock for data processing at 10bit or 8bit with valid 
      rst_102M4      : in  std_logic;
      -- serial input
      serial_in_n    : in  std_logic;
      serial_in_p    : in  std_logic;
      clk_256M_out   : out std_logic;
      pll_locked_out : out std_logic;
      okay_led_out   : out std_logic;
      cnt_led_out    : out std_logic;
      data_out       : out std_logic_vector(87 downto 0);
      valid_out      : out std_logic;
      rx_dat_aligned : out std_logic;
      alignment_out  : out std_logic_vector(3 downto 0);
      rx_data_ready  : out std_logic;
      rx_data_raw    : out std_logic_vector(9 downto 0)
      );

end check_telemetry;

architecture rtl of check_telemetry is

  signal clk_256M : std_logic;



  -- set this longer for a longer test
  --constant c_test_len : integer := 2000;


  signal r_data_E : unsigned(31 downto 0) := (others => '0');
  signal r_data_F : unsigned(31 downto 0) := (others => '0');
  -- pack
--  signal r_valid_in : std_logic                     := '0';
--  signal r_data_in  : std_logic_vector(55 downto 0) := (others => '0');

  -- dec
  signal rdisp_dec    : std_logic;
  signal k_dec_out    : std_logic;
  signal data_dec_out : std_logic_vector(7 downto 0);



  -- unpack
  signal valid_unpack_out : std_logic;
  signal data_unpack_out  : std_logic_vector(87 downto 0);


  -- check
  signal r_data_match  : std_logic             := '0';
  signal r_timeout_cnt : unsigned(15 downto 0) := x"0000";
  signal r_match_cnt   : unsigned(19 downto 0) := x"00000";

  signal r_okay_led_out : std_logic := '0';

  signal IntRxD_p         : std_logic_vector(0 downto 0);
  signal IntRxD_n         : std_logic_vector(0 downto 0);
  signal RxDataRdy        : std_logic_vector(0 downto 0);
--  signal RxRawData     : std_logic_vector(7 downto 0);
  signal RxData           : std_logic_vector(9 downto 0);
  signal RxDataRev        : std_logic_vector(9 downto 0);
  signal RxClkDiv         : std_logic;
  signal data_framed      : std_logic_vector(9 downto 0);
  signal valid_framed     : std_logic;
  signal aligned          : std_logic;
--  signal clk_102M4       : std_logic;
  -- count up to ten bits set
  signal r_cnt_rising     : unsigned(3 downto 0)         := (others => '0');
  signal r_cnt            : unsigned(27 downto 0)        := (others => '0');
  signal pll_locked       : std_logic;
  signal r_rx_data        : std_logic                    := '0';
  signal r_rx_data_rising : std_logic_vector(9 downto 0) := (others => '0');

  signal probe2 : std_logic_vector(9 downto 0);
  signal probe3 : std_logic_vector(9 downto 0);

begin

  ---------------------------------------------------------------------------------------------
-- LVDS Receiver
---------------------------------------------------------------------------------------------
  Receiver_0 : entity work.Receiver
    generic map (
      -- LOC constraints must be conistent with LOC's
      -- in constraint file and with each other
      C_MmcmLoc       => "MMCME2_ADV_X0Y0",
      C_UseFbBufg     => 0,
      C_UseBufg       => "0000000",
      C_RstOutDly     => 2,
      C_EnaOutDly     => 6,
      C_Width         => 1,
      C_AlifeFactor   => 5,
      C_AlifeOn       => "00000001",
      C_DataWidth     => 1,
      C_BufioClk0Loc  => "BUFIO_X0Y0",
      C_BufioClk90Loc => "BUFIO_X0Y1",
      C_IdlyCtrlLoc   => "IDELAYCTRL_X0Y0",
      -- target is 244ps (45degrees of 1024MHz period)
      -- at 200MHz single tap delay is 78ps
      -- 2 is 156 ps, 3 is 234, 4 is 312ps
      -- at 300MHz single tap delay is 52ps
      -- 3 is 156 ps, 4 is 208, 5 is 260ps
      -- at 400MHz single tap delay is 39ps
      -- 4 is 156 ps, 5 is 195, 6 is 234ps, 7 is 273ps
      -- https://www.xilinx.com/support/documentation/data_sheets/ds181_Artix_7_Data_Sheet.pdf
      -- https://forums.xilinx.com/t5/Other-FPGA-Architecture/IDELAY-Tap-delay-control-using-Ref-frequency/td-p/639670
      -- Notes: first tap is longer, 64 tap sum is adjusted to be one period of
      -- ref clock.
      -- expected single tap delay average is 1/(REF_CLK_FREQ*64)
      -- refclk must be +-10 MHz
      -- so 390@6taps is 240ps
      -- so 290@4taps is 216ps
      -- so 310@5taps is 252ps
      -- so 210@5taps is 252ps
      -- so 190@3taps is 247ps
      -- presumably more taps is better, so probably pcik 390@6taps

      C_IdlyCntVal_M    => "00000",
      C_IdlyCntVal_S    => "00110",
      -- mmcm must also be adjusted inside to make this right
      -- period is +/- 10 MHz
      C_RefClkFreq      => 292.571,
      C_IoSrdsDataWidth => 4,
      C_ClockPattern    => "1010"
      )
    port map (
      RxD_p        => IntRxD_p,   -- in [C_DataWidth-1:0]
      RxD_n        => IntRxD_n,   -- in [C_DataWidth-1:0]
      RxClkIn      => clk_102M4,  -- in 102.4MHz
      -- should be 125M to run data at 1250Mbit
      -- reference clock to generate clock used for data
      --this will create: a 25mhz clock (1/2 data rate)
      --an inverted 25mhz clock
      RxRst        => rst_102M4,  -- in
      RxClk        => open,       -- out
      RxClkDiv     => RxClkDiv,   -- out RxClkIn * 5/2 (e.g. 102.4 -> 256)
      RxMmcmLocked => pll_locked,
      RxMmcmAlive  => open,       -- out
      RxDatAlignd  => rx_dat_aligned,       -- out
      RxDataRdy    => RxDataRdy,  -- out [C_DataWidth-1:0]
      RxRawData    => open,       -- out [(C_DataWidth*8)-1:0]
      RxData       => RxData      -- out [(C_DataWidth*10)-1:0]
     -- RxData comes out at RxClkDiv 256 MHz, 10 bits at a time.
      );

-- for testing of no data case
--RxData <= "1111111111";

  RxDataRev <= RxData(0) & RxData(1) & RxData(2) & RxData(3) & RxData(4) & RxData(5) &
               RxData(6) & RxData(7) & RxData(8) & RxData(9);


  IntRxD_p(0) <= SERIAL_IN_N;
  IntRxD_n(0) <= SERIAL_IN_P;

  -- output data to debug low-level trouble with functionality
  rx_data_ready <= RxDataRdy(0);
  rx_data_raw <= RxDataRev;

  probe2 <= "0000" & r_okay_led_out & r_data_match & aligned & valid_framed & RxDataRdy & pll_locked;
  probe3 <= "0" & k_dec_out & data_dec_out;
--  gen_debug : if g_debug = '1' generate
    -- four ten bit probes
--    inst_ila_0 : entity work.ila_0
--      port map (
--        clk    => RxClkDiv,
--        probe0 => RxData,
--        probe1 => data_framed,
--        probe2 => probe2,
--        probe3 => probe3
--        );
--  end generate gen_debug;


  -- count rising transitions in input stream
  proc_edge_detect : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (RxDataRdy(0) = '1') then
        r_rx_data        <= RxData(0);
        r_rx_data_rising <= RxData and not (r_rx_data & RxData(9 downto 1));
      end if;
    end if;
  end process;

  proc_cnt_input : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (RxDataRdy(0) = '1') then
        r_cnt_rising <= resize(unsigned(r_rx_data_rising(9 downto 9)), 4) + resize(unsigned(r_rx_data_rising(8 downto 8)), 4) +
                        resize(unsigned(r_rx_data_rising(7 downto 7)), 4) + resize(unsigned(r_rx_data_rising(6 downto 6)), 4) +
                        resize(unsigned(r_rx_data_rising(5 downto 5)), 4) + resize(unsigned(r_rx_data_rising(4 downto 4)), 4) +
                        resize(unsigned(r_rx_data_rising(3 downto 3)), 4) + resize(unsigned(r_rx_data_rising(2 downto 2)), 4) +
                        resize(unsigned(r_rx_data_rising(1 downto 1)), 4) + resize(unsigned(r_rx_data_rising(0 downto 0)), 4);
      end if;
    end if;
  end process;

  -- count rising edges in input stream
  proc_cnt : process(clk_256M)
  begin
    if rising_edge(clk_256M) then
      if (RxDataRdy(0) = '1') then
        r_cnt <= r_cnt + r_cnt_rising;
      end if;
    end if;
  end process;

-- expecting 50% ones if the data is good.
-- so we will get an average of 5 ones every valid
-- each valid comes at 102.4 Mhz
-- so 2**28 bits should give a 1/2 second toggle
  cnt_led_out <= r_cnt(27);

---------------------------------------------------------------------------------------------

-- todo: implement block:
  -- base on des.vhd
  -- framer.vhd
  --
  -- 10 bits in to framer
  -- 10 bits out aligned to k character
  framer_1 : entity work.framer
    port map (
      clk         => RxClkDiv,
      data_in     => RxDataRev,
      valid_in    => RxDataRdy(0),
      data_out    => data_framed,
      alignment_out => alignment_out,
      aligned_out => aligned,
      valid_out   => valid_framed
      );
  


  RxDataRev <= RxData(0) & RxData(1) & RxData(2) & RxData(3) & RxData(4) & RxData(5) &
               RxData(6) & RxData(7) & RxData(8) & RxData(9);
  clk_256M <= RxClkDiv;

  dec_8b10b_1 : entity work.dec_8b10b
    port map (
      clk        => clk_256M,
      datain_10b => data_framed,
      rdispin    => rdisp_dec,
      en         => valid_framed,
      reset_n    => '1',  -- who cares?      
      dataout_8b => data_dec_out,
      kout       => k_dec_out,
      disp_err   => open,
      code_err   => open,
      rdispout   => rdisp_dec,
      debug      => open
      );


  -- this will only decode data if it sees a valid k character before the data

  unpack_1 : entity work.unpack_telemetry
    port map(
      clk       => clk_256M,
      en        => valid_framed,
      -- using valid from previous block, so first input will be invalid and missed
      k_in      => k_dec_out,
      data_in   => data_dec_out,
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
