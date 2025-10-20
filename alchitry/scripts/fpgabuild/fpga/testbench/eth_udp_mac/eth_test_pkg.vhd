----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
--
-- Description:  A test package for testing Ethernet streams including GMII interface
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

use work.eth_fcs_calc_pkg.all;

package eth_test_pkg is

    procedure LOG(str: in string);

    type bytes is array (integer range <>) of std_logic_vector(7 downto 0);

    type t_pkt_err is record
        all_good        : boolean;
        bad_eth_pre     : boolean;
        bad_eth_type    : boolean;
        bad_eth_len     : boolean;
        bad_ip_hdr      : boolean;
        bad_ip_len      : boolean;
        bad_udp_len     : boolean;
        bad_eth_fcs     : boolean;
        bad_ip_csum     : boolean;
        bad_udp_csum    : boolean;
    end record;

    type t_eth is record                             -- Store all bytes field as big endian (as it is for Eth)
        des_addr    : bytes(5 downto 0);
        src_addr    : bytes(5 downto 0);
        fcs_rx      : bytes(3 downto 0);
        fcs_calc    : bytes(3 downto 0);
    end record;

    type t_ip is record
        len          : bytes(1 downto 0);
        id           : bytes(1 downto 0);
        hdr_csum     : bytes(1 downto 0);
        src_addr     : bytes(3 downto 0);
        des_addr     : bytes(3 downto 0);
    end record;

    type t_udp is record
        src_port    : bytes(1 downto 0);
        des_port    : bytes(1 downto 0);
        len         : bytes(1 downto 0);
        csum        : bytes(1 downto 0);
        data        : bytes(1 downto 0);
        len_pload   : integer;
        payload     : bytes(1500 downto 0);               --configurable size based on UDP length
        pload_cnt   : integer;
        clk_extra   : integer;
    end record;

    type t_pkt is record
        err             : t_pkt_err;
        eth             : t_eth;
        ip              : t_ip;
        udp             : t_udp;
    end record;

    procedure decode_gmii(
         signal clk     : in std_logic;
         signal txd_en  : in std_logic;
         signal txd     : in std_logic_vector(7 downto 0);
         chk_test_pload : in boolean;
         decoded_pkt    : out t_pkt;
         errors         : inout integer);

    procedure display_pkt(
        pkt : in t_pkt);

    procedure encode_gmii(
        signal clk         : in std_logic;
        signal mac_gmii_en : in std_logic;
        mac_dest           : in std_logic_vector(47 downto 0);
        mac_src            : in std_logic_vector(47 downto 0);
        ip_src             : in std_logic_vector(31 downto 0);
        ip_dest            : in std_logic_vector(31 downto 0);
        udp_src            : in std_logic_vector(15 downto 0);
        udp_dest           : in std_logic_vector(15 downto 0);
        pkt_bytes          : in std_logic_vector(15 downto 0);
        signal rxd_en      : out std_logic;
        signal rxd         : out std_logic_vector(7 downto 0);
        signal done        : out std_logic;
        test               : in string;
        pkt_out            : out t_pkt);

    procedure decode_axis(
        signal clk         : in std_logic;
        pkt                : in t_pkt;
        signal tdata       : in std_logic_vector(7 downto 0);
        signal tvalid      : in std_logic;
        signal tlast       : in std_logic;
        signal tready      : out std_logic;
        signal mac_src     : in std_logic_vector(47 downto 0);
        signal ip_id       : in std_logic_vector(15 downto 0);
        signal payload_len : in std_logic_vector(15 downto 0);
        signal ip_src      : in std_logic_vector(31 downto 0);
        signal udp_dest    : in std_logic_vector(15 downto 0);
        signal udp_src     : in std_logic_vector(15 downto 0);
        test_pass          : out boolean);

    procedure decode_reg(
        signal clk         : in  std_logic;
        signal tdata       : in  std_logic_vector(7 downto 0);
        signal tvalid      : in  std_logic;
        signal tlast       : in  std_logic;
        signal tready      : in  std_logic;
        signal reg_data_rd : out std_logic_vector(31 downto 0);
        signal reg_data_wr : in  std_logic_vector(31 downto 0);
        signal reg_addr    : in  std_logic_vector(23 downto 0);
        signal reg_re      : in  std_logic;
        signal reg_wr      : in  std_logic;
        signal reg_tdata   : in  std_logic_vector(7 downto 0);
        signal reg_tvalid  : in  std_logic;
        signal reg_tlast   : in  std_logic;
        signal reg_tready  : out std_logic;
        test_pass          : out boolean);

    shared variable crc32_lfsr : std_logic_vector(31 downto 0) := (others => '0');
    shared variable chk_pload : boolean := False;

    constant REG_RD_TYPE : std_logic_vector(7 downto 0) := x"01";
    constant REG_WR_TYPE : std_logic_vector(7 downto 0) := x"10";

end package;

package body eth_test_pkg is

    procedure LOG(str: in string) is
		variable outline: LINE;
	begin
		WRITE(outline,'(');
		WRITE(outline,now);
		WRITE(outline,string'(") "));
		WRITE(outline,string'(str));
		WRITELINE(output,outline);
	end procedure;

    function bytes_to_str (
        data_in : in bytes
    )
    return string is
        variable s : string(1 to 2*data_in'length);
    begin
        for ii in data_in'right to data_in'left loop
            s(((ii-data_in'right)*2)+1 to ((ii-data_in'right)*2)+2):=to_hstring(data_in(ii));
        end loop;
        return s;
    end;

    function bytes_to_int (
        data_in : in bytes
    )
    return integer is
        variable int : integer;
    begin
        int := 0;
        for ii in 0 to data_in'length-1 loop
            int := int + to_integer(unsigned(data_in(data_in'left-ii)))*(2**(8*ii));
        end loop;
        return int;
    end;

    procedure display_pkt(
        pkt : in t_pkt)
    is
        variable outline: LINE;
        variable bytes_remain : natural;
        variable display_bytes_per_line : natural := 8;
    begin
        LOG("----------------------  Ethernet Packet Display ----------------------");
        LOG("");
        LOG("  <<< Eth Type II >>>");
        LOG("      Mac Src Addr: 0x"&bytes_to_str(pkt.eth.src_addr)&"    Mac Des Addr: 0x"&bytes_to_str(pkt.eth.des_addr));
        LOG("      <<< IPv4 >>>");
        LOG("          Src Addr: 0x"&bytes_to_str(pkt.ip.src_addr)&"    Des Addr: 0x"&bytes_to_str(pkt.ip.des_addr));
        LOG("          ID: 0x"&bytes_to_str(pkt.ip.id)&"    Length: "&to_string(bytes_to_int(pkt.ip.len))&"    Hdr Checksum: 0x"&bytes_to_str(pkt.ip.hdr_csum));
        LOG("          <<< UDP >>>");
        LOG("             Src Port: "&to_string(bytes_to_int(pkt.udp.src_port))&"    Des Port: "&to_string(bytes_to_int(pkt.udp.des_port)));
        LOG("             Length: "&to_string(bytes_to_int(pkt.udp.len))&"    UDP Checksum: 0x"&bytes_to_str(pkt.udp.csum));
        LOG("             Payload Data ("&to_string(pkt.udp.len_pload)&" bytes):");
        bytes_remain:=pkt.udp.len_pload;
        while(bytes_remain>=display_bytes_per_line)loop
            -- write the raw udp payload bytes
            bytes_remain := bytes_remain - display_bytes_per_line;
            WRITE(outline,'(');
            WRITE(outline,now);
            WRITE(outline,string'(") "));
            WRITE(outline,string'("                     "));
            WRITE(outline,bytes_to_str(pkt.udp.payload(pkt.udp.len_pload-bytes_remain-1 downto pkt.udp.len_pload-bytes_remain-display_bytes_per_line)));
            WRITELINE(output,outline);
        end loop;
        if(bytes_remain > 0)then
            WRITE(outline,'(');
            WRITE(outline,now);
            WRITE(outline,string'(") "));
            WRITE(outline,string'("                     "));
            WRITE(outline,bytes_to_str(pkt.udp.payload(pkt.udp.len_pload-1 downto pkt.udp.len_pload-bytes_remain)));
            WRITELINE(output,outline);
        end if;
        LOG("  <<< ETH FCS CRC-32 >>>   Rx: 0x"&bytes_to_str(pkt.eth.fcs_rx));
        LOG("                         Calc: 0x"&bytes_to_str(pkt.eth.fcs_calc));
        LOG("");
        if(pkt.err.all_good=True)then
        LOG("Packet passed - no issues detected.");
        else
        LOG("PACKET ERRORS DETECTED!!! error status:");
        LOG("    bad_eth_pre:  "&to_string(pkt.err.bad_eth_pre));
        LOG("    bad_eth_type: "&to_string(pkt.err.bad_eth_type));
        LOG("    bad_eth_len:  "&to_string(pkt.err.bad_eth_len));
        LOG("    bad_ip_hdr:   "&to_string(pkt.err.bad_ip_hdr));
        LOG("    bad_ip_len:   "&to_string(pkt.err.bad_ip_len));
        LOG("    bad_udp_len:  "&to_string(pkt.err.bad_udp_len));
        LOG("    bad_eth_fcs:  "&to_string(pkt.err.bad_eth_fcs));
        LOG("    bad_ip_csum:  "&to_string(pkt.err.bad_ip_csum));
        LOG("    bad_udp_csum: "&to_string(pkt.err.bad_udp_csum));
        end if;
        LOG("----------------------------------------------------------------------");
    end procedure;

----------------------------------------------------------------------------------
-- Procedures for TX side of MAC
----------------------------------------------------------------------------------

    procedure decode_udp(
         signal txd     : in std_logic_vector(7 downto 0);
         v_ip           : in integer;
         done           : out boolean;
         pkt            : inout t_pkt;
         errors         : inout integer)
    is
        variable v : integer;
        variable pload_cnt : integer;
        variable id_int : integer;
    begin
        v:=v_ip - 20;
        if(v=0)then
            pkt.udp.src_port(0) := txd;  -- store big endian
        elsif(v=1)then
            pkt.udp.src_port(1) := txd;
        elsif(v=2)then
            pkt.udp.des_port(0) := txd;
        elsif(v=3)then
            pkt.udp.des_port(1) := txd;
        elsif(v=4)then
            pkt.udp.len(0) := txd;
        elsif(v=5)then
            pkt.udp.len(1) := txd;
        elsif(v=6)then
            if(bytes_to_int(pkt.udp.len) < 16)then
                errors:=errors+1;
                LOG("*!* ERROR: decode_udp bytes 4,5 UDP length expected at least 16 received "&(bytes_to_str((pkt.udp.len))));
            end if;
            pkt.udp.len_pload := bytes_to_int(pkt.udp.len) - 8;
            pkt.udp.pload_cnt := 0; --pkt.udp.len_pload; --initialize for new packet
            pkt.udp.csum(0) := txd;
        elsif(v=7)then
            pkt.udp.csum(1) := txd;
        elsif(pkt.udp.pload_cnt < pkt.udp.len_pload)then
            pkt.udp.payload(pkt.udp.pload_cnt):=txd;
            ---- check payload ----
            if(chk_pload)then
                if(pkt.udp.pload_cnt<=3 and pkt.udp.pload_cnt>1)then
                     if(pkt.udp.payload(pkt.udp.pload_cnt)/=pkt.ip.id(pkt.udp.pload_cnt-2))then
                         LOG("Error payload pattern byte "&to_string(pkt.udp.pload_cnt)&" data received "&to_hstring(pkt.udp.payload(pkt.udp.pload_cnt))&" expected "&to_hstring(pkt.ip.id(3-pkt.udp.pload_cnt)));
                         errors:=errors+1;
                     end if;
                elsif(pkt.udp.pload_cnt>3)then
                    id_int:=conv_integer(pkt.ip.id(0))*2**8+conv_integer(pkt.ip.id(1));
                    if(pkt.udp.payload(pkt.udp.pload_cnt)/= ((id_int+pkt.udp.pload_cnt-4) mod 256))then
                         LOG("Error payload pattern byte "&to_string(pkt.udp.pload_cnt)&" data received "&to_string(conv_integer(pkt.udp.payload(pkt.udp.pload_cnt)))&" expected "&to_string(id_int+pkt.udp.pload_cnt-4));
                         errors:=errors+1;
                    end if;
                end if;
            end if;
            --------------------------
            pkt.udp.pload_cnt:=pkt.udp.pload_cnt+1;
        else
            pkt.udp.clk_extra:=pkt.udp.clk_extra + 1;
        end if;

        if(pkt.udp.pload_cnt < pkt.udp.len_pload or v <=7)then
            done := False;
        else
            done := True;
        end if;
        --if(pkt.udp.pload_cnt<=1)then
        --      LOG("first 2 bytes");

    end procedure;

    procedure decode_ip(
         signal txd     : in std_logic_vector(7 downto 0);
         v_eth          : in integer;
         done           : out boolean;
         pkt            : inout t_pkt;
         errors         : inout integer)
    is
        variable v : integer;
    begin
        v:=v_eth-22;
        if(v=0)then
            if(txd/=X"45")then
                pkt.err.bad_ip_hdr:=True;
                errors:=errors+1;
                LOG("*!* ERROR: decode_ip byte 0 ver,hdr expected x45 received "&to_string(txd));
            end if;
        elsif(v=1)then
            if(txd/=X"00")then
                pkt.err.bad_ip_hdr:=True;
                errors:=errors+1;
                LOG("*!* ERROR: decode_ip byte 1 diff serv expected x00 received "&to_string(txd));
            end if;
        elsif(v=2)then
            pkt.ip.len(0) := txd;
        elsif(v=3)then
            pkt.ip.len(1) := txd;
        elsif(v=4)then
            if(bytes_to_int(pkt.ip.len) < 20)then
                errors:=errors+1;
                LOG("*!* ERROR: decode_ip bytes 2,3 IP length expected at least 20 received "&bytes_to_str(pkt.ip.len));
            end if;
            pkt.ip.id(0) := txd;
        elsif(v=5)then
            pkt.ip.id(1) := txd;
        elsif(v<=8)then
            if(txd/=X"00")then
                pkt.err.bad_ip_hdr:=True;
                errors:=errors+1;
                LOG("*!* ERROR: decode_ip byte "&to_string(v)&" IP length expected x00 received "&to_string(txd));
            end if;
        elsif(v=9)then
            if(txd/=X"11")then
                errors:=errors+1;
                LOG("*!* ERROR: decode_ip byte 9 Protocol expected x11 received "&to_string(txd));
            end if;
        elsif(v=10)then
            pkt.ip.hdr_csum(0) := txd;
        elsif(v=11)then
            pkt.ip.hdr_csum(1) := txd;
        elsif(v<=15)then
            pkt.ip.src_addr(v-12) := txd;
        elsif(v<=19)then
            pkt.ip.des_addr(v-16) := txd;
        else
            decode_udp(txd, v, done, pkt, errors);
        end if;
    end procedure;

    procedure decode_gmii(
         signal clk     : in std_logic;
         signal txd_en  : in std_logic;
         signal txd     : in std_logic_vector(7 downto 0);
         chk_test_pload : in boolean;
         decoded_pkt    : out t_pkt;
         errors         : inout integer )
     is
         variable pkt             :  t_pkt;
         variable v               :  integer := 0;  -- cnt of clk when txd_en is high
         variable fcs_shift       :  bytes(4 downto 0);
         variable fcs_calc_out    :  std_logic_vector(31 downto 0);
         variable ip_done_fcs_now :  boolean;
         variable fcs_calc_done   :  boolean := False;
     begin
         reset_fcs;
         chk_pload := chk_test_pload;
         wait until rising_edge(txd_en);
         LOG("decode_gmii: txd_en rising_edge");
         while(txd_en)loop
             wait until rising_edge(clk);

             -- Eth Frame Preamble
             if(v<=6)then
                if(txd/=X"55")then
                    errors:=errors+1;
                    pkt.err.bad_eth_pre := True;
                end if;
             -- Eth Frame Sof Delim
             elsif(v=7)then
                if(txd/=X"d5")then
                    errors:=errors+1;
                    pkt.err.bad_eth_pre := True;
                end if;
             elsif(v<=13)then
                pkt.eth.des_addr(v-8):=txd; --bytes come big endian (msB first)
             elsif(v<=19)then
                pkt.eth.src_addr(v-14):=txd;
             elsif(v=20)then
                if(txd/=X"08")then
                    errors:=errors+1;
                    pkt.err.bad_eth_type:=True;
                end if;
             elsif(v=21)then
                if(txd/=X"00")then
                    errors:=errors+1;
                    pkt.err.bad_eth_type:=True;
                end if;
             else
                 decode_ip(txd, v, ip_done_fcs_now, pkt, errors);
             end if;

             if(v>7 and not fcs_calc_done)then
                update_fcs_calc(txd, fcs_calc_out);
             end if;

             if(ip_done_fcs_now and not fcs_calc_done)then
                 for i in 0 to 3 loop
                     pkt.eth.fcs_calc(i) := fcs_calc_out((i*8)+7 downto (i*8));
                 end loop;
                 fcs_calc_done := True;
             end if;

             v:=v+1;
             -- keep shifting in lst 4 bytes while txd_en is high, when it goes low the fcs will be correct
             fcs_shift(fcs_shift'left-1 downto 0) := fcs_shift(fcs_shift'left downto 1);
             fcs_shift(fcs_shift'left):=txd;
         end loop;
         LOG("decode_gmii: txd_en went low");
         pkt.eth.fcs_rx:=fcs_shift(fcs_shift'left-1 downto 0);
         -- LOG("fcs_shift=0x"&bytes_to_str(fcs_shift));
         -- LOG("fcs_shift(0)=0x"&bytes_to_str(fcs_shift(0 downto 0)));
        -- LOG("FCS Rx: 0x"&bytes_to_str(pkt.eth.fcs_rx)&"  Calc: 0x"&bytes_to_str(pkt.eth.fcs_calc));

         --fcs verify
         for ii in 0 to 3 loop
             if(pkt.eth.fcs_rx(ii) /= pkt.eth.fcs_calc(ii))then
                 errors:=errors+1;
                 pkt.err.bad_eth_fcs := True;
             end if;
         end loop;


         if(pkt.err.bad_eth_pre or
            pkt.err.bad_eth_type or
            pkt.err.bad_eth_len or
            pkt.err.bad_ip_hdr or
            pkt.err.bad_ip_len or
            pkt.err.bad_udp_len or
            pkt.err.bad_eth_fcs or
            pkt.err.bad_ip_csum or
            pkt.err.bad_udp_csum)then
                pkt.err.all_good := False;
        else
            pkt.err.all_good := True;
          end if;

         decoded_pkt := pkt;

     end procedure;

----------------------------------------------------------------------------------
-- Procedures for RX side of MAC
----------------------------------------------------------------------------------

    procedure encode_udp(
         signal rxd     : out std_logic_vector(7 downto 0);
         v_ip           : in integer;
         done           : out boolean;
         test           : in string;
         pkt            : inout t_pkt)
    is
        variable v : integer;
        variable id_int : integer;
    begin
        v:=v_ip - 20;

        if (v <= 1) then
            rxd <= pkt.udp.src_port(v);
        elsif (v <= 3) then
            rxd <= pkt.udp.des_port(v-2);
        elsif (v <= 5) then
            rxd <= pkt.udp.len(v-4);
        elsif (v <= 7) then
            rxd <= pkt.udp.csum(v-6);
            pkt.udp.pload_cnt := 0;
        elsif (test = "reg_rd") then
            if (v = 8) then
                rxd <= x"01";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (v <= 12) then
                rxd <= x"00";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (v = 15) then
                rxd <= x"AA";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (pkt.udp.pload_cnt < pkt.udp.len_pload) then
                rxd               <= x"00";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            end if;
        elsif (test = "reg_wr") then
            if (v = 8) then
                rxd <= x"10";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (v <= 12) then
                rxd <= x"00";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (v = 15) then
                rxd <= x"AA";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (v <= 19) then
                rxd <= x"00";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (v <= 23) then
                rxd <= x"FF";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            elsif (pkt.udp.pload_cnt < pkt.udp.len_pload) then
                rxd               <= x"00";
                pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
            end if;
        elsif (pkt.udp.pload_cnt < pkt.udp.len_pload) then
            rxd               <= pkt.udp.payload(pkt.udp.pload_cnt);
            pkt.udp.pload_cnt := pkt.udp.pload_cnt+1;
        else
            pkt.udp.clk_extra := pkt.udp.clk_extra + 1;
        end if;

        if(pkt.udp.pload_cnt < pkt.udp.len_pload or v <= 7) then
            done := False;
        else
            done := True;
        end if;

    end procedure;

    procedure encode_ip(
         signal rxd     : out std_logic_vector(7 downto 0);
         v_eth          : in integer;
         done           : out boolean;
         test           : in string;
         pkt            : inout t_pkt)
    is
        variable v : integer;
    begin
        v:=v_eth-22;

        if (v = 0) then
            rxd <= x"45";
        elsif (v = 1) then
            rxd <= x"00";
        elsif (v <= 3) then
            rxd <= pkt.ip.len(v-2);
        elsif (v <= 5) then
            rxd <= pkt.ip.id(v-4);
        elsif (v <= 8) then
            rxd <= x"00";
        elsif (v = 9) then
            rxd <= x"11";
        elsif (v <= 11) then
            rxd <= pkt.ip.hdr_csum(v-10);
        elsif (v <= 15) then
            rxd <= pkt.ip.src_addr(v-12);
        elsif (v <= 19) then
            rxd <= pkt.ip.des_addr(v-16);
        else
            encode_udp(rxd, v, done, test, pkt);
        end if;

    end procedure;

    procedure encode_gmii(
        signal clk         : in std_logic;
        signal mac_gmii_en : in std_logic;
        mac_dest           : in std_logic_vector(47 downto 0);
        mac_src            : in std_logic_vector(47 downto 0);
        ip_src             : in std_logic_vector(31 downto 0);
        ip_dest            : in std_logic_vector(31 downto 0);
        udp_src            : in std_logic_vector(15 downto 0);
        udp_dest           : in std_logic_vector(15 downto 0);
        pkt_bytes          : in std_logic_vector(15 downto 0);
        signal rxd_en      : out std_logic;
        signal rxd         : out std_logic_vector(7 downto 0);
        signal done        : out std_logic;
        test               : in string;
        pkt_out            : out t_pkt)
    is
        variable pkt             :  t_pkt;
        variable v               :  integer := 0;  -- cnt of clk when txd_en is high
        variable fcs_calc_out    :  std_logic_vector(31 downto 0);
        variable ip_done_fcs_now :  boolean;
        variable fcs_calc_done   :  boolean := False;
        variable rxd_done        :  boolean := False;
        variable ip_len          :  std_logic_vector(15 downto 0);
        variable udp_len         :  std_logic_vector(15 downto 0);
    begin
        -- assign MAC addresses
        pkt.eth.src_addr(0) := mac_src(47 downto 40);
        pkt.eth.src_addr(1) := mac_src(39 downto 32);
        pkt.eth.src_addr(2) := mac_src(31 downto 24);
        pkt.eth.src_addr(3) := mac_src(23 downto 16);
        pkt.eth.src_addr(4) := mac_src(15 downto 8);
        pkt.eth.src_addr(5) := mac_src(7 downto 0);

        pkt.eth.des_addr(0) := mac_dest(47 downto 40);
        pkt.eth.des_addr(1) := mac_dest(39 downto 32);
        pkt.eth.des_addr(2) := mac_dest(31 downto 24);
        pkt.eth.des_addr(3) := mac_dest(23 downto 16);
        pkt.eth.des_addr(4) := mac_dest(15 downto 8);
        pkt.eth.des_addr(5) := mac_dest(7 downto 0);

        -- assign IP addresses
        pkt.ip.src_addr(0) := ip_src(31 downto 24);
        pkt.ip.src_addr(1) := ip_src(23 downto 16);
        pkt.ip.src_addr(2) := ip_src(15 downto 8);
        pkt.ip.src_addr(3) := ip_src(7 downto 0);

        pkt.ip.des_addr(0) := ip_dest(31 downto 24);
        pkt.ip.des_addr(1) := ip_dest(23 downto 16);
        pkt.ip.des_addr(2) := ip_dest(15 downto 8);
        pkt.ip.des_addr(3) := ip_dest(7 downto 0);

        -- assign UDP ports
        pkt.udp.src_port(0) := udp_src(15 downto 8);
        pkt.udp.src_port(1) := udp_src(7 downto 0);

        pkt.udp.des_port(0) := udp_dest(15 downto 8);
        pkt.udp.des_port(1) := udp_dest(7 downto 0);

        -- calculate lengths
        udp_len := pkt_bytes + 8;
        ip_len  := udp_len + 20;

        pkt.ip.len(0) := ip_len(15 downto 8);
        pkt.ip.len(1) := ip_len(7 downto 0);

        pkt.udp.len(0) := udp_len(15 downto 8);
        pkt.udp.len(1) := udp_len(7 downto 0);

        pkt.udp.len_pload := conv_integer(pkt_bytes);

        -- create payload data
        pkt.udp.payload(0) := x"00";
        for i in 1 to pkt.udp.len_pload-1 loop
            pkt.udp.payload(i) := pkt.udp.payload(i-1) + 1;
        end loop;

        -- assign IP ID
        pkt.ip.id(0) := x"AA";
        pkt.ip.id(1) := x"BB";

        -- assign checksums
        pkt.ip.hdr_csum := (others => (others => '0'));
        pkt.udp.csum    := (others => (others => '0'));

        reset_fcs;

        LOG("encode_gmii: start gmii");
        while(mac_gmii_en)loop
            wait until rising_edge(clk);

            rxd_en <= '1';
            if (v <= 6) then
                rxd <= x"55";
            elsif (v = 7) then
                rxd <= x"d5";
            elsif (v <= 13) then
                rxd <= pkt.eth.des_addr(v-8);
            elsif (v <= 19) then
                rxd <= pkt.eth.src_addr(v-14);
            elsif (v <= 20) then
                rxd <= x"08";
            elsif (v <= 21) then
                rxd <= x"00";
            elsif (v <= (pkt.udp.len_pload + 49)) then
                encode_ip(rxd, v, ip_done_fcs_now, test, pkt);
            elsif (v <= (pkt.udp.len_pload + 49 + 4)) then
                rxd <= pkt.eth.fcs_calc(v - (pkt.udp.len_pload + 49 + 1)); -- FIXME does FCS calc below happen sequentially?
            elsif (v > (pkt.udp.len_pload + 49 + 4)) then
                rxd      <= x"00";
                rxd_done := True;
            else
                rxd <= x"00";
            end if;

            if(v > 7 and not fcs_calc_done)then
               update_fcs_calc(rxd, fcs_calc_out);
            end if;

            if(ip_done_fcs_now and not fcs_calc_done)then
                for i in 0 to 3 loop
                    pkt.eth.fcs_calc(i) := fcs_calc_out((i*8)+7 downto (i*8));
                end loop;
                fcs_calc_done := True;
            end if;

            done <= '1' when rxd_done else '0';
            pkt_out := pkt;
            v := v + 1;
        end loop;

        LOG("encode_gmii: done sending packet");
        rxd_en <= '0';

     end procedure;

    procedure decode_axis(
        signal clk         : in std_logic;
        pkt                : in t_pkt;
        signal tdata       : in std_logic_vector(7 downto 0);
        signal tvalid      : in std_logic;
        signal tlast       : in std_logic;
        signal tready      : out std_logic;
        signal mac_src     : in std_logic_vector(47 downto 0);
        signal ip_id       : in std_logic_vector(15 downto 0);
        signal payload_len : in std_logic_vector(15 downto 0);
        signal ip_src      : in std_logic_vector(31 downto 0);
        signal udp_dest    : in std_logic_vector(15 downto 0);
        signal udp_src     : in std_logic_vector(15 downto 0);
        test_pass          : out boolean)
    is
        variable v                 : integer := 0;
        variable pkt_hdr_err       : boolean := False;
        variable pkt_len_long_err  : boolean := False;
        variable pkt_len_short_err : boolean := False;
        variable pload_len_slv     : std_logic_vector(15 downto 0);
        variable mac_src_exp       : std_logic_vector(47 downto 0);
        variable ip_id_exp         : std_logic_vector(15 downto 0);
        variable ip_src_exp        : std_logic_vector(31 downto 0);
        variable udp_dest_exp      : std_logic_vector(15 downto 0);
        variable udp_src_exp       : std_logic_vector(15 downto 0);
    begin
        tready <= '1';

        wait until rising_edge(tvalid);
        wait until rising_edge(clk);

        -- convert payload length into bytes
        pload_len_slv := std_logic_vector(to_unsigned(pkt.udp.len_pload, pload_len_slv'length));

        -- concat fields
        mac_src_exp := pkt.eth.src_addr(0) & pkt.eth.src_addr(1) & pkt.eth.src_addr(2) & pkt.eth.src_addr(3) & pkt.eth.src_addr(4) & pkt.eth.src_addr(5);
        ip_id_exp := pkt.ip.id(0) & pkt.ip.id(1);
        ip_src_exp := pkt.ip.src_addr(0) & pkt.ip.src_addr(1) & pkt.ip.src_addr(2) & pkt.ip.src_addr(3);
        udp_dest_exp := pkt.udp.des_port(0) & pkt.udp.des_port(1);
        udp_src_exp := pkt.udp.src_port(0) & pkt.udp.src_port(1);

        LOG("");
        LOG("---------------------- Ethernet Payload Display ----------------------");
        LOG("");

        while(tvalid)loop
            if (v = 0) then
                if (mac_src /= mac_src_exp) then
                    LOG("             *Failed - MAC src addr: expected 0x"&to_hstring(mac_src_exp)&", actual 0x"&to_hstring(mac_src));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - MAC src addr: expected 0x"&to_hstring(mac_src_exp)&", actual 0x"&to_hstring(mac_src));
                end if;

                if (ip_id /= ip_id_exp) then
                    LOG("             *Failed - IP ID: expected 0x"&to_hstring(ip_id_exp)&", actual 0x"&to_hstring(ip_id));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - IP ID: expected 0x"&to_hstring(ip_id_exp)&", actual 0x"&to_hstring(ip_id));
                end if;

                if (payload_len /= pload_len_slv) then
                    LOG("             *Failed - Payload len: expected 0x"&to_hstring(pload_len_slv)&", actual 0x"&to_hstring(payload_len));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - Payload len: expected 0x"&to_hstring(pload_len_slv)&", actual 0x"&to_hstring(payload_len));
                end if;

                if (ip_src /= ip_src_exp) then
                    LOG("             *Failed - IP src addr: expected 0x"&to_hstring(ip_src_exp)&", actual 0x"&to_hstring(ip_src));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - IP src addr: expected 0x"&to_hstring(ip_src_exp)&", actual 0x"&to_hstring(ip_src));
                end if;

                if (udp_dest /= udp_dest_exp) then
                    LOG("             *Failed - UDP dest port: expected 0x"&to_hstring(udp_dest_exp)&", actual 0x"&to_hstring(udp_dest));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - UDP dest port: expected 0x"&to_hstring(udp_dest_exp)&", actual 0x"&to_hstring(udp_dest));
                end if;

                if (udp_src /= udp_src_exp) then
                    LOG("             *Failed - UDP src port: expected 0x"&to_hstring(udp_src_exp)&", actual 0x"&to_hstring(udp_src));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - UDP src port: expected 0x"&to_hstring(udp_src_exp)&", actual 0x"&to_hstring(udp_src));
                end if;
            end if;

            if (v < pkt.udp.len_pload) then
                if (tdata /= v) then
                    LOG("             *Failed - Payload: expected 0x"&to_string(v)&", actual 0x"&to_hstring(tdata));
                    pkt_hdr_err := True;
                else
                    LOG("              Passed - Payload: expected 0x"&to_string(v)&", actual 0x"&to_hstring(tdata));
                end if;
            else
                LOG("             *Failed - Payload longer than expected, actual 0x"&to_hstring(tdata));
                pkt_len_long_err := True;
            end if;

            wait until rising_edge(clk);
            v := v + 1;
        end loop;

        -- If not true, then tvalid went low before full length of packet
        if (v < pkt.udp.len_pload) then
            pkt_len_short_err := True;
        end if;

        LOG("");
        if (pkt_hdr_err = True or pkt_len_long_err = True or pkt_len_short_err = True) then
            LOG("              WARNING! WARNING! PACKET ERRORS DETECTED!!!");
            LOG("                     pkt_hdr_err:       "&to_string(pkt_hdr_err));
            LOG("                     pkt_len_long_err:  "&to_string(pkt_len_long_err));
            LOG("                     pkt_len_short_err: "&to_string(pkt_len_short_err));
            test_pass := False;
        else
            LOG("                  Packet passed - no issues detected.");
            test_pass := True;
        end if;
        LOG("");
        LOG("----------------------------------------------------------------------");
        LOG("");

    end procedure;

    procedure decode_reg(
        signal clk         : in  std_logic;
        signal tdata       : in  std_logic_vector(7 downto 0);
        signal tvalid      : in  std_logic;
        signal tlast       : in  std_logic;
        signal tready      : in  std_logic;
        signal reg_data_rd : out std_logic_vector(31 downto 0);
        signal reg_data_wr : in  std_logic_vector(31 downto 0);
        signal reg_addr    : in  std_logic_vector(23 downto 0);
        signal reg_re      : in  std_logic;
        signal reg_wr      : in  std_logic;
        signal reg_tdata   : in  std_logic_vector(7 downto 0);
        signal reg_tvalid  : in  std_logic;
        signal reg_tlast   : in  std_logic;
        signal reg_tready  : out std_logic;
        test_pass          : out boolean)
    is
        variable v                 : integer := 0;
        variable w                 : integer := 0;
        variable reg_addr_err      : boolean := False;
        variable reg_resp_type_err : boolean := False;
        variable reg_resp_zero_err : boolean := False;
        variable reg_resp_data_err : boolean := False;
        variable m_cmd_type        : std_logic_vector(7 downto 0);
        variable m_reg_addr        : bytes(2 downto 0);
        variable m_reg_data_wr     : bytes(3 downto 0);
        variable reg_data_bytes    : bytes(3 downto 0);
    begin
        reg_tready <= '1';

        wait until rising_edge(tvalid);
        wait until rising_edge(clk);

        -- Monitor AXI stream from MAC RX
        while(tvalid)loop
            if (w = 0) then
                m_cmd_type := tdata;
            elsif (w <= 4) then
                null;
            elsif (w <= 7) then
                m_reg_addr(w-5) := tdata;
            elsif (w <= 11) then
                null;
            elsif (w <= 15) then
                m_reg_data_wr(w-12) := tdata;
            end if;

            wait until rising_edge(clk);
            w := w + 1;
        end loop;

        -- Wait for simple bus read/write enable
        if (m_cmd_type = REG_RD_TYPE) then
            while (not reg_re) loop
                wait until rising_edge(clk);
            end loop;
        elsif (m_cmd_type = REG_WR_TYPE) then
            while (not reg_wr) loop
                wait until rising_edge(clk);
            end loop;
        end if;

        -- Use simple bus register address as read data
        if (reg_re) then
            reg_data_rd <= x"00" & reg_addr;
            reg_data_bytes(0) := x"00";
            reg_data_bytes(1) := reg_addr(23 downto 16);
            reg_data_bytes(2) := reg_addr(15 downto 8);
            reg_data_bytes(3) := reg_addr(7 downto 0);
        elsif (reg_wr) then
            reg_data_rd <= (others => '0');
            reg_data_bytes(0) := (others => '0');
            reg_data_bytes(1) := (others => '0');
            reg_data_bytes(2) := (others => '0');
            reg_data_bytes(3) := (others => '0');
        end if;

        -- Verify that data from MAC RX checks out with simple bus
        LOG("");
        LOG("---------------------- Register Command Display ----------------------");
        LOG("");

        if (reg_re or reg_wr) then
            if (reg_addr /= (m_reg_addr(0) & m_reg_addr(1) & m_reg_addr(2))) then
                LOG("             *Failed - Reg addr: expected 0x"&to_hstring((m_reg_addr(0) & m_reg_addr(1) & m_reg_addr(2)))&", actual 0x"&to_hstring(reg_addr));
                reg_addr_err := True;
            else
                LOG("              Passed - Reg addr: expected 0x"&to_hstring((m_reg_addr(0) & m_reg_addr(1) & m_reg_addr(2)))&", actual 0x"&to_hstring(reg_addr));
            end if;
        end if;

        if (reg_wr) then
            if (reg_data_wr /= (m_reg_data_wr(0) & m_reg_data_wr(1) & m_reg_data_wr(2) & m_reg_data_wr(3))) then
                LOG("             *Failed - Reg data wr: expected 0x"&to_hstring((m_reg_data_wr(0) & m_reg_data_wr(1) & m_reg_data_wr(2) & m_reg_data_wr(3)))&", actual 0x"&to_hstring(reg_data_wr));
                reg_addr_err := True;
            else
                LOG("              Passed - Reg data wr: expected 0x"&to_hstring((m_reg_data_wr(0) & m_reg_data_wr(1) & m_reg_data_wr(2) & m_reg_data_wr(3)))&", actual 0x"&to_hstring(reg_data_wr));
            end if;
        end if;

        -- Check read response packet
        if (m_cmd_type = REG_RD_TYPE) then
            wait until rising_edge(reg_tvalid);
            wait until rising_edge(clk);

            while(reg_tvalid)loop
                if (v = 0) then
                    if (reg_tdata /= m_cmd_type) then
                        LOG("             *Failed - Reg resp type: expected 0x"&to_hstring(m_cmd_type)&", actual 0x"&to_hstring(reg_tdata));
                        reg_resp_type_err := True;
                    else
                        LOG("              Passed - Reg resp type: expected 0x"&to_hstring(m_cmd_type)&", actual 0x"&to_hstring(reg_tdata));
                    end if;
                elsif (v <= 3) then
                    if (reg_tdata /= x"00") then
                        LOG("             *Failed - Reg zero: expected 0x00, actual 0x"&to_hstring(reg_tdata));
                        reg_resp_zero_err := True;
                    else
                        LOG("              Passed - Reg zero: expected 0x00, actual 0x"&to_hstring(reg_tdata));
                    end if;
                elsif (v <= 7) then
                    if (reg_tdata /= reg_data_bytes(v-4)) then
                        LOG("             *Failed - Reg resp: expected 0x"&to_hstring(reg_data_bytes(v-4))&", actual 0x"&to_hstring(reg_tdata));
                        reg_resp_data_err := True;
                    else
                        LOG("              Passed - Reg resp: expected 0x"&to_hstring(reg_data_bytes(v-4))&", actual 0x"&to_hstring(reg_tdata));
                    end if;
                elsif (v <= 17) then
                    if (reg_tdata /= x"00") then
                        LOG("             *Failed - Reg zero: expected 0x00, actual 0x"&to_hstring(reg_tdata));
                        reg_resp_type_err := True;
                    else
                        LOG("              Passed - Reg zero: expected 0x00, actual 0x"&to_hstring(reg_tdata));
                    end if;
                end if;

                wait until rising_edge(clk);
                v := v + 1;
            end loop;
        end if;

        -- Print errors if found
        LOG("");
        if (reg_addr_err = True or reg_resp_type_err = True or reg_resp_zero_err = True or reg_resp_data_err = True) then
            LOG("         WARNING! WARNING! REGISTER COMMAND ERRORS DETECTED!!!");
            LOG("                     reg_addr_err:      "&to_string(reg_addr_err));
            LOG("                     reg_resp_type_err: "&to_string(reg_resp_type_err));
            LOG("                     reg_resp_zero_err: "&to_string(reg_resp_zero_err));
            LOG("                     reg_resp_data_err: "&to_string(reg_resp_data_err));
            test_pass := False;
        else
            LOG("              Register command passed - no issues detected.");
            test_pass := True;
        end if;
        LOG("");
        LOG("----------------------------------------------------------------------");
        LOG("");
        
        

    end procedure;

end package body;

