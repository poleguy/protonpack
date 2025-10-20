----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
-- 
-- Description: async fifo instantiation
--
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity afifo_infer is
  generic (
    DATA_WIDTH              : integer := 8;
    ADDR_WIDTH              : integer := 4;
    USE_DISTR_NOT_BLOCK_RAM : boolean := false
    );
  port (
    -- Reading port.
    rd_clk  : in  std_logic;
    rd_en   : in  std_logic;
    rd_data : out std_logic_vector (DATA_WIDTH-1 downto 0);

    rd_empty       : out std_logic;
    rd_over_thresh : out std_logic;  -- set by wr_set_thresh and sync to rd_clk
    rd_full        : out std_logic;
    rd_depth       : out std_logic_vector(ADDR_WIDTH-1 downto 0);  --fifo depth can lag by a few counts due to sync

    -- Writing port.
    wr_en   : in std_logic;
    wr_clk  : in std_logic;
    wr_data : in std_logic_vector (DATA_WIDTH-1 downto 0);

    wr_set_thresh  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    wr_over_thresh : out std_logic;  --set by wr_set_thresh
    wr_full        : out std_logic;
    wr_depth       : out std_logic_vector(ADDR_WIDTH-1 downto 0);  --fifo depth can lag by a few counts due to sync

    rst_rd_clk : in std_logic  -- reset in rd_clk domain
    );
end entity;
architecture rtl of afifo_infer is
  ----/Internal connections & variables------
  constant FIFO_DEPTH : integer := 2**ADDR_WIDTH;

  type RAM is array (integer range <>)of std_logic_vector (DATA_WIDTH-1 downto 0);

  signal pWrite             : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pWrite_d           : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pWrite_rclk_meta   : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pWrite_rclk_sync   : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pRead              : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pRead_d            : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pRead_wclk_meta    : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pRead_wclk_sync    : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal pEqual_rclk        : std_logic;
  signal pEqual_wclk        : std_logic;
  signal set_status_wclk    : std_logic;
  signal set_status_rclk    : std_logic;
  signal RdBinCnt           : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal RdBinCnt_wclk      : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal WrBinCnt_rclk      : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal WrBinCnt           : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal fill_depth_wclk    : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal fill_depth_rclk    : std_logic_vector (ADDR_WIDTH-1 downto 0);
  signal NextWriteAddressEn : std_logic;
  signal NextReadAddressEn  : std_logic;
  signal empty_int          : std_logic;
  signal full_int           : std_logic;
  signal over_thresh_int    : std_logic;
  signal empty_sr           : std_logic_vector (3 downto 0) := (others => '0');

  signal over_thresh_rclk_sync : std_logic := '0';
  signal over_thresh_rclk_meta : std_logic := '0';

--  signal rst_rclk      : std_logic;
--  signal rst_rclk_meta : std_logic;
  signal r_rst_rclk    : std_logic := '0';  -- delay for safe fanout 

  signal rst_wclk      : std_logic := '0';
  
  signal r_rst_wclk    : std_logic := '0';  -- delay for safe fanout 
  signal r_rst_wclk2   : std_logic := '0';
  signal rst_wclk_meta : std_logic := '0';

  signal full_rclk_meta : std_logic;

  attribute ASYNC_REG                          : string;
  attribute ASYNC_REG of pWrite_rclk_meta      : signal is "TRUE";
  attribute ASYNC_REG of pWrite_rclk_sync      : signal is "TRUE";
  attribute ASYNC_REG of pRead_wclk_meta       : signal is "TRUE";
  attribute ASYNC_REG of pRead_wclk_sync       : signal is "TRUE";
  attribute ASYNC_REG of over_thresh_rclk_meta : signal is "TRUE";
  attribute ASYNC_REG of over_thresh_rclk_sync : signal is "TRUE";

--  attribute ASYNC_REG of rst_rclk      : signal is "TRUE";
--  attribute ASYNC_REG of rst_rclk_meta : signal is "TRUE";
  attribute ASYNC_REG of rst_wclk      : signal is "TRUE";
  attribute ASYNC_REG of rst_wclk_meta : signal is "TRUE";

  attribute ASYNC_REG of rd_full        : signal is "TRUE";
  attribute ASYNC_REG of full_rclk_meta : signal is "TRUE";

begin

  -- outputs
  wr_over_thresh <= over_thresh_int;
  rd_over_thresh <= over_thresh_rclk_sync;
  wr_depth       <= fill_depth_wclk;
  rd_depth       <= fill_depth_rclk;

  -- RESET sync
  process (rd_clk)
  begin
    if rising_edge(rd_clk) then
      r_rst_rclk <= rst_rd_clk;
    end if;
  end process;
  process (wr_clk)
  begin
    if rising_edge(wr_clk) then
      rst_wclk_meta <= r_rst_rclk;
      rst_wclk      <= rst_wclk_meta;
      r_rst_wclk    <= rst_wclk;
      r_rst_wclk2   <= rst_wclk;
    end if;
  end process;


  process (rd_clk)
  begin
    if rising_edge(rd_clk) then
      full_rclk_meta <= full_int;
      rd_full        <= full_rclk_meta;
    end if;
  end process;


  process (rd_clk)
  begin
    if rising_edge(rd_clk) then
      over_thresh_rclk_meta <= over_thresh_int;
      over_thresh_rclk_sync <= over_thresh_rclk_meta;
    end if;
  end process;

  fill_depth_wclk <= WrBinCnt - RdBinCnt_wclk;
  fill_depth_rclk <= WrBinCnt_rclk - RdBinCnt;

  --convert synchronized gray codes to binary count for depth arithmetic
  RdBinCnt_wclk <= pRead_wclk_sync(ADDR_WIDTH-1) &
                   (RdBinCnt_wclk(ADDR_WIDTH-1 downto 1) xor
                    pRead_wclk_sync(ADDR_WIDTH-2 downto 0));

  WrBinCnt_rclk <= pWrite_rclk_sync(ADDR_WIDTH-1) &
                   (WrBinCnt_rclk(ADDR_WIDTH-1 downto 1) xor
                    pWrite_rclk_sync(ADDR_WIDTH-2 downto 0));

  process (wr_clk)
  begin
    if (rising_edge(wr_clk))then
      if(r_rst_wclk = '1')then
        over_thresh_int <= '0';
      elsif(fill_depth_wclk >= wr_set_thresh) then
        over_thresh_int <= '1';
      else
        over_thresh_int <= '0';
      end if;
    end if;
  end process;

  -- sync gray counter into other clock domain
  process (rd_clk)
  begin
    if(rising_edge(rd_clk))then
      if(r_rst_rclk = '1')then
        pWrite_rclk_meta <= (others => '0');
        pWrite_rclk_sync <= (others => '0');
      else
        pWrite_rclk_meta <= pWrite_d;
        pWrite_rclk_sync <= pWrite_rclk_meta;
      end if;
    end if;
  end process;

  process (wr_clk)
  begin
    if(rising_edge(wr_clk))then
      if(r_rst_wclk = '1')then
        pRead_wclk_meta <= (others => '0');
        pRead_wclk_sync <= (others => '0');
      else
        pRead_wclk_meta <= pRead_d;
        pRead_wclk_sync <= pRead_wclk_meta;
      end if;
    end if;
  end process;

  --clk pointers into FF before syncronizing to other clk domain
  process (rd_clk)
  begin
    if(rising_edge(rd_clk))then
      if(r_rst_rclk = '1')then
        pRead_d <= (others => '0');
      else
        pRead_d <= pRead;
      end if;
    end if;
  end process;
  
  process (wr_clk)
  begin
    if(rising_edge(wr_clk))then
      if(r_rst_wclk = '1')then
        pWrite_d <= (others => '0');
      else
        pWrite_d <= pWrite;
      end if;
    end if;
  end process;



  ----------------------------
  --'EqualAddresses' logic:
  pEqual_wclk <= '1' when (pWrite = pRead_wclk_sync) else '0';
  pEqual_rclk <= '1' when (pRead = pWrite_rclk_sync) else '0';

  set_status_wclk <= (pWrite(ADDR_WIDTH-2) xnor pRead_wclk_sync(ADDR_WIDTH-1)) and
                     (pWrite(ADDR_WIDTH-1) xor pRead_wclk_sync(ADDR_WIDTH-2));

  set_status_rclk <= (pRead(ADDR_WIDTH-2) xnor pWrite_rclk_sync(ADDR_WIDTH-1)) and
                     (pRead(ADDR_WIDTH-1) xor pWrite_rclk_sync(ADDR_WIDTH-2));

  --'full' logic for the writing port:
  process (wr_clk)
  begin
    if(rising_edge(wr_clk))then
      full_int <= set_status_wclk and pEqual_wclk;
    end if;
  end process;
  wr_full <= full_int;

  --'empty' logic for the reading port:
  empty_int <= not set_status_rclk and pEqual_rclk;

  process (rd_clk)
  begin
    if rising_edge (rd_clk) then
      if (r_rst_rclk = '1') then
        empty_sr <= (others => '1');
      else
        empty_sr(0)          <= empty_int;
        empty_sr(3 downto 1) <= empty_sr(2 downto 0);
      end if;
    end if;
  end process;
  rd_empty <= empty_sr(3);

  --Fifo addresses support logic: 
  --'Next Addresses' enable logic:
  NextWriteAddressEn <= wr_en and (not full_int);
  NextReadAddressEn  <= rd_en and (not empty_int);

  --Addreses (Gray counters) logic:
  gray_cnt_pWr : entity work.gray_cnt
    generic map (
      COUNTER_WIDTH => ADDR_WIDTH
      )
    port map (
      GrayCount_out => pWrite,
      BinCount_out  => WrBinCnt,
      Enable_in     => NextWriteAddressEn,
      Clear_in      => r_rst_wclk2,
      clk           => wr_clk
      );

  gray_cnt_pRd : entity work.gray_cnt
    generic map (
      COUNTER_WIDTH => ADDR_WIDTH
      )
    port map (
      GrayCount_out => pRead,
      BinCount_out  => RdBinCnt,
      Enable_in     => NextReadAddressEn,
      Clear_in      => r_rst_rclk,
      clk           => rd_clk
      );


  -- FIFO RAM INFER
  gen_bram_attr : if USE_DISTR_NOT_BLOCK_RAM = false generate
    signal Mem                 : RAM (0 to FIFO_DEPTH-1);
    attribute ram_style        : string;
    attribute ram_style of Mem : signal is "block";
  begin
    --'dout' logic:
    process (rd_clk)
    begin
      if (rising_edge(rd_clk)) then
        if (rd_en = '1' and empty_int = '0') then
          rd_data <= Mem(conv_integer(pRead));
        end if;
      end if;
    end process;
    --'din' logic:
    process (wr_clk)
    begin
      if (rising_edge(wr_clk)) then
        if (wr_en = '1' and full_int = '0') then
          Mem(conv_integer(pWrite)) <= wr_data;
        end if;
      end if;
    end process;
  end generate;

  gen_distr_attr : if USE_DISTR_NOT_BLOCK_RAM = true generate
    signal Mem                 : RAM (0 to FIFO_DEPTH-1);
    attribute ram_style        : string;
    attribute ram_style of Mem : signal is "distributed";
  begin
    --'dout' logic:
    process (rd_clk)
    begin
      if (rising_edge(rd_clk)) then
        if (rd_en = '1' and empty_int = '0') then
          rd_data <= Mem(conv_integer(pRead));
        end if;
      end if;
    end process;
    --'din' logic:
    process (wr_clk)
    begin
      if (rising_edge(wr_clk)) then
        if (wr_en = '1' and full_int = '0') then
          Mem(conv_integer(pWrite)) <= wr_data;
        end if;
      end if;
    end process;
  end generate;


end architecture;
