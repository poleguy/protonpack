-------------------------------------------------
-- mobile_data_buff.vhd
--------------------------------------------------
--
-- Copyright © 2022 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
--
-- Create a ping-pong buffer for mobile telemetry
-- trigger/sample sets. Fields are buffered here
-- and only written downstream to eth-telemetry
-- once a complete sample set has been received.
-- Importantly the output always writes a complete
-- sample set to keep us field and buffer aligned
-- in eth-telem FIFO.
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

entity mobile_data_buff is
   generic(
    BUFFER_SIZE_NUM_FIELDS : natural := 128

   );
  port(
    clk      : in  std_logic;
    rst      : in  std_logic; 

    valid    : in std_logic;
    field    : in std_logic_vector(7 downto 0);
    data     : in std_logic_vector(31 downto 0);
    timestamp : in std_logic_vector(31 downto 0);

    num_fields : in std_logic_vector(7 downto 0); --number of fields for this stream

    -- output to ethernet-telemetry
    stream_valid : out std_logic;
    stream_data  : out std_logic_vector(31 downto 0)
    );
end mobile_data_buff;

architecture rtl of mobile_data_buff is

    constant BUFFER_WIDTH : integer := integer(ceil(log2(real(BUFFER_SIZE_NUM_FIELDS))));

    type StateType is (IDLE, COLLECT, COMPLETE);
    signal state_wr : StateType := IDLE;

    type StateTypeRd is (IDLE, READ_TIME, READ, READ_LAST_VALID);
    signal state_rd : StateTypeRd := IDLE;

    signal wr_not_rd    : std_logic_vector(0 downto 0) := (others=>'0');
    --signal wr_ptr       : std_logic_vector(BUFFER_WIDTH-1 downto 0);
    signal rd_ptr       : std_logic_vector(BUFFER_WIDTH-1 downto 0);
    signal wr_addr      : std_logic_vector(rd_ptr'left+1 downto 0);
    signal rd_addr      : std_logic_vector(rd_ptr'left+1 downto 0);

    signal rd_val : std_logic;

    signal last_field : std_logic;

    signal ram_rd_data : std_logic_vector(31 downto 0);

    type t_ram is array ((BUFFER_SIZE_NUM_FIELDS*2)-1 downto 0) of std_logic_vector(31 downto 0);
    signal ram  : t_ram;

    type t_timestamp is array (1 downto 0) of std_logic_vector(31 downto 0);
    signal timestamps : t_timestamp;

    signal stream_data_pre : std_logic_vector(31 downto 0);
    signal stream_valid_pre : std_logic;

begin

    wr_addr <=     wr_not_rd & field(BUFFER_WIDTH-1 downto 0);
    rd_addr <= not wr_not_rd & rd_ptr;


    -- ping pong buffer select
    process(clk)begin
        if rising_edge(clk) then
            if(rst='1')then
                wr_not_rd(0) <= '0';
            elsif(state_wr=COMPLETE)then
                wr_not_rd(0) <= not wr_not_rd(0);
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    -- Store Timestamp  
    -----------------------------------------------------------------------------
    process(clk)begin
        if rising_edge(clk) then
            if(field=0 and valid='1')then
                timestamps(to_integer(unsigned(wr_not_rd))) <= timestamp;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    -- Write Data to Buffer
    -----------------------------------------------------------------------------
    last_field <= '1' when field=num_fields-1 else '0';

    -- write FSM
    process(clk)begin
        if rising_edge(clk) then

            if(rst='1' or num_fields=0)then
                state_wr <= IDLE;


            else
                case(state_wr)is

                    when IDLE =>
                        if(valid='1' and field=0)then
                            state_wr <= COLLECT;
                        end if;

                    when COLLECT =>
                        -- only 1 field is a special edge case:
                        if(num_fields=1)then
                            state_wr <= COMPLETE;
                        -- greater than 1 field:
                        elsif(valid='1' and last_field='1')then
                            state_wr <= COMPLETE;
                        end if;

                    when COMPLETE =>
                        state_wr   <= IDLE;
                end case;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    -- Reade Data from Buffer
    -----------------------------------------------------------------------------
    --rd ptr
    process(clk)begin
        if rising_edge(clk) then
            if(state_rd=IDLE)then
                rd_ptr <= (others=>'0');
            elsif(state_rd=READ_TIME or state_rd=READ)then
                rd_ptr <= rd_ptr + 1;
            end if;
        end if;
    end process;

    -- write out the timestamp first as eth-telem field0, followed by all the mobile fields
    process(clk)begin
        if rising_edge(clk) then

            if(rst='1')then
                state_rd <= IDLE;

            else
                case(state_rd)is
                    when IDLE =>
                        if(state_wr=COMPLETE)then --buffer write is complete, read it out now
                            state_rd <= READ_TIME;
                        end if;

                    when READ_TIME =>
                        -- special case where num_fields is 1 only need to read one data sample
                        if(num_fields=1)then 
                            state_rd <= READ_LAST_VALID;
                        -- num_fields greater than 1
                        else
                            state_rd <= READ;
                        end if;

                    when READ =>
                        if(rd_ptr=num_fields-1)then --last valid data is rd_ptr=num_fields-1
                            state_rd <= READ_LAST_VALID;
                        end if;

                    when READ_LAST_VALID =>
                        state_rd <= IDLE;
                end case;
            end if;
        end if;
    end process;

    stream_data_pre <= timestamps(to_integer(unsigned(not wr_not_rd))) when state_rd=READ_TIME else ram_rd_data;
    stream_valid_pre <= '0' when state_rd=IDLE else '1';


    -- register output
    process(clk)begin
        if rising_edge(clk) then
            stream_valid <= stream_valid_pre;
            stream_data  <= stream_data_pre;
        end if;
    end process;

    -----------------------------------------------------------------------------
    -- RAM Write/Read Processes
    -----------------------------------------------------------------------------
    process(clk)begin
        if rising_edge(clk) then
            if(valid='1')then
                ram(to_integer(unsigned(wr_addr))) <= data;
            end if;
        end if;
    end process;

    process(clk)begin
        if rising_edge(clk) then
            ram_rd_data <= ram(to_integer(unsigned(rd_addr)));
        end if;
    end process;


end;
