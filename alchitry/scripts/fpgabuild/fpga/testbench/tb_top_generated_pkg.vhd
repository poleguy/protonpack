----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
--
-- Description:  A test package for Telemetry
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

LIBRARY std;
    USE std.textio.all;
      USE std.env.all;                -- for stop()

use work.telemetry_cfg_pkg.all;

package tb_top_generated_pkg is

    procedure LOG(str: in string);

    procedure stream0_source(
        signal clk      : out std_logic;
        signal valid    : out std_logic;
        signal enable   : out std_logic_vector;
        signal data     : out std_logic_vector
        );

    procedure print_config_rom (rom : t_cfg_rom);

    shared variable capture_pcapng_first_call : boolean := true;
        
end package;

package body tb_top_generated_pkg is

    procedure LOG(str: in string) is
		variable outline: LINE;
	begin
		WRITE(outline,'(');
		WRITE(outline,now);
		WRITE(outline,string'(") "));
		WRITE(outline,string'(str));
		WRITELINE(output,outline);
	end procedure;

    procedure stream0_source(
        signal clk      : out std_logic;
        signal valid    : out std_logic;
        signal enable   : out std_logic_vector;
        signal data     : out std_logic_vector
        ) is

        constant clk_period : time := 10 ns;
        constant valid_period_clks : integer := 10;
        constant stream_num : integer := 0;
        constant stream_field : integer := 0;
        file f0             : text open read_mode is "fpga_stream0_field0.stim";

        variable data_var_int : integer;
        variable data_stream_slv : std_logic_vector(getStreamTotalBytes(stream_num)*8-1 downto 0) := (others=>'0');
        variable data_field_slv : std_logic_vector(getStreamFieldBytes(stream_num,stream_field)*8-1 downto 0);
        --variable data_stream_max_slv : std_logic_vector(STREAM_MAX_BYTES*8-1 downto 0) := (others=>'0');
        --variable en_var : std_logic_vector(getStreamNumFields(stream_num)-1 downto 0) := (others => '1');
        variable clk_cnt : integer := 0;

        -- populated by python generated vhdl

        variable v_line : line;


    begin
       enable(31 downto 0) <= X"FFFFFFFF";
       data(data_stream_slv'left downto 0) <= X"00";
       --data(data_stream_slv'left downto 0) <= data_stream_slv;
       while not endfile(f0) loop
           wait for clk_period/2;
           clk<='0';
           wait for clk_period/2;
           clk<='1';

           if(clk_cnt = valid_period_clks-1)then
               readline(f0, v_line);
               read(v_line, data_var_int);
               data_stream_slv := (others=>'0');
               data_field_slv := std_logic_vector(to_unsigned(data_var_int,getStreamFieldBytes(stream_num,stream_field)*8));
               data_stream_slv(data_field_slv'left downto 0) := data_field_slv;
               data(data_stream_slv'left downto 0) <= data_stream_slv;
               valid <= '1' after 1 ps; --delayed FF was registering on same clk in msim so add this to fix... seems like a bug has happened before to me (AS)
               clk_cnt := 0;
           else
               valid <= '0';
               clk_cnt := clk_cnt + 1;
           end if;
        end loop;
        LOG("stream0 stimulus files have ended calling stop to stop the rtl sim");
        wait for 100 us;
        stop(0);
    end procedure;

    procedure print_config_rom (rom : t_cfg_rom) is
        variable words : integer := (rom'length/4);
        variable i : integer := 0;
    begin
        LOG("Cfg Packet ROM output");
        for w in 0 to words-1 loop
            LOG(
            to_hstring(rom((w*4)+0))&
            to_hstring(rom((w*4)+1))&
            to_hstring(rom((w*4)+2))&
            to_hstring(rom((w*4)+3)));
        end loop;
    end procedure;

   -------------------------------------
   -- Example steps for reading from binary file, conv to slv, then write slv to binary file
   -------------------------------------

   -- Keep this...
                                 --  process is
                                 --      type char_file is file of character;
                                 --      file ptr : char_file;
                                 --      file ptr2 : char_file;
                                 --      variable char : character;
                                 --      variable char2 : character;
                                 --      variable byte : std_logic_vector(7 downto 0);
                                 --  begin
                                 --      file_open (ptr, "/home/fpga/data/eth_udp/pkt3", read_mode);
                                 --      file_open (ptr2, "/home/fpga/data/eth_udp/vhdl.bin", write_mode);
                                 --      for ii in 1 to 10 loop
                                 --          read(ptr, char);
                                 --          byte := std_logic_vector(to_unsigned(character'pos(char),8));
                                 --          char2 := character'val(to_integer(unsigned(byte)));
                                 --          write(ptr2, char2);
                                 --          LOG("read binary test="&to_hstring(byte));
                                 --      end loop;
                                 --    file_close(ptr);
                                 --    file_close(ptr2);
                                 --      wait;
                                 --  end process;
    

end package body;

