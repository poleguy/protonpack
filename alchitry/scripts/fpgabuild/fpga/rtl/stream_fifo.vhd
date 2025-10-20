-- Alex Stezskal
-- Shure inc.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all;

use work.telemetry_cfg_pkg.all;

ENTITY stream_fifo IS
    generic(
    STREAM_NUM       : in integer := 0;
    STREAM_FIELDS    : in integer := 1;
    STREAM_NUM_WORDS : in integer := 1;
    FIFO_DATA_WIDTH  : in integer := 8;
    FIFO_ADDR_WIDTH  : in integer := 11 --11=2048 (BRAM18) 12=4096 (BRAM36E1)
);
port(
    -- Application Stream Inputs (declared in pkg)
    s_clk       : in std_logic;
    s_valid     : in std_logic;
    s_en        : in std_logic_vector(FIELD_ENABLE_SIZE_BYTES*8-1 downto 0);
    s_data      : in std_logic_vector(STREAM_NUM_WORDS*FIFO_DATA_WIDTH-1 downto 0);

    s_user_error : in std_logic_vector(STREAM_USER_ERROR_BITS-1 downto 0);

    pkt_size    : in integer range 0 to 1472;

    sys_time    : in std_logic_vector(31 downto 0);

    rd_rst      : in std_logic;
    rd_clk      : in  std_logic;
    rd_rdy      : out std_logic;
    rd_en       : in std_logic;
    rd_data     : out std_logic_vector(7 downto 0)

    );
END stream_fifo;

ARCHITECTURE rtl OF stream_fifo IS

    attribute ASYNC_REG                        : string;

    constant FIFO_BYTE_WIDTH : integer := (FIFO_DATA_WIDTH/8);

    signal s_data_d      : std_logic_vector(STREAM_NUM_WORDS*FIFO_DATA_WIDTH-1 downto 0) := (others=>'0');

    type StateTypeWr is (IDLE,WR_DATA);
    signal state_wr : StateTypeWr := IDLE;

    type StateTypeRd is (IDLE,STATUS,FIFO);
    signal state_rd : StateTypeRd := IDLE;

    signal stream_sel   : integer range 0 to STREAM_NUM_WORDS;
    signal r_stream_sel : integer range 0 to STREAM_NUM_WORDS-1;
    signal valid_d : std_logic := '0';
    signal last_index : std_logic;

    signal rd_beat : integer range 0 to PAYLOAD_STATUS_SIZE_BYTES;

    type t_sdata_mux is array (STREAM_NUM_WORDS-1 downto 0) of std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    signal stream_mux : t_sdata_mux;
    type t_en_mux is array (FIELD_ENABLE_SIZE_BYTES-1 downto 0) of std_logic_vector(7 downto 0);
    signal en_mux : t_en_mux;

    signal wr_fifo_data : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
    signal wr_set_thresh_in : std_logic_vector(FIFO_ADDR_WIDTH-1 downto 0);
    signal time_mux_out : std_logic_vector(7 downto 0);

    signal rd_fifo_data : std_logic_vector(FIFO_BYTE_WIDTH*8-1 downto 0);
    type t_fifo_mux is array (FIFO_BYTE_WIDTH-1 downto 0) of std_logic_vector(7 downto 0);
    signal rd_fifo_data_mux : t_fifo_mux;
    signal rd_fifo_data_mux_out : std_logic_vector(7 downto 0);
    signal rd_fifo_inc : std_logic := '0';
    signal rd_en_allow : std_logic := '0';
    signal rd_full : std_logic;
    signal rd_byte_sel : integer range 0 to FIFO_BYTE_WIDTH-1  := FIFO_BYTE_WIDTH-1;
    signal sys_time_held : std_logic_vector(31 downto 0);

    signal fifo_full_since_pwr_on     : std_logic := '0';
    signal fifo_full_since_pkt     : std_logic := '0';
    signal error_status     : std_logic_vector(7 downto 0) := (others=>'0');
    signal fifo_available_held : std_logic_vector(23 downto 0) := (others=>'0');

    signal rrst_n : std_logic;
    signal wrst_n : std_logic;

    signal wr_en : std_logic := '0';

    signal rd_rdy_in : std_logic;

    signal rd_depth : std_logic_vector(FIFO_ADDR_WIDTH downto 0);
    signal rd_data_mux_out : std_logic_vector(7 downto 0);

    signal rst_s_clk_meta : std_logic := '0';
    signal rst_s_clk_sync : std_logic := '0';

    signal wfull : std_logic;
    signal rd_full_meta : std_logic;

    signal err_val_too_soon : std_logic := '0';
    signal err_val_too_soon_sticky : std_logic := '0';

    attribute ASYNC_REG of rst_s_clk_meta : signal is "TRUE";
    attribute ASYNC_REG of rst_s_clk_sync : signal is "TRUE";

    attribute ASYNC_REG of rd_full_meta : signal is "TRUE";
    attribute ASYNC_REG of rd_full      : signal is "TRUE";


    constant FIFO_TOTAL_CAPACITY : std_logic_vector(FIFO_ADDR_WIDTH downto 0) := std_logic_vector(to_unsigned(2**FIFO_ADDR_WIDTH, FIFO_ADDR_WIDTH+1));

   -- attribute mark_debug : string;
   -- attribute mark_debug of state_rd : signal is "true";
   -- attribute mark_debug of state_wr : signal is "true";
   -- attribute mark_debug of rd_beat : signal is "true";
   -- attribute mark_debug of rd_en : signal is "true";
   -- attribute mark_debug of rd_rdy : signal is "true";
   -- attribute mark_debug of rd_full : signal is "true";
   -- attribute mark_debug of rd_depth : signal is "true";
   -- attribute mark_debug of rd_fifo_inc : signal is "true";
   -- attribute mark_debug of rd_fifo_data : signal is "true";
   -- attribute mark_debug of rd_data : signal is "true";
   -- attribute mark_debug of wr_fifo_data : signal is "true";
   -- attribute mark_debug of wr_en : signal is "true";

BEGIN

    -- Get the FIFO threshold that indicates we have enough FIFO entires corresponding to enough bytes
    -- to generate the desired pkt size.  This value is in FIFO depth units, not necessarily bytes.
    -- For standard mode where you don't change the fifo-data-width then this unit is bytes.
    wr_set_thresh_in    <= std_logic_vector(to_unsigned(getStreamFifoDepthThreshold(STREAM_NUM),FIFO_ADDR_WIDTH)); 
     
    rd_rdy_in <= '1' when rd_depth>=wr_set_thresh_in else '0';

    process(s_clk)begin
        if rising_edge(s_clk)then
            if(s_valid='1')then
                if(state_wr=WR_DATA and last_index='0')then
                    err_val_too_soon <= '1';
                else
                    err_val_too_soon <= '0';
                end if;
            end if;
            if(err_val_too_soon='1')then
                err_val_too_soon_sticky <= '1';
            end if;
        end if;
    end process;

    process(rd_clk)begin
        if rising_edge(rd_clk)then
            rd_rdy <= rd_rdy_in;
        end if;
    end process;

    rrst_n <= not rd_rst;
    wrst_n <= not rst_s_clk_sync;

    fifo_0 : entity work.fifo1
    generic map(
        DSIZE         => FIFO_DATA_WIDTH,
        ASIZE         => FIFO_ADDR_WIDTH
        --USE_DISTR_NOT_BLOCK_RAM => false
    )
    port map(
        -- Write Interface
        wclk         => s_clk,
        wdata        => wr_fifo_data,
        winc         => wr_en,
        wfull        => wfull,
        wrst_n       => wrst_n,

        -- Read Interface
        rclk         => rd_clk,
        rdata        => rd_fifo_data(FIFO_DATA_WIDTH-1 downto 0),
        rinc         => rd_fifo_inc,
        rempty       => open,
        rdepth       => rd_depth,
        rrst_n       => rrst_n
    );

    wr_en <= '1' when state_wr=WR_DATA else '0';

    -------------------------------------------------------------------------------------
    -- Setup FIFO Input data Muxing
    -- dependent on # of stream bytes
    -------------------------------------------------------------------------------------
    --
    -- big endian (send most significant byte first in time within each data field)
    --   via the indexing in LHS of these mux statements
    
    -- register the input data on valid in case data changes between valids
    -- also helps with timing at the expense of more resources
    process(s_clk)begin
        if rising_edge(s_clk) then
            if(s_valid='1')then
                s_data_d <= s_data;
            end if;
        end if;
    end process;
    
    -- select a byte (or 32b word) to write into the fifo
    data_mux_gen : for ii in 0 to STREAM_NUM_WORDS-1 generate
        stream_mux(STREAM_NUM_WORDS-1-ii) <= s_data_d((FIFO_DATA_WIDTH-1)+(ii*FIFO_DATA_WIDTH) downto (ii*FIFO_DATA_WIDTH));
    end generate;

    wr_fifo_data <= stream_mux(r_stream_sel);

    -- TODO field enable capability does not exist... the implementation would invovle gating stream data based on 
    -- field enable bits
    en_mux_gen : for ii in 0 to FIELD_ENABLE_SIZE_BYTES-1 generate
        en_mux(FIELD_ENABLE_SIZE_BYTES-1-ii) <= s_en(7+(ii*8) downto (ii*8));
    end generate;


    process(s_clk)begin
        if rising_edge(s_clk) then
            valid_d <= s_valid;
        end if;
    end process;


    last_index <= '1' when r_stream_sel=STREAM_NUM_WORDS-1 else '0';

    -- Stream input data index counter
    stream_sel <= 0 when s_valid='1'    else -- if valid_d, should be byte 0
                  0 when last_index='1' else -- if hit max number of words, reset counter 
                  r_stream_sel + 1;            -- otherwise assume we are indexing a valid already

    process(s_clk)begin
        if rising_edge(s_clk) then
            if(rst_s_clk_sync='1')then
                r_stream_sel <= 0;
            else
                r_stream_sel <= stream_sel;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------------------
    -- Write Stream data into FIFO State Machine
    -------------------------------------------------------------------------------------
    process (s_clk) begin
        if rising_edge(s_clk) then
            rst_s_clk_meta <= rd_rst;
            rst_s_clk_sync <= rst_s_clk_meta;
        end if;
    end process;

    process(s_clk)begin
        if rising_edge(s_clk) then
            if(rst_s_clk_sync='1')then
                state_wr <= IDLE;
            else
                case(state_wr)is
                    when IDLE =>
                        if(s_valid='1')then
                            state_wr <= WR_DATA;
                        end if;
                    when WR_DATA =>
                        if(last_index='1')then
                            -- its a back-back write (max write throughput), no time for IDLE
                            -- this can occur in a burst application
                            if(s_valid='1')then 
                                state_wr <= WR_DATA;
                            else
                                state_wr <= IDLE;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;


    -------------------------------------------------------------------------------------
    -- Packet data multiplexer
    -- send some Payload header status data and then send the actual stream data via rd_fifo_data_mux
    -------------------------------------------------------------------------------------

    -- send all fields big endian (MSByte first in time)
    rd_data         <=  en_mux(3)            when rd_beat=0 else
                        en_mux(2)            when rd_beat=1 else
                        en_mux(1)            when rd_beat=2 else
                        en_mux(0)            when rd_beat=3 else
                        error_status          when rd_beat=4 else
                        fifo_available_held(23 downto 16)  when rd_beat=5 else
                        fifo_available_held(15 downto 8)  when rd_beat=6 else
                        fifo_available_held(7 downto 0)   when rd_beat=7 else
                        sys_time_held(31 downto 24)  when rd_beat=8 else
                        sys_time_held(23 downto 16)  when rd_beat=9 else
                        sys_time_held(15 downto 8)  when rd_beat=10 else
                        sys_time_held(7 downto 0)   when rd_beat=11 else
                        rd_fifo_data_mux_out; --rd_beat=12

    -- Generate a mux to select which byte is read from fifo output
    -- If only byte-wide fifo (typical) then there is no mux (1 byte read goes to ethernet)
    -- However for burst applications, helpful to support wider fifo widths
    -- Big endian.. send most significant byte first, (which is most significant of field 0)
    fifo_rd_mux_gen : for ii in 0 to FIFO_BYTE_WIDTH-1 generate
        rd_fifo_data_mux(FIFO_BYTE_WIDTH-1-ii) <=rd_fifo_data((ii+1)*8-1 downto ii*8);
    end generate;
    rd_fifo_data_mux_out <= rd_fifo_data_mux(rd_byte_sel);

    -- Have to fire the rd_fifo_inc 2 clocks before you want a new sample. Since we're clocking this, need 3 cycles before (see original below)
    -- 1 clock increments the address, then once clock delay of memory on the output of new addr
    -- the last fire of the rd_fifo_inc will set the address for the first read of the next packet
    process(rd_clk) begin
        if rising_edge(rd_clk) then
            if (FIFO_BYTE_WIDTH=1 and (rd_beat >= (PAYLOAD_STATUS_SIZE_BYTES-2))) then
                rd_en_allow <= rd_en;
            elsif (FIFO_BYTE_WIDTH=2 and (rd_beat = PAYLOAD_STATUS_SIZE_BYTES-1)) then -- need this to start a read before rd_byte_sel starts counting
                rd_en_allow <= rd_en;
            elsif (FIFO_BYTE_WIDTH=2 and (rd_beat > (PAYLOAD_STATUS_SIZE_BYTES-1)) and rd_byte_sel=1) then
                rd_en_allow <= rd_en;
            elsif (FIFO_BYTE_WIDTH>2 and rd_byte_sel=FIFO_BYTE_WIDTH-3 and state_rd=FIFO) then
                rd_en_allow <= rd_en;
            else
                rd_en_allow <= '0';
            end if;
        end if;
    end process;

    rd_fifo_inc <= rd_en when rd_en_allow = '1' else '0'; -- need rd_fifo_inc to deassert at same time as rd_en

    -- Original code for reference
    -- rd_fifo_inc <= rd_en when FIFO_BYTE_WIDTH=1 and (rd_beat >= (PAYLOAD_STATUS_SIZE_BYTES-1)) else --this will prime 1 byte at correct time(start 1 clock earlier than 1st payload byte)
                   -- rd_en when FIFO_BYTE_WIDTH=2 and (rd_beat >= (PAYLOAD_STATUS_SIZE_BYTES)) and rd_byte_sel=0 else --will prime 2 byte fifo width at correct time (start clock of 1st payload byte)
                   -- rd_en when rd_byte_sel=FIFO_BYTE_WIDTH-2 else --otherwize always increment fifo addr 2 clocks before it is needed (rd_byte_sel=0) since thats the first mux byte output
                   -- '0';

    --rd_byte_sel logic. used as mux select when reading out larger than 1byte fifo width data..
    process(rd_clk)begin
        if rising_edge(rd_clk) then
            if(state_rd/=FIFO)then
                rd_byte_sel <= 0;
            elsif(rd_byte_sel=FIFO_BYTE_WIDTH-1)then
                rd_byte_sel <= 0;
            else
                rd_byte_sel <= rd_byte_sel + 1;
            end if;
        end if;
    end process;

    -- rd data beat or counter (each rd data clock is a beat)
    process(rd_clk)begin
        if rising_edge(rd_clk) then
            if(rd_rst='1')then
                rd_beat <= 0;
            else
                if state_rd=IDLE and rd_en='0' then
                    rd_beat <= 0;
                elsif(rd_beat<PAYLOAD_STATUS_SIZE_BYTES and rd_en='1') then
                    rd_beat <= rd_beat + 1;
                end if;
            end if;
        end if;
    end process;


    -----------------------------------------------------------
    -- FIFO Status logic
    -----------------------------------------------------------
    process(rd_clk)begin
        if rising_edge(rd_clk)then
            error_status(0) <= fifo_full_since_pwr_on;
            error_status(1) <= fifo_full_since_pkt;
            error_status(2) <= err_val_too_soon_sticky; --async OK
            error_status(3) <= '0';
            error_status(7 downto 4) <= s_user_error;   --async OK
         end if;
    end process;

    process(rd_clk)begin
        if rising_edge(rd_clk)then
            rd_full_meta <= wfull;
            rd_full <= rd_full_meta;
        end if;
    end process;

    process(rd_clk)begin
        if rising_edge(rd_clk) then
            if(rd_rst='1')then
                fifo_full_since_pkt <= '0';
            else
                fifo_full_since_pwr_on  <= rd_full;
                fifo_full_since_pkt     <= rd_full;

                if(rd_beat=4)then
                    fifo_full_since_pkt <= '0';
                end if;
            end if;
        end if;
    end process;


    -------------------------------------------------------------------------------------
    -- State Machine for Packet Data Header Payload Status AND stream payload data
    --      STATUS is the payload header
    --      FIFO is reading out of fifo the payload stream data
    -------------------------------------------------------------------------------------
    process(rd_clk)begin
        if rising_edge(rd_clk) then
            if(rd_rst='1')then
                state_rd <= IDLE;
            else
                case(state_rd)is
                    when IDLE =>
                        if(rd_en='1')then
                            state_rd <= STATUS;
                        end if;
                    when STATUS => -- indicates rd_data to ethernet is status payload header
                        if(rd_beat=(PAYLOAD_STATUS_SIZE_BYTES-1))then
                            state_rd <= FIFO;
                        end if;
                    when FIFO =>   -- indicates rd_data to ethernet is fifo payload data
                        if(rd_en='0' and rd_byte_sel=FIFO_BYTE_WIDTH-1)then --wait until entire 32-bit word is read before finishing
                            state_rd <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;


    process(rd_clk)begin
        if rising_edge(rd_clk) then
            -- Register and hold the FIFO available (total-depth) at the start of the packet readout 
            if(rd_beat=4)then -- latest possible time to check the depth before we need to send it
                fifo_available_held(FIFO_ADDR_WIDTH downto 0) <= std_logic_vector(unsigned(FIFO_TOTAL_CAPACITY) - unsigned(rd_depth));
            end if;

            -- Register and hold the system time at the start of the packet read out
            if(rd_beat=7)then -- latest possible time to register the system time before we need to send it
                sys_time_held <= sys_time;
            end if;
        end if;
    end process;


END;
