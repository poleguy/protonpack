-- 8b10b encoder
-------------------------------------------------
-- unpack_telemetry.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- this will only decode data if it sees a valid k character before the data
-- unpacks a series of bytes from the 8b10b decoder
-- converts it into a 11 byte wide output and valid
--------------------------------------------------
-- see version control for rev info
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library work;
--library UNISIM;
--use UNISIM.vcomponents.all;

entity unpack_telemetry is
  generic (
    -- https://stackoverflow.com/questions/36330302/vhdl-constant-in-generics
    g_data_width : natural := 11);  -- effectively a constant, in bytes (only 11 is supported)
  port
    (
      clk       : in  std_logic;
      en        : in  std_logic;
      k_in      : in  std_logic;
      data_in   : in  std_logic_vector(7 downto 0);
      valid_out : out std_logic;
      data_out  : out std_logic_vector(g_data_width*8-1 downto 0)
      );

end entity unpack_telemetry;

architecture rtl of unpack_telemetry is
  signal r_data_in  : std_logic_vector(7 downto 0) := (others => '0');
  signal r_data_out  : std_logic_vector(g_data_width*8-1 downto 0) := (others => '0');
  signal r_valid_out : std_logic                                   := '0';
  -- handles up to 15 data words, default to a stopped state to avoid a false start
  -- after reset
  signal r_cnt       : unsigned(3 downto 0)                        := x"f";
  
begin

  assert g_data_width = 11; -- only 11 byte telemetry data is supported here
  
  process(clk)
  begin
    if rising_edge(clk) then
      if (en = '1') then
        -- ignore k character when idle
        -- stream byte (1) is ignored, as it will be hard coded to zero
        if r_cnt = x"0" then
          r_data_out(7 downto 0) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"1" then
          r_data_out(15 downto 8) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"2" then
          r_data_out(23 downto 16) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"3" then
          r_data_out(31 downto 24) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"4" then
          r_data_out(39 downto 32) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"5" then
          r_data_out(8*6-1 downto 40) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"6" then
          r_data_out(8*7-1 downto 8*6) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"7" then
          r_data_out(8*8-1 downto 8*7) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"8" then
          r_data_out(8*9-1 downto 8*8) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"9" then
          r_data_out(8*10-1 downto 8*9) <= r_data_in;
          r_valid_out <= '0';
        elsif r_cnt = x"a" then
          r_data_out(8*11-1 downto 8*10) <= r_data_in;
        -- only send out valid data once all has been received
          r_valid_out              <= '1';
        end if;
      else
        r_valid_out <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if (en = '1') then
        if (k_in = '0') then
          r_data_in <= data_in;
        end if;
      end if;
    end if;
  end process;

  -- count bytes while not k_in is low
  -- can only handle length of 15, which is fine because this is hard coded for
  -- 11 byte packets
  process(clk)
  begin
    if rising_edge(clk) then
      if (en = '1') then
        if (k_in = '0') then
          -- count bytes
          r_cnt <= r_cnt + 1;
        else
          -- this will wrap on the next data byte (i.e. k_in = '0')
          r_cnt <= x"f";
        end if;
      end if;
    end if;
  end process;


  -- outputs
  data_out  <= r_data_out;
  valid_out <= r_valid_out;
  
  
end architecture rtl;

