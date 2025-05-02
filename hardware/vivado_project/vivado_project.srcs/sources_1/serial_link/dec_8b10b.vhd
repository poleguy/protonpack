-- 8b10b decoder
-------------------------------------------------
-- dec_8b10b.vhd
--------------------------------------------------
--
-- Copyright © 2019 Shure Incorporated
-- CONFIDENTIAL AND PROPRIETARY TO SHURE
--
--------------------------------------------------
-- 8b10b
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

entity dec_8b10b is
  port
    (
      clk   : in std_logic;
      datain_10b  : in std_logic_vector(9 downto 0);      
      rdispin : in std_logic;
      en : in std_logic;
      reset_n : in std_logic;
      dataout_8b  : out std_logic_vector(7 downto 0);      
      kout : out std_logic;
      disp_err : out std_logic;
      code_err : out std_logic;
      rdispout : out std_logic;
      debug : out std_logic_vector(9 downto 0)
      );

end dec_8b10b;

architecture rtl of dec_8b10b is

  signal r_dataout : std_logic_vector(7 downto 0) := (others => '0');
  signal dataout : std_logic_vector(8 downto 0);
  signal dispout : std_logic;
  signal r_datain : std_logic_vector(9 downto 0) := (others => '0');
  signal r_dispout : std_logic := '0';
  signal r_en_1 : std_logic := '0';
  signal disp_err_core : std_logic;
  signal code_err_core : std_logic;
  signal r_disp_err : std_logic := '0';
  signal r_code_err : std_logic := '0';
  signal r_kout : std_logic := '0';
  
  component decode
    port(
	  datain : in std_logic_vector(9 downto 0);
	  dispin : in std_logic;
	  dataout : out std_logic_vector(8 downto 0);
	  dispout : out std_logic;
	  code_err: out std_logic;
	  disp_err : out std_logic	  
	);
  end component;
  
begin

  ------------------------------------------------------------
  -- 8b/10b encode data  
  ------------------------------------------------------------
  -- https://www.latticesemi.com/-/media/LatticeSemi/Documents/ReferenceDesigns/1D/8b10bEncoderDecoder-Documentation.ashx?document_id=5653
  
  -- file:///home/fpga/Downloads/8b10bEncoderDecoder-Documentation.pdf
  --decode_1 : entity work.decode
  decode_1 : decode
    port map(datain => r_datain,
             dispin => rdispin,
             dataout => dataout,
             dispout => dispout,
             code_err => code_err_core,
             disp_err => disp_err_core) ;



  process(clk)
  begin
    if rising_edge(clk) then
      r_en_1 <= en;
    end if;
  end process;
  process(clk)
  begin
    if rising_edge(clk) then
      if (en = '1') then
        r_datain(9 downto 0) <= datain_10b;
      end if;
    end if;
  end process;
  process(clk)
  begin
    if rising_edge(clk) then
      if (r_en_1 = '1') then
        r_dataout <= dataout(7 downto 0);
        r_kout <= dataout(8);
        r_disp_err <= disp_err_core;
        r_code_err <= code_err_core;
        r_dispout <= dispout;                      
      end if;
    end if;
  end process;
  dataout_8b <= r_dataout;
  rdispout <= r_dispout;
  kout <= r_kout;
  disp_err <= r_disp_err;
  code_err <= r_code_err;
  debug <= r_datain;
  
  
end architecture rtl;

