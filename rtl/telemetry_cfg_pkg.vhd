-----------------------------------------
-- Auto-generated Telemetry Configuration Package from telem_cfg_csv_to_pkg.py
--   
----------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

package telemetry_cfg_pkg is

    type t_stream_ints is array (0 to 19) of natural;
    type t_stream_bool is array (0 to 19) of boolean;

    constant TELEMETRY_VERSION           : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(5,8));
    constant PORT_DEST_STREAM_BASE       : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(5000,16));
    constant PORT_DEST_CONFIG            : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(4999,16));
    constant FIELD_ENABLE_SIZE_BYTES     : natural := 4;
    constant MAX_NUM_FIELDS_PER_STREAM   : natural := 128;
    constant MAX_NUM_STREAMS             : natural := 20;
    constant ROUND_ROBIN_ITEMS           : natural := 21;
    constant STREAM_MAX_BYTES            : natural := 256;
    constant TIMESTAMP_SIZE_BYTES        : natural := 4;
    constant PAYLOAD_STATUS_SIZE_BYTES   : natural := 12;
    constant STREAM_USER_ERROR_BITS      : natural := 4;

    constant getStreamNumFields          : t_stream_ints := (11,2,2,12,8,10,2,2,2,2,2,2,7,2,2,5,2,0,0,0);
    constant getStreamTotalBytes         : t_stream_ints := (44,8,8,48,32,40,8,8,8,8,8,8,28,8,8,20,8,0,0,0);
    -- use SLeft for indexing a stream data input e.g. stream_data(sleft(STREAM_ID_O) donwto 0) <= data;
    constant SLeft                       : t_stream_ints := (351,63,63,383,255,319,63,63,63,63,63,63,223,63,63,159,63,0,0,0);
    constant getStreamNumFifoWords       : t_stream_ints := (1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0);
    constant getStreamFifoDepthThreshold : t_stream_ints := (11,2,2,12,360,360,2,2,2,2,2,2,7,2,2,5,2,0,0,0);
    constant getNumActiveStreams         : natural := 17;
    constant getFifoAddrWidths           : t_stream_ints := (12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12);
    constant getFifoDataWidths           : t_stream_ints := (32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,8,8,8);
    constant getStreamFifoSDataWidth     : t_stream_ints := (32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,0,0,0);

    type t_pkt_sizes is array (0 to ROUND_ROBIN_ITEMS-1) of integer; -- each stream plus 1 or more cfg pkts
    constant PktPayloadSizeBytes : t_pkt_sizes := (56,20,20,60,1452,1452,20,20,20,20,20,20,40,20,20,32,20,0,0,0,1149);

    type t_stream_clks       is array (0 to MAX_NUM_STREAMS-1) of std_logic;
    type t_stream_valids     is array (0 to MAX_NUM_STREAMS-1) of std_logic;
    type t_stream_enables    is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(FIELD_ENABLE_SIZE_BYTES*8-1 downto 0);
    type t_stream_data       is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(STREAM_MAX_BYTES*8-1 downto 0);
    type t_stream_ts         is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(TIMESTAMP_SIZE_BYTES*8-1 downto 0);
    type t_stream_user_error is array (0 to MAX_NUM_STREAMS-1) of std_logic_vector(STREAM_USER_ERROR_BITS-1 downto 0);

    constant stream_data_init       :  t_stream_data    := (others => (others => '0'));
    constant stream_valids_init     :  t_stream_valids  := (others => '0');
    constant stream_clks_init       :  t_stream_clks    := (others => '0');
    constant stream_enables_init    :  t_stream_enables := (others => (others=>'0'));
    constant stream_user_error_init :  t_stream_user_error := (others => (others=>'0'));
    constant stream_ts_init         :  t_stream_ts      := (others => (others=>'0'));

    -- Stream ID constants that can be used to index stream_data, stream_valids, and stream_clks in rtl interface.
    constant S_symR : natural := 0;
    constant S_nul0 : natural := 1;
    constant S_nul1 : natural := 2;
    constant S_rxbp : natural := 3;
    constant S_mcau : natural := 4;
    constant S_asrc : natural := 5;
    constant S_nul6 : natural := 6;
    constant S_nul7 : natural := 7;
    constant S_nul8 : natural := 8;
    constant S_nul9 : natural := 9;
    constant S_nulA : natural := 10;
    constant S_nulB : natural := 11;
    constant S_agc  : natural := 12;
    constant S_nulD : natural := 13;
    constant S_nulE : natural := 14;
    constant S_META : natural := 15;
    constant S_FALT : natural := 16;

    -- The ROM memory that holds the cfg packet payload
        type t_cfg_rom     is array (0 to 1149-1) of std_logic_vector(7 downto 0);
        constant CONFIG_PKT_ROM           : t_cfg_rom := (
         x"be",x"ef",x"d0",x"0d",x"05",x"01",x"04",x"08",x"04",x"00",x"00",x"00",x"00",x"00",x"00",x"00"
        ,x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"98",x"73",x"79",x"6d",x"52",x"13",x"88",x"54",x"49"
        ,x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"72",x"78",x"30",x"5f",x"69"
        ,x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"72",x"78",x"30",x"5f",x"71",x"20",x"20",x"20"
        ,x"04",x"53",x"49",x"4e",x"54",x"72",x"78",x"31",x"5f",x"69",x"20",x"20",x"20",x"04",x"53",x"49"
        ,x"4e",x"54",x"72",x"78",x"31",x"5f",x"71",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"65"
        ,x"71",x"30",x"5f",x"69",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"65",x"71",x"30",x"5f"
        ,x"71",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"65",x"71",x"31",x"5f",x"69",x"20",x"20"
        ,x"20",x"04",x"53",x"49",x"4e",x"54",x"65",x"71",x"31",x"5f",x"71",x"20",x"20",x"20",x"04",x"53"
        ,x"49",x"4e",x"54",x"65",x"71",x"30",x"5f",x"6d",x"73",x"65",x"20",x"04",x"53",x"49",x"4e",x"54"
        ,x"65",x"71",x"31",x"5f",x"6d",x"73",x"65",x"20",x"04",x"53",x"49",x"4e",x"54",x"01",x"00",x"23"
        ,x"6e",x"75",x"6c",x"30",x"13",x"89",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55"
        ,x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54"
        ,x"02",x"00",x"23",x"6e",x"75",x"6c",x"31",x"13",x"8a",x"54",x"49",x"4d",x"45",x"20",x"20",x"20"
        ,x"20",x"04",x"55",x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53"
        ,x"49",x"4e",x"54",x"03",x"00",x"a5",x"72",x"78",x"62",x"70",x"13",x"8b",x"54",x"49",x"4d",x"45"
        ,x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"63",x"72",x"73",x"5f",x"4e",x"65",x"72"
        ,x"72",x"04",x"55",x"49",x"4e",x"54",x"73",x"66",x"5f",x"4e",x"65",x"72",x"72",x"20",x"04",x"55"
        ,x"49",x"4e",x"54",x"63",x"72",x"73",x"5f",x"63",x"72",x"63",x"46",x"04",x"55",x"49",x"4e",x"54"
        ,x"73",x"66",x"5f",x"63",x"72",x"63",x"46",x"20",x"04",x"55",x"49",x"4e",x"54",x"73",x"75",x"62"
        ,x"66",x"5f",x"69",x"64",x"78",x"04",x"55",x"49",x"4e",x"54",x"66",x"72",x"6d",x"5f",x"72",x"65"
        ,x"66",x"20",x"04",x"55",x"49",x"4e",x"54",x"66",x"72",x"6d",x"5f",x"73",x"66",x"20",x"20",x"04"
        ,x"55",x"49",x"4e",x"54",x"66",x"72",x"6d",x"5f",x"74",x"79",x"70",x"65",x"04",x"55",x"49",x"4e"
        ,x"54",x"73",x"66",x"5f",x"6c",x"6f",x"63",x"6b",x"64",x"04",x"55",x"49",x"4e",x"54",x"73",x"66"
        ,x"5f",x"69",x"64",x"78",x"30",x"20",x"04",x"55",x"49",x"4e",x"54",x"61",x"75",x"64",x"69",x"6f"
        ,x"5f",x"65",x"6e",x"04",x"55",x"49",x"4e",x"54",x"04",x"00",x"71",x"6d",x"63",x"61",x"75",x"13"
        ,x"8c",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"63",x"6f"
        ,x"64",x"65",x"77",x"6f",x"72",x"64",x"04",x"55",x"49",x"4e",x"54",x"53",x"46",x"63",x"77",x"20"
        ,x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"61",x"6c",x"6c",x"6f",x"63",x"20",x"20",x"20"
        ,x"04",x"55",x"49",x"4e",x"54",x"6c",x"6c",x"72",x"6d",x"69",x"6e",x"20",x"20",x"04",x"55",x"49"
        ,x"4e",x"54",x"53",x"46",x"6c",x"6c",x"72",x"6d",x"69",x"6e",x"04",x"55",x"49",x"4e",x"54",x"6d"
        ,x"75",x"74",x"65",x"5f",x"73",x"74",x"61",x"04",x"55",x"49",x"4e",x"54",x"66",x"69",x"66",x"6f"
        ,x"5f",x"66",x"75",x"6c",x"04",x"55",x"49",x"4e",x"54",x"05",x"00",x"8b",x"61",x"73",x"72",x"63"
        ,x"13",x"8d",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"61"
        ,x"75",x"64",x"69",x"6f",x"5f",x"4c",x"20",x"04",x"53",x"49",x"4e",x"54",x"61",x"75",x"64",x"69"
        ,x"6f",x"5f",x"52",x"20",x"04",x"53",x"49",x"4e",x"54",x"6d",x"64",x"5f",x"72",x"61",x"74",x"69"
        ,x"6f",x"04",x"55",x"49",x"4e",x"54",x"69",x"6e",x"5f",x"49",x"5f",x"6c",x"76",x"6c",x"04",x"55"
        ,x"49",x"4e",x"54",x"6c",x"69",x"6e",x"5f",x"69",x"6e",x"74",x"20",x"04",x"55",x"49",x"4e",x"54"
        ,x"6f",x"75",x"74",x"5f",x"6d",x"69",x"6e",x"20",x"04",x"55",x"49",x"4e",x"54",x"64",x"65",x"62"
        ,x"75",x"67",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"6f",x"75",x"74",x"5f",x"6c",x"76"
        ,x"6c",x"20",x"04",x"55",x"49",x"4e",x"54",x"66",x"69",x"66",x"6f",x"5f",x"65",x"72",x"72",x"04"
        ,x"55",x"49",x"4e",x"54",x"06",x"00",x"23",x"6e",x"75",x"6c",x"36",x"13",x"8e",x"54",x"49",x"4d"
        ,x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20"
        ,x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"07",x"00",x"23",x"6e",x"75",x"6c",x"37",x"13",x"8f"
        ,x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"4e",x"55",x"4c"
        ,x"4c",x"20",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"08",x"00",x"23",x"6e",x"75",x"6c"
        ,x"38",x"13",x"90",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54"
        ,x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"09",x"00",x"23"
        ,x"6e",x"75",x"6c",x"39",x"13",x"91",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55"
        ,x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54"
        ,x"0a",x"00",x"23",x"6e",x"75",x"6c",x"41",x"13",x"92",x"54",x"49",x"4d",x"45",x"20",x"20",x"20"
        ,x"20",x"04",x"55",x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53"
        ,x"49",x"4e",x"54",x"0b",x"00",x"23",x"6e",x"75",x"6c",x"42",x"13",x"93",x"54",x"49",x"4d",x"45"
        ,x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20"
        ,x"20",x"04",x"53",x"49",x"4e",x"54",x"0c",x"00",x"64",x"61",x"67",x"63",x"20",x"13",x"94",x"54"
        ,x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"61",x"64",x"63",x"30"
        ,x"5f",x"6c",x"76",x"6c",x"04",x"55",x"49",x"4e",x"54",x"61",x"64",x"63",x"31",x"5f",x"6c",x"76"
        ,x"6c",x"04",x"55",x"49",x"4e",x"54",x"61",x"74",x"74",x"30",x"5f",x"72",x"66",x"20",x"04",x"55"
        ,x"49",x"4e",x"54",x"61",x"74",x"74",x"31",x"5f",x"72",x"66",x"20",x"04",x"55",x"49",x"4e",x"54"
        ,x"61",x"74",x"74",x"30",x"5f",x"69",x"66",x"20",x"04",x"55",x"49",x"4e",x"54",x"61",x"74",x"74"
        ,x"31",x"5f",x"69",x"66",x"20",x"04",x"55",x"49",x"4e",x"54",x"0d",x"00",x"23",x"6e",x"75",x"6c"
        ,x"44",x"13",x"95",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54"
        ,x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54",x"0e",x"00",x"23"
        ,x"6e",x"75",x"6c",x"45",x"13",x"96",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55"
        ,x"49",x"4e",x"54",x"4e",x"55",x"4c",x"4c",x"20",x"20",x"20",x"20",x"04",x"53",x"49",x"4e",x"54"
        ,x"0f",x"00",x"4a",x"4d",x"45",x"54",x"41",x"13",x"97",x"54",x"49",x"4d",x"45",x"20",x"20",x"20"
        ,x"20",x"04",x"55",x"49",x"4e",x"54",x"52",x"58",x"42",x"55",x"49",x"4c",x"44",x"20",x"04",x"55"
        ,x"49",x"4e",x"54",x"52",x"58",x"44",x"41",x"54",x"45",x"20",x"20",x"04",x"55",x"49",x"4e",x"54"
        ,x"52",x"58",x"54",x"49",x"4d",x"45",x"20",x"20",x"04",x"55",x"49",x"4e",x"54",x"74",x"69",x"6d"
        ,x"65",x"5f",x"73",x"63",x"6c",x"04",x"46",x"4c",x"54",x"20",x"10",x"00",x"23",x"46",x"41",x"4c"
        ,x"54",x"13",x"98",x"54",x"49",x"4d",x"45",x"20",x"20",x"20",x"20",x"04",x"55",x"49",x"4e",x"54"
        ,x"46",x"41",x"55",x"4c",x"54",x"5f",x"49",x"44",x"04",x"55",x"49",x"4e",x"54");


end telemetry_cfg_pkg;

package body telemetry_cfg_pkg is
end telemetry_cfg_pkg;
