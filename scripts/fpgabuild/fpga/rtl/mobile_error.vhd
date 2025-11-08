-------------------------------------------------
-- mobile_error.vhd
--------------------------------------------------
--
-- Copyright © 2022 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
--
-- Check for and handle errors
--
--------------------------------------------------
-- Engineer: Alex Stezskal
-- see version control for rev info
--------------------------------------------------
--  

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use ieee.math_real.all; --for ceil, log2

entity mobile_error is
  port(
    clk      : in  std_logic;
    rst      : in  std_logic; --also reset to discard buffer / if error occurs
    one_ms_pulse : in std_logic;

    valid    : in std_logic;
    field    : in std_logic_vector(7 downto 0);
    num_fields : in std_logic_vector(7 downto 0);

    serial_error_in : in std_logic;

    field_error_out  : out std_logic := '0';
    serial_error_out : out std_logic := '0'
    );
end mobile_error;

architecture rtl of mobile_error is

    signal stream_start : std_logic := '0';
    signal out_of_order_flag : std_logic := '0';

    signal order_ms_cnt : std_logic_vector(10 downto 0):=(others=>'0');
    signal field_ms_cnt : std_logic_vector(10 downto 0):=(others=>'0');
    signal serial_ms_cnt : std_logic_vector(10 downto 0):=(others=>'0');

    signal field_prev : std_logic_vector(field'left downto 0);

    signal timeout : std_logic := '1';

    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of field_prev      : signal is "TRUE";
    attribute MARK_DEBUG of one_ms_pulse    : signal is "TRUE";
    attribute MARK_DEBUG of out_of_order_flag    : signal is "TRUE";
    attribute MARK_DEBUG of field_ms_cnt    : signal is "TRUE";
    attribute MARK_DEBUG of serial_ms_cnt    : signal is "TRUE";
    attribute MARK_DEBUG of stream_start    : signal is "TRUE";

begin

     -- valid logic
     process(clk)begin
         if rising_edge(clk) then

             if(rst='1' or timeout='1')then
                 stream_start <= '0';

             else
                 -- only act if the class=stream (valid input should be gated on this class)
                 -- if we are on field0 we are starting a new sample set, so we write in the timestamp first
                 -- use the timestamp from field0 which should be the same for all fields of this sample set
                 if(field=0 and valid='1')then
                     stream_start <= '1' after 1 ps; --set that we've stored field0 timestamp

                 end if;

             end if; --rst 

         end if; --clk
     end process;

    process(clk)begin
        if rising_edge(clk) then
            timeout <= '0'; -- default 0

            if(valid='1')then  -- if a field has come in, reset the timeout counter
                order_ms_cnt <= (others=>'0');
            elsif(order_ms_cnt(order_ms_cnt'left)='1')then   -- ~1second at 2**10 of 1ms pulses
                order_ms_cnt <= (others=>'0');
                timeout <= '1'; -- pulse timeout signal when time reaches desired amount
            elsif(one_ms_pulse='1')then
                order_ms_cnt <= order_ms_cnt + 1;
            end if;
        end if;
    end process;

     -------------------------------------------------------
     --
     --  Check for receiving a field out of order.
     --  This could happen on a reboot or power-
     --  cycle of the Transmitting side.
     --
     -------------------------------------------------------
     process(clk)begin
         if rising_edge(clk) then

             if(valid='1')then
                 field_prev<=field;
             end if;

             out_of_order_flag <= '0';

             -- If only 1 field, then can't be out of order
             if(num_fields>1)then

                 -- check for expected field at the proper time
                 -- on valid before previous is re-stored
                 -- and only when we have already seen field0 and started capturing data
                 if(valid='1' and stream_start='1')then

                     -- If field0 then the previous should have been the max
                     if(field=0 and field_prev/=(num_fields-1))then
                         out_of_order_flag <= '1';

                     -- Any other field other than field 0
                     elsif(field/=0 and field/=(field_prev+1))then
                         out_of_order_flag <= '1';

                     -- normal not out of order
                    -- else
                    --     out_of_order_flag <= '0';
                     end if;

                 end if; --valid

             end if; --num_fields


         end if; --clk
     end process;



     -- hold any error activity for about a second so that it shows up in telemetry around the time of occurance 
     -- but doesn't indicate an error forever if the error goes away
     process(clk)begin
         if rising_edge(clk) then
             if(rst='1')then
                 field_error_out <= '0';
             else
                 if(out_of_order_flag='1')then
                     field_ms_cnt <= (others=>'0');
                     field_error_out <= '1';
                 elsif(field_ms_cnt(field_ms_cnt'left)='1')then   -- ~1second at 2**10 of 1ms pulses
                     field_error_out <= '0';
                 elsif(one_ms_pulse='1')then
                     field_ms_cnt <= field_ms_cnt + 1;
                 end if;
             end if;
         end if;
     end process;

     process(clk)begin
         if rising_edge(clk) then
             if(rst='1')then
                 serial_error_out<='0';
             else
                 if(serial_error_in='1')then
                     serial_ms_cnt <= (others=>'0');
                     serial_error_out <= '1';
                 elsif(serial_ms_cnt(serial_ms_cnt'left)='1')then   -- ~1second at 2**10 of 1ms pulses
                     serial_error_out <= '0';
                 elsif(one_ms_pulse='1')then
                     serial_ms_cnt <= serial_ms_cnt + 1;
                 end if;
             end if;
         end if;
     end process;

end;
