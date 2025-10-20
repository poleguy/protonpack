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

use work.telemetry_cfg_pkg.all;

package tb_telemetry_pkg is

    procedure LOG(str: in string);

    procedure stream_source(
        signal clk : out std_logic;
        signal valid : out std_logic;
        signal enable : out std_logic_vector;
        signal data : out std_logic_vector;
        stream_num : in integer;
        clk_period : in time;
        frame_clk_period : in integer);

    procedure print_config_rom (rom : t_cfg_rom);

    procedure capture_pcapng(cap_file : string;
                            signal tx_en : in std_logic;
                            signal tx_data : in std_logic_vector(7 downto 0);
                            signal clk : in std_logic
                            );
    
    shared variable capture_pcapng_first_call : boolean := true;
        
end package;

package body tb_telemetry_pkg is

    procedure LOG(str: in string) is
		variable outline: LINE;
	begin
		WRITE(outline,'(');
		WRITE(outline,now);
		WRITE(outline,string'(") "));
		WRITE(outline,string'(str));
		WRITELINE(output,outline);
	end procedure;

    procedure stream_source(
        signal clk : out std_logic;
        signal valid : out std_logic;
        signal enable : out std_logic_vector;
        signal data : out std_logic_vector;
        stream_num : in integer;
        clk_period : in time;
        frame_clk_period : in integer) is

        variable data_var : std_logic_vector(getStreamTotalBytes(stream_num)*8-1 downto 0);
        variable en_var : std_logic_vector(getStreamNumFields(stream_num)-1 downto 0) := (others => '1');
        variable clk_cnt : integer := 0;

        variable frame_cnt : std_logic_vector(3 downto 0) := (others => '0');
        variable cnt_up_slv : std_logic_vector(31  downto 0) := (others=>'0');
        variable cnt_dn_slv : std_logic_vector(31 downto 0):= (others=>'0');
        variable cnt_sel : std_logic_vector(31 downto 0):= (others=>'0');

        variable field_width : integer;
        variable next_start : integer := 0;

    begin
        while(true)loop
            wait for clk_period/2;
            clk<='0';
            wait for clk_period/2;

            clk<='1';
            if(clk_cnt = frame_clk_period-1)then
                next_start := 0;
                data_var := (others => '0');
                --for ii in 0 to getStreamTotalBytes(stream_num)-1 loop
                --    data_var((ii*8)+7 downto (ii*8)):= frame_cnt & std_logic_vector(to_unsigned(ii,4));
                --end loop;
                for ii in 0 to getStreamNumFields(stream_num) loop
                   field_width:=8*getStreamFieldBytes(stream_num,ii);
                   if(ii mod 2=0)then
                       cnt_sel := cnt_up_slv+std_logic_vector(to_unsigned(ii,32));  -- add ii for some difference between fields when more than 2
                   else
                       cnt_sel := cnt_dn_slv+std_logic_vector(to_unsigned(ii,32));
                   end if;

                   data_var(next_start+field_width-1 downto next_start) := cnt_sel(field_width-1 downto 0);


                   next_start := next_start+field_width;
                end loop;

                data(data_var'left downto 0) <= data_var;
                valid <= '1';
                enable(enable'left downto en_var'left+1) <= (others => '0');
                enable(en_var'left downto 0) <= en_var;
                clk_cnt := 0;
               -- frame_cnt := frame_cnt + 1;
                cnt_up_slv := cnt_up_slv + '1';
                cnt_dn_slv := cnt_dn_slv - '1';
            else
                valid <= '0';
                clk_cnt := clk_cnt + 1;
            end if;
        end loop;
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
    procedure capture_pcapng(cap_file : string;
                            signal tx_en : in std_logic;
                            signal tx_data : in std_logic_vector(7 downto 0);
                            signal clk : in std_logic
                            ) is
           type char_file is file of character;
           file fp : char_file;
           variable char : character;
           variable byte : std_logic_vector(7 downto 0);
           type t_char_array is array (0 to 3) of character;
           variable bl : integer := 0;
           type t_bl_bytes is array (0 to 3) of integer;
           variable bl_bytes : t_bl_bytes;
           variable cap_bytes : t_bl_bytes;
           variable bl_temp : integer;
           type t_buff is array (0 to 1600) of std_logic_vector(7 downto 0);
           variable buff : t_buff;
           variable bcnt : integer := 0;
           variable bcnt2 : integer := 0;
            variable align_append : integer := 0;

    variable bl_sub : integer;
    begin
           if(capture_pcapng_first_call)then
               file_open (fp, cap_file, write_mode);
               --bolck type section header
               write(fp, character'val(16#0A#));
               write(fp, character'val(16#0D#));
               write(fp, character'val(16#0D#));
               write(fp, character'val(16#0A#));
               --block Total Length
               bl := 28;
               write(fp, character'val(bl));
               write(fp, character'val(0));
               write(fp, character'val(0));
               write(fp, character'val(0));
               --Byte Order Magic
               write(fp, character'val(16#4D#));
               write(fp, character'val(16#3C#));
               write(fp, character'val(16#2B#));
               write(fp, character'val(16#1A#));
               --Major Number
               write(fp, character'val(1));
               write(fp, character'val(0));
               --Minor Version and Section Length
               for i in 0 to 10-1 loop
                   write(fp, character'val(0));
               end loop;
               --Block Length
               write(fp, character'val(bl));
               write(fp, character'val(0));
               write(fp, character'val(0));
               write(fp, character'val(0));

               --Block Type
               write(fp, character'val(1));
               write(fp, character'val(0));
               write(fp, character'val(0));
               write(fp, character'val(0));
               --Block Length
               write(fp, character'val(20));
               write(fp, character'val(0));
               write(fp, character'val(0));
               write(fp, character'val(0));
               --Link Type
               write(fp, character'val(1));
               write(fp, character'val(0));
               write(fp, character'val(0));
               write(fp, character'val(0));
               --SnapLen
               write(fp, character'val(16#FF#));
               write(fp, character'val(16#FF#));
               write(fp, character'val(16#FF#));
               write(fp, character'val(16#FF#));
               --Block Length
               write(fp, character'val(20));
               write(fp, character'val(0));
               write(fp, character'val(0));
               write(fp, character'val(0));
               file_close(fp);
               capture_pcapng_first_call := false;
           end if;


           -- capture the gmii data in a buffer
           -- have to buffer to know the length before writing
           -- to file
          -- LOG("START THE GMII WAIT");
           wait until rising_edge(tx_en);
           wait until rising_edge(clk);
           while (tx_en='1') loop
               buff(bcnt):=tx_data;
               bcnt := bcnt+1;
               wait until rising_edge(clk);
           end loop;

           bcnt2 := bcnt - 8 -4 ;

           -- open already created file
           file_open (fp, cap_file, append_mode);

           -- calculate the block length bytes
           bl_temp := 28 + bcnt2 +4; --block header + packet data + block length
          -- LOG("bl_temp (pre-align)="&integer'image(bl_temp));
           align_append:=0;
           if( (bl_temp mod 4) /=0 )then
               align_append := 4-(bl_temp mod 4);
               bl_temp := bl_temp + align_append;
           end if;
          -- LOG("bl_temp (post-align)="&integer'image(bl_temp));
           for p in 3 downto 0 loop
             bl_bytes(p) := bl_temp / 2**((p)*8);   
             bl_sub := bl_bytes(p)*(2**((p)*8));
             bl_temp := bl_temp - bl_sub;
           --  LOG("bl_bytes("&integer'image(p)&")="&integer'image(bl_bytes(p)));
           end loop;
           -- calculate the capture/pkt length bytes
           bl_temp := bcnt2;
           for p in 3 downto 0 loop
             cap_bytes(p) := bl_temp / 2**((p)*8);   
             bl_sub := cap_bytes(p)*(2**((p)*8));
             bl_temp := bl_temp - bl_sub;
           end loop;

          -- LOG("bcnt = "&integer'image(bcnt));
          -- LOG("bcnt2 = "&integer'image(bcnt2));

           --Block Type 6 - enhanced packet mode
           write(fp, character'val(6));
           write(fp, character'val(0));
           write(fp, character'val(0));
           write(fp, character'val(0));

           --write(fp, character'val(212));
           for p in 0 to 3 loop
          --   LOG("bl_bytes("&integer'image(p)&")="&integer'image(bl_bytes(p)));
             write(fp, character'val(bl_bytes(p))); 
           end loop;
           -- interface ID, Timestamp H, Timestamp L
           for p in 0 to 11 loop
               write(fp, character'val(0));
           end loop;
           --capture length
           for p in 0 to 3 loop
             write(fp, character'val(cap_bytes(p))); 
           end loop;
           -- packet length
           for p in 0 to 3 loop
             write(fp, character'val(cap_bytes(p))); 
           end loop;
                                 --          char2 := character'val(to_integer(unsigned(byte)));
           --packet data
           for i in 0 to bcnt2-1 loop
             write(fp, character'val(to_integer(unsigned(buff(8+i))))); 
           end loop;

           --write 0 bytes to 32bit word align
           if(align_append>0)then
               for i in 0 to align_append-1 loop
                   write(fp, character'val(0));
               end loop;
           end if;

           --block length at end again
           for p in 0 to 3 loop
             write(fp, character'val(bl_bytes(p))); 
           end loop;

           file_close (fp);
    end procedure;
    

end package body;

