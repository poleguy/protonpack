----------------------------------------------------------------------------------
-- Company: Shure Inc
-- Engineer: Alex Stezskal
-- Revision: subversion.shure.com
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity axi_to_sb is
generic (
            ADDR_WIDTH     : natural := 24 
		);
	port (
            axi_aclk    : IN STD_LOGIC;
            axi_aresetn : IN STD_LOGIC;
            axi_awid    : IN STD_LOGIC_VECTOR(3 downto 0):= (others => '0');
            axi_awaddr  : IN STD_LOGIC_VECTOR(ADDR_WIDTH-1 DOWNTO 0);
            axi_awlen   : IN STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
            axi_awsize  : IN STD_LOGIC_VECTOR(2 DOWNTO 0) := (others => '0');
            axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0):= (others => '0');
            axi_awvalid : IN STD_LOGIC;
            axi_awready : OUT STD_LOGIC                     := '0';
            axi_wdata   : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            axi_wstrb   : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            axi_wlast   : IN STD_LOGIC;
            axi_wvalid  : IN STD_LOGIC; 
            axi_wready  : OUT STD_LOGIC                     := '0';
            axi_bid     : OUT STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
            axi_bresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)  := "00";
            axi_bvalid  : OUT STD_LOGIC                     := '0';
            axi_bready  : IN STD_LOGIC;
            axi_arid    : IN STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
            axi_araddr  : IN STD_LOGIC_VECTOR(ADDR_WIDTH-1 DOWNTO 0);
            axi_arlen   : IN STD_LOGIC_VECTOR(7 DOWNTO 0):= (others => '0');
            axi_arsize  : IN STD_LOGIC_VECTOR(2 DOWNTO 0):= (others => '0');
            axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0):= (others => '0');
            axi_arvalid : IN STD_LOGIC;
            axi_arready : OUT STD_LOGIC                     := '0';
            axi_rid     : OUT STD_LOGIC_VECTOR(3 downto 0):= (others => '0');
            axi_rdata   : OUT STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
            axi_rresp   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)  := (others => '0');
            axi_rlast   : OUT STD_LOGIC                     := '0';
            axi_rvalid  : OUT STD_LOGIC                     := '0';
            axi_rready  : IN STD_LOGIC ;
            
            sb_data_rd  : in std_logic_vector(31 downto 0);
            sb_data_wr  : out std_logic_vector(31 downto 0);
            sb_addr     : out std_logic_vector(ADDR_WIDTH-1 downto 0); --byte based addressing same as axi, so 0x0, 0x4, 0x8
            sb_wea      : out std_logic;
            sb_rea      : out std_logic
		);
    
end axi_to_sb;

architecture rtl of axi_to_sb is
    

	type t_state_read is (IDLE,
                        ACK_READ_START,
						WAIT_FOR_RREADY,
						READING
						);
    signal state_read                : t_state_read := IDLE;

	type t_state_write is (IDLE,
                        ACK_WRITE_START,
						WAIT_FOR_WVALID,
						WRITING,
                        WRITE_DONE_ACK
						);
    signal state_write                : t_state_write := IDLE;

    signal addr_wr          : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal addr_rd          : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal axi_wready_int   : std_logic;
    signal rd_cnt           : std_logic_vector(7 downto 0) := (others => '0');
    signal sb_rea_int       : std_logic;
    signal addr_rnw         : std_logic;

begin -- architecture

    axi_bid <= axi_awid;
    axi_rid <= axi_arid;
       
    sb_addr(sb_addr'left downto 2) <= addr_rd(sb_addr'left-2 downto 0) when addr_rnw='1' else addr_wr(sb_addr'left-2 downto 0);
    sb_addr(1 downto 0) <= "00";


    ----------------------------------------------
    -- READ FSM  
    ----------------------------------------------
    sb_rea              <= sb_rea_int; --read different than write because have to read data 1 clock earleier whereas data you can write in on same clock
    axi_rdata           <= sb_data_rd;

    axi_rd_proc : process (axi_aclk) is
        variable var_axi_arlen : std_logic_vector(axi_arlen'left downto 0);
    begin 
		if rising_edge(axi_aclk) then	
			case state_read is
				when IDLE =>
                    sb_rea_int  <= '0';
                    axi_rvalid  <= '0';
                    axi_rlast   <= '0';
                    axi_arready <= '0';
                    axi_rresp   <= (others => '0');
                    addr_rnw    <= '0';
                    if (axi_arvalid = '1') then --indicates master is starting a transaction and the address is on the bus
                        addr_rnw    <= '1';     --determines if sb_addr is coming from read or from write state machines
                        state_read <= ACK_READ_START;
					end if;
                when ACK_READ_START =>
                    axi_arready     <= '1';  --ack the address here
                    addr_rd         <= "00" & axi_araddr(addr_rd'left downto 2);  --save start addr and convert from byte to 32-bit word based addressing for counting
                    var_axi_arlen   := axi_arlen;  --axi_arlen+1 = # of beats to read
                    rd_cnt          <= (others => '0');
                    sb_rea_int      <= '1'; --set sb_rea to get the first data word since registered output
                    state_read      <= READING;
              --  when WAIT_FOR_RREADY =>  
              --      sb_rea_int      <= '1'; --set sb_rea to get the first data word since registered output
              --      axi_arready     <= '0';
              --      if(axi_rready='1')then
              --          state_read  <= READING;
              --      end if;
                when READING =>
                    axi_arready     <= '0';
                    if(axi_rready='1') then  --data is valid on first beat of this state if rready is high 
                        axi_rvalid  <= '1';  --rvalid and rready will be high indicating an active beat
                        addr_rd     <= addr_rd + 1;
                        rd_cnt      <= rd_cnt + 1;
                        if(rd_cnt=var_axi_arlen or var_axi_arlen=0)then
                            sb_rea_int  <= '0';
                            axi_rlast   <= '1';
                            state_read  <= IDLE;
                        end if;
                    else 
                        axi_rvalid <= '0';
                    end if;
                 when others =>
                     state_read <= IDLE;
             end case;
		end if;
    end process axi_rd_proc;

    ----------------------------------------------
    -- WRITE Logic and FSM  
    ----------------------------------------------
    sb_wea              <= axi_wvalid and axi_wready_int;
    sb_data_wr          <= axi_wdata;
    axi_wready          <= axi_wready_int;

    axi_wr_proc : process (axi_aclk) is
    begin 
		if rising_edge(axi_aclk) then	
			case state_write is
				when IDLE =>
                    axi_wready_int  <= '0';
                    axi_bresp       <= (others => '0');
					if (axi_awvalid = '1') then
                        axi_awready         <= '1';
                        state_write <= ACK_WRITE_START;
					end if;
                when ACK_WRITE_START =>
                    addr_wr             <= "00" & axi_awaddr(addr_wr'left downto 2); --convert from byte to 32-bit word based addressing for counting
                    axi_awready         <= '0';
                    axi_wready_int      <= '1';
                    state_write         <= WRITING;
              --  when WAIT_FOR_WVALID =>
              --      axi_awready     <= '0';
              --      if(axi_wvalid='1')then
              --          --addr_wr     <= addr_wr + 1;
              --          state_write <= WRITING;
              --      end if;
                
                when WRITING =>
                    if(axi_wvalid='1') then
                        addr_wr     <= addr_wr + 1;
                    end if;
                    if(axi_wlast='1')then
                        axi_wready_int  <= '0';
                        axi_bvalid      <= '1';
                        state_write     <= WRITE_DONE_ACK;
                    end if;
                when WRITE_DONE_ACK =>
                    if(axi_bready = '1')then
                        axi_bvalid  <= '0';
                        state_write <= IDLE;
                    end if;
                 when others =>
                     state_write <= IDLE;
             end case;
		end if;
    end process axi_wr_proc;

end rtl;
