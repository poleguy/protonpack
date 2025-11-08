-----------------------------------------
-- Generated September 17, 2020  07:04AM
-- Auto-generated Telemetry Configuration Package
--   
----------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

package telemetry_cfg_pkg is

    type t_stream_ints is array (0 to 7) of natural;
    type t_stream_bool is array (0 to 7) of boolean;

    constant TELEMETRY_VERSION           : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(2,8));
    constant STREAM_ID_SIZE_BYTES        : natural := 4;
    constant FIELD_ID_SIZE_BYTES         : natural := 4;
    constant MAX_PKT_UDP_DATA_SIZE_BYTES : t_stream_ints := (1464,1464,1464,1464,1464,1464,1464,1464);
    constant FIELD_LEN_SIZE_BYTES        : natural := 1;
    constant FIELD_ENABLE_SIZE_BYTES     : natural := 4;
    constant FIELD_UNIT_TYPE_SIZE_BYTES  : natural := 4;
    constant MAX_NUM_FIELDS_PER_STREAM   : natural := 32;
    constant MAX_NUM_STREAMS             : natural := 8;
    constant STREAM_MAX_BYTES            : natural := 256;
    constant PORT_SIZE_BYTES             : natural := 2;
    constant TIMESTAMP_SIZE_BYTES        : natural := 4;
    constant PAYLOAD_STATUS_SIZE_BYTES   : natural := 8;

    type t_all_fields_ints is array (0 to MAX_NUM_STREAMS*MAX_NUM_FIELDS_PER_STREAM-1) of natural;
    constant StreamFieldBytes            : t_all_fields_ints := (
         1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

    constant getStreamNumFields          : t_stream_ints := (1,0,0,0,0,0,0,0);
    constant getStreamTotalBytes         : t_stream_ints := (1,0,0,0,0,0,0,0);
    constant getStreamNumFifoWords       : t_stream_ints := (1,0,0,0,0,0,0,0);
    constant getNumActiveStreams         : natural := 1;
    constant getFifoAddrWidths           : t_stream_ints := (12,12,12,12,12,12,12,12);
    constant getFifoDataWidths           : t_stream_ints := (8,8,8,8,8,8,8,8);
    constant getImplicitTS               : t_stream_bool := (True,True,True,True,True,True,True,True);

    impure function getStreamFieldBytes (stream_num : integer; field_num : integer) return integer;

    -- The ROM memory that holds the cfg packet payload
        type t_cfg_rom     is array (0 to 26-1) of std_logic_vector(7 downto 0);
        constant CONFIG_PKT_ROM           : t_cfg_rom := (
         x"be",x"ef",x"d0",x"0d",x"02",x"04",x"04",x"04",x"00",x"00",x"12",x"53",x"54",x"5f",x"30",x"13"
        ,x"88",x"53",x"30",x"46",x"30",x"01",x"75",x"6e",x"69",x"74");

    type t_pkt_sizes is array (0 to MAX_NUM_STREAMS) of integer; --size is MAX_NUM_STREAMS+1 +1 is for config packet size
    constant PktPayloadSizeBytes : t_pkt_sizes := (1463,0,0,0,0,0,0,0,26);

    type t_stream_clks      is array (0 to MAX_NUM_STREAMS-1) of std_logic;
    type t_stream_valids    is array (0 to MAX_NUM_STREAMS-1) of std_logic;
    type t_stream_enables   is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(FIELD_ENABLE_SIZE_BYTES*8-1 downto 0);
    type t_stream_data      is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(STREAM_MAX_BYTES*8-1 downto 0);

    constant stream_data_init    :  t_stream_data    := (others => (others => '0'));
    constant stream_valids_init  :  t_stream_valids  := (others => '0');
    constant stream_clks_init    :  t_stream_clks    := (others => '0');
    constant stream_enables_init :  t_stream_enables := (others => (others=>'0'));

end telemetry_cfg_pkg;

package body telemetry_cfg_pkg is

    impure function getStreamFieldBytes (stream_num : integer; field_num : integer) return integer is
    begin
        return StreamFieldBytes(stream_num*MAX_NUM_FIELDS_PER_STREAM+field_num);
    end;

end telemetry_cfg_pkg;
