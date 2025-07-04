---------------------------------------------------------------------------------------------
--   ____  ____ 
--  /   /\/   / 
-- /___/  \  /   
-- \   \   \/    © Copyright 2011 Xilinx, Inc. All rights reserved.
--  \   \        This file contains confidential and proprietary information of Xilinx, Inc.
--  /   /        and is protected under U.S. and international copyright and other
-- /___/   /\    intellectual property laws.
-- \   \  /  \    
--  \___\/\___\ 
-- 
---------------------------------------------------------------------------------------------
-- Device:              Series-7
-- Author:              defossez
-- Entity Name:         RxGenClockMod
-- Purpose:             Clock generation for a SGMII Receiver.
--
-- MMCM frequency calculations
-- Input frequency: 125 MHz
-- Component: Kintex    -2 or -3 (These speed grades are strongly recomended for this design).
--                      -1 needs special care. The numbers that work for this speed grade are
--                          mentionned between [ ] brackets.
--                          Read also comments about -1 speed grade between [ ] brackets.
--        Fin_min     = 10 MHz
--        Fin_max     = 933 MHz [800]
--        Fvco_min    = 600 MHz
--        Fvco_max    = 1440 MHz [1200]
--        Fout_min    = 4.69 Mhz 
--        Fout_max    = 933 MHz [800]
--        Fpfd_min    = 10 MHz 
--        Fpfd_max    = 500 MHz [450] (Bandwidth set to High or Optimized.)
--        
--        Dmin = rndup Fin/Fpfd_max               => 1 <==
--        Dmax = Rnddwn Fin/Fpfd_min              => 12 
--        Mmin = (rndup Fvco_min/Fin) * Dmin      => 5
--        Mmax = rnddwn ((Dmax * Fvco_max)/Fin)   => 138 [115.5]
--        Mideal = (Dmin * Fvco_max) / Fin        => 11.52 [9.6] <==
--              Fvco must be maximized for best functioning of the VCO.
--              For easy calculation and use, the multiply factor will be taken
--              as a integer value close to the ideal multiplier setting the VCO
--              frequency as high as possible.
--              M is taken as 10, then Fvco is 1250 MHz (12 as M is too high, 1500 MHz)
--            [ For a -1, Fvcomax is 1200 MHz, this is too low when M = 10 and D = 1. ]
--            [ There is no ferquency other than 625 MMHz at which the VCO can run were ]
--            [ it is possible to use integer values for the counter dividers in the MMCM ]
--            [ clock outputs. the value for M remains is therefore reduced to 5. ]
--
--        Fvco = Fin * M/D          125 x 10/1  => 1250
--                                  [125 x 5/1  => 625]
--        Fout = Fin * M/D*O        Fout_Clk0  => D = 4.0322  ==> 310 MHz IDELAYCTRL ref clock.
--                                [ Fout_Clk0  => D = 3.125   ==> 200 MHz IDELAYCTRL ref clock. ]
--                                  Fout_Clk1  => D = 2 [1]    ==> 625 MHz  
--                                  Fout_Clk2  => D = 2 [1]    ==> 625 MHz
--                                  Fout_Clk3  => D = 4 [2]    ==> 312.5 MHz
--                                  Fout_Clk4  => D = 2 [1]    ==> 625 MHz
--                                  Fout_Clk5  => D = 4        |
--                                  Fout_Clk6  => D = 4        |==> Not Used
--
-- CLKOUT0 is used for the reference clock of the IDELAYCTRL component.
-- When the reference clock is set to 200 Mhz the tap delay is 78ps, when the clock is set
-- to 300 MHZ the tap delay is 52ps. The clock precission must be +- 10MHz.
-- The clock for the IDLEAYCTRL block can thus be set at 310MHz.
-- [ -1 speed grade                                                                         ]
-- [ CLKOUT0 is here also used as reference clock of the IDELAYCTRL component.              ]
-- [ The IDELAYCTRL in a -1 component cannot run at 310 MHz. The maximal speed is 200 MHz.  ]
-- [ Therefore the division factor 'D' of CLKOUT0 is set to 3.125.                          ]
-- 
-- Clock output 1 and 2 are used to generate 90-degrees shifted 625 MHz clocks.
--
-- Outputs 3 and 4 are used in FINE PHASE SHIFT mode (..._USE_FINE_PS = TRUE).
--
-- Because the reference clock, CLKOUT0, is now 312.5 MHz the "LifeIndicator", ""TimeTick", and
-- "AppsRstEna" circuits are running on this clock frequency.
-----------------------------------------------------------------------------------------------
-- Tools:               ISE_13.2
-- Limitations:         none
--
-- Vendor:              Xilinx Inc.
-- Version:             0.01
-- Filename:            RxGenClockMod.vhd
-- Date Created:        02 September, 2011
-- Date Last Modified:  02 September, 2011
---------------------------------------------------------------------------------------------
-- Disclaimer:
--		This disclaimer is not a license and does not grant any rights to the materials
--		distributed herewith. Except as otherwise provided in a valid license issued to you
--		by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
--		ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
--		WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
--		TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
--		PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
--		negligence, or under any other theory of liability) for any loss or damage of any
--		kind or nature related to, arising under or in connection with these materials,
--		including for any direct, or any indirect, special, incidental, or consequential
--		loss or damage (including loss of data, profits, goodwill, or any type of loss or
--		damage suffered as a result of any action brought by a third party) even if such
--		damage or loss was reasonably foreseeable or Xilinx had been advised of the
--		possibility of the same.
--
-- CRITICAL APPLICATIONS
--		Xilinx products are not designed or intended to be fail-safe, or for use in any
--		application requiring fail-safe performance, such as life-support or safety devices
--		or systems, Class III medical devices, nuclear facilities, applications related to
--		the deployment of airbags, or any other applications that could lead to death,
--		personal injury, or severe property or environmental damage (individually and
--		collectively, "Critical Applications"). Customer assumes the sole risk and
--		liability of any use of Xilinx products in Critical Applications, subject only to
--		applicable laws and regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES. 
--
-- Contact:    e-mail  hotline@xilinx.com        phone   + 1 800 255 7778
---------------------------------------------------------------------------------------------
-- Revision History:
--  Rev. 10 Oct 2011
--      Needed to put the common used components between the clock design of the transmitter
--      and the reciever in a common library. This due the fact that the ISE tool went nuts
--      when finding files with the same name in different directories of the design.
------------------------------------------------------------------------------
-- Naming Conventions:
--  Generics start with:                        "C_*"
--  Ports
--      All words in the label of a port name start with a upper case, AnInputPort.
--      Active low ports end in                             "*_n"
--      Active high ports of a differential pair end in:    "*_p"
--      Ports being device pins end in _pin                 "*_pin"
--      Reset ports end in:                                 "*Rst"
--      Enable ports end in:                                "*Ena", "*En"
--      Clock ports end in:                                 "*Clk", "ClkDiv", "*Clk#"
--  Signals and constants
--      Signals and constant labels start with              "Int*"
--      Registered signals end in                           "_d#"
--      User defined types:                                 "*_TYPE"
--      State machine next state:                           "*_Ns"
--      State machine current state:                        "*_Cs"
--      Counter signals end in:                             "*Cnt", "*Cnt_n"
--   Processes:                                 "<Entity_><Function>_PROCESS"
--   Component instantiations:                  "<Entity>_I_<Component>_<Function>"
---------------------------------------------------------------------------------------------
library IEEE;
	use IEEE.std_logic_1164.all;
	use IEEE.std_logic_UNSIGNED.all;
library UNISIM;
	use UNISIM.vcomponents.all;
library Common;
    use Common.all;
---------------------------------------------------------------------------------------------
-- Entity pin description
---------------------------------------------------------------------------------------------
--      GENERICS
--  C_GenMmcmLoc    : Location constraint for the MMCM
--  C_UseFbBufg     : '1' = use a BUFG in the feedback loop.
--  C_UseBufg       : A '1' in the vector = Use BUFG in the clock paths.
--                  : std_logic_vector(5 downto 0), 5 = ClkOut5 & 0 = ClkOut0
-- -- Reset and enable stuff
-- C_PrimRstOutDly : Delay on the primary reset, most of the time used for the IDELAYCTRL.RST  
-- C_UseRstOutDly  : Use a delay on the reset synchronous to a MMCM clock?
-- C_RstOutDly     : The delay that the above enable reset gets.
-- C_EnaOutDly     : After the reset is released, the delay of the enable.
-- C_Width         : With of the blinked circuit.
-- C_AlifeFactor   : Frequency of the blinker
-- C_AlifeOn       : What output, defined by C_Width, gets a blinking circuit.
--      PORTS
--  Mmcm_ClkIn1     : MMCM clock input.
--  Mmcm_ClkIn2     : MMCM clock input.
--  Mmcm_ClkInSel   : MMCM clock input.
--
--  Mmcm_ClkFbOut   : MMCM Feedback output, can be internal to the FPGA but can also be on the PCB.
--  Mmcm_ClkFbIn    : MMCM feedback input, When from external a IBUFG is needed.
--
--  Mmcm_RstIn      : System reset input.
--  Mmcm_EnaIn      : Enable input, let the system start.

--  Mmcm_SysClk0    : Clock 0 output
--  Mmcm_SysClk1    : Clock 1 output
--  Mmcm_SysClk2    : Clock 2 output
--  Mmcm_SysClk3    : Clock 3 output 
--  Mmcm_SysClk4    : Clock 4 output 
--  Mmcm_SysClk5    : Clock 5 output |==> Not Used Here
--  Mmcm_SysClk5    : Clock 6 output |
--
--  Mmcm_AliveOut   : Pulsing output to show the MMCM is locked adn functional.
--  Mmcm_PrimRstOut : 'x' clock cycles after the MMCM is locked this reset will be released
--  Mmcm_RstOut     : 'x' clock cycles after external events this reset will be released
--  Mmcm_EnaOut     : 'x' clcok cycles after above reset is release this enable will go active.
--  Mmcm_ReadyIn    : input from IDELAYCTRL.RDY
--
--  Mmcm_Drp_Di     : DRP port
--  Mmcm_Drp_Addr   : DRP port
--  Mmcm_Drp_We     : DRP port
--  Mmcm_Drp_En     : DRP port
--  Mmcm_Drp_Clk    : DRP port
--  Mmcm_Drp_Do     : DRP port
--  Mmcm_Drp_Rdy    : DRP port
--
--  Mmcm_PsIncDec   : Phase shift of the MMCM
--  Mmcm_Psen       : Phase shift of the MMCM
--  Mmcm_PsClk      : Phase shift of the MMCM
--  Mmcm_PsDone     : Phase shift of the MMCM
--
--  Mmcm_TimeTick_Fast  : Pulsing output followin a 1/2 second rate
--  Mmcm_TimeTick_Slow  : Pulsing output folling a sec rate.
-----------------------------------------------------------------------------------------------
entity RxGenClockMod is
    generic (
        -- MMCM related stuff
        C_AppsMmcmLoc   : string;
        C_UseFbBufg     : integer := 0;
        C_UseBufg       : std_logic_vector(6 downto 0) := "0011001"; -- "0011001";
        -- Reset and enable stuff
        C_PrimRstOutDly : integer := 2;
        C_UseRstOutDly  : integer := 1;
        C_RstOutDly     : integer := 6;
        C_EnaOutDly     : integer := 8;
        -- Stuff for LED.
        C_Width         : integer := 1;
        C_AlifeFactor   : integer := 5;
        C_AlifeOn       : std_logic_vector(7 downto 0) := "00000001"
    );
    port (
        Mmcm_ClkIn1         : in std_logic;
        Mmcm_ClkIn2         : in std_logic;
        Mmcm_ClkInSel       : in std_logic;
        Mmcm_ClkFbOut       : out std_Logic;
        Mmcm_ClkFbIn        : in std_Logic;
        Mmcm_RstIn          : in std_Logic;
--        Mmcm_EnaIn          : in std_Logic;
        Mmcm_SysClk0        : out std_logic;
        Mmcm_SysClk1        : out std_logic;
        Mmcm_SysClk2        : out std_logic;
        Mmcm_SysClk3        : out std_logic;
        Mmcm_SysClk4        : out std_logic;
        Mmcm_SysClk5        : out std_logic;
        Mmcm_SysClk6        : out std_logic;
        Mmcm_Locked         : out std_logic;
        Mmcm_AliveOut       : out std_logic;
        Mmcm_PrimRstOut     : out std_Logic;
        Mmcm_RstOut_SysClk3         : out std_logic;
        Mmcm_RstOut_SysClk5         : out std_logic;
        Mmcm_EnaOut         : out std_logic;
        Mmcm_ReadyIn        : in std_Logic;
        --
        Mmcm_Drp_Di         : in std_logic_vector(15 downto 0);
        Mmcm_Drp_Addr       : in std_logic_vector(6 downto 0);
        Mmcm_Drp_We         : in std_logic;
        Mmcm_Drp_En         : in std_logic;
        Mmcm_Drp_Clk        : in std_logic;
        Mmcm_Drp_Do         : out std_logic_vector(15 downto 0);
        Mmcm_Drp_Rdy        : out std_logic;
        --
        Mmcm_PsIncDec       : in std_logic;
        Mmcm_Psen           : in std_logic;
        Mmcm_PsClk          : in std_logic;
        Mmcm_PsDone         : out std_logic
        
--        Mmcm_TimeTick_Fast  : out std_logic;
--        Mmcm_TimeTick_Slow  : out std_logic
    );
end entity RxGenClockMod;
-----------------------------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------------------------
architecture RxGenClockMod_struct of RxGenClockMod is
-----------------------------------------------------------------------------------------------
-- Component Instantiation
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-- Constants, Signals and Attributes Declarations
-----------------------------------------------------------------------------------------------
-- Functions
-- Constants
constant Low  : std_logic   := '0';
constant High : std_logic   := '1';
-- Signals
signal IntMmcm_Bufg_SysClk      : std_logic_vector(6 downto 0);
signal IntMmcm_Bufg_ClkFbOut    : std_logic;
signal IntMmcm_SysClk   : std_logic_vector(6 downto 0);
signal IntMmcm_ClkFbOut : std_logic;
signal IntMmcm_Locked   : std_logic;
signal IntMmcm_EnaOut   : std_logic;
signal IntMmcm_RstOut_SysClk3   : std_logic;
signal IntMmcm_RstOut_SysClk5   : std_logic;
signal IntAliveIn       : std_logic_vector(0 downto 0);
signal IntAliveOut      : std_logic_vector(0 downto 0);
-- Attributes
attribute KEEP_HIERARCHY : string;
    attribute KEEP_HIERARCHY of RxgenClockMod_struct : architecture is "YES";
attribute LOC : string;
-- this should be placed correctly by vivado
--    attribute LOC of RxGenClockMod_I_Mmcm_Adv : label is C_AppsMmcmLoc;
-----------------------------------------------------------------------------------------------
begin
-----------------------------------------------------------------------------------------------
RxGenClockMod_I_Mmcm_Adv : MMCME2_ADV
    generic map (
        BANDWIDTH               => "OPTIMIZED", -- string
        CLKIN1_PERIOD           => 10.000,         -- real -- was 125 MHz (8), is now 100.0 MHz
        CLKIN2_PERIOD           => 0.0,         -- real
        REF_JITTER1             => 0.010,       -- real --
        REF_JITTER2             => 0.0,         -- real
        DIVCLK_DIVIDE           => 1,           -- integer  --
        CLKFBOUT_MULT_F         => 8.0,        -- real  -- [ -1: => 5.0, ]
        CLKFBOUT_PHASE          => 0.0,         -- real
        CLKFBOUT_USE_FINE_PS    => FALSE,       -- boolean
        -- refclk_frequency must be 190-210, 290-310, or 390-410 MHz
        -- https://www.xilinx.com/support/documentation/user_guides/ug471_7Series_SelectIO.pdf
        -- https://www.xilinx.com/support/documentation/application_notes/xapp523-lvds-4x-asynchronous-oversampling.pdf
        -- hitting 310.0 with 102.4 MHz input
        -- this divider is the bit clock/ref_clk
        -- 1250/310 = 4.0322
        -- 1024/310 = 3.3032
        -- 1024/390 = 2.6256 (Must be in sync with settings in Receiver generic
        -- C_IdlyCntVal_M/S and C_RefClkFreq) see check_byte.vhd
        -- switched to traget 290 because 390 is used and it's not clear what the requirement is.
        -- xapp523 claims "ideally running at 312.5 MHz"
        -- if that's for 1250 then maybe we should be at targeting 256 for 1024 MHz?
        -- then 290 is closest?

        -- [DRC AVAL-139] MMCME2_ADV Phase shift and divide attr checks: The MMCME2_ADV cell block_design_i/telem_0/inst/check_telemetry_1/Receiver_0/Receiver_I_RxGenClockMod/RxGenClockMod_I_Mmcm_Adv has a fractional CLKOUT0_DIVIDE_F value (3.531) which is not a multiple of the hardware granularity (0.125) and will be adjusted to the nearest supportable value. Please update the design to use a valid value.
        -- when trying 4.8750: [DRC AVAL-29] IODELAY_RefClkFreq_alt: Invalid configuration. IDELAYE2 block_design_i/telem_0/inst/check_telemetry_1/Receiver_0/Gen_1[1].Receiver_I_SgmiiRxData/SgmiiRxData_I_Idlye2_M has an invalid REFCLK_FREQUENCY value (210.051000). Only values from 190-210, 290-310, or 390-410 are allowed. Resolution: Change the timing requirements.
        -- can't do that, so slow it down.

        -- targeting 200MHz (close enough to 1/4 of line rate)
        -- must match check_telemetry.vhd Receiver setting for C_RefClkFreq
        CLKOUT0_DIVIDE_F        => 4.000,      -- real  -- [ -1: => 3.125, ]
        --CLKOUT0_DIVIDE_F        => 2.6256,      -- real  -- [ -1: => 3.125, ]
        CLKOUT0_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT0_PHASE           => 0.0,         -- real
        CLKOUT0_USE_FINE_PS     => FALSE,       -- boolean
        CLKOUT1_DIVIDE          => 2,           -- integer  -- [ -1: => 1, ]
        CLKOUT1_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT1_PHASE           => 0.0,         -- real
        CLKOUT1_USE_FINE_PS     => FALSE,       -- boolean
        CLKOUT2_DIVIDE          => 2,           -- integer  -- [ -1: => 1, ]
        CLKOUT2_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT2_PHASE           => 90.000,      -- real  --
        CLKOUT2_USE_FINE_PS     => FALSE,       -- boolean
        CLKOUT3_DIVIDE          => 4,           -- integer -- [ -1: => 2, ]
        CLKOUT3_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT3_PHASE           => 0.0,         -- real
        CLKOUT3_USE_FINE_PS     => TRUE,        -- boolean  --
        CLKOUT4_CASCADE         => FALSE,       -- boolean
        CLKOUT4_DIVIDE          => 2,           -- integer -- [ -1: => 1, ]
        CLKOUT4_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT4_PHASE           => 0.0,         -- real
        CLKOUT4_USE_FINE_PS     => TRUE,        -- boolean  --
        CLKOUT5_DIVIDE          => 4,           -- integer -- [ -1: => 2, ]
        CLKOUT5_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT5_PHASE           => 0.0,         -- real
        CLKOUT5_USE_FINE_PS     => FALSE,       -- boolean
        CLKOUT6_DIVIDE          => 4,           -- integer -- [ -1: => 2, ]
        CLKOUT6_DUTY_CYCLE      => 0.5,         -- real
        CLKOUT6_PHASE           => 0.0,         -- real
        CLKOUT6_USE_FINE_PS     => FALSE,       -- boolean
        COMPENSATION            => "ZHOLD",     -- string
        STARTUP_WAIT            => FALSE        -- boolean
    )
    port map (
        CLKIN1          => Mmcm_ClkIn1,             -- in
        CLKIN2          => Mmcm_ClkIn2,             -- in
        CLKINSEL        => Mmcm_ClkInSel,           -- in
        CLKFBIN         => Mmcm_ClkFbIn,            -- in
        CLKOUT0         => IntMmcm_Bufg_SysClk(0),  -- out
        CLKOUT0B        => open,                    -- out
        CLKOUT1         => IntMmcm_Bufg_SysClk(1),  -- out
        CLKOUT1B        => open,                    -- out
        CLKOUT2         => IntMmcm_Bufg_SysClk(2),  -- out
        CLKOUT2B        => open,                    -- out
        CLKOUT3         => IntMmcm_Bufg_SysClk(3),  -- out
        CLKOUT3B        => open,                    -- out
        CLKOUT4         => IntMmcm_Bufg_SysClk(4),  -- out
        CLKOUT5         => IntMmcm_Bufg_SysClk(5),  -- out
        CLKOUT6         => IntMmcm_Bufg_SysClk(6),  -- out
        CLKFBOUT        => IntMmcm_Bufg_ClkFbOut,   -- out
        CLKFBOUTB       => open,                    -- out
        CLKINSTOPPED    => open,                    -- out
        CLKFBSTOPPED    => open,                    -- out
        LOCKED          => IntMmcm_Locked,          -- out
        PWRDWN          => Low,             -- in
        RST             => Mmcm_RstIn,      -- in
        DI              => Mmcm_Drp_Di,     -- in
        DADDR           => Mmcm_Drp_Addr,   -- in
        DCLK            => Mmcm_Drp_Clk,    -- in
        DEN             => Mmcm_Drp_En,     -- in
        DWE             => Mmcm_Drp_We,     -- in
        DO              => Mmcm_Drp_Do,     -- out
        DRDY            => Mmcm_Drp_Rdy,    -- out
        PSINCDEC        => Mmcm_PsIncDec,   -- in
        PSEN            => Mmcm_PsEn,       -- in
        PSCLK           => Mmcm_PsClk,      -- in
        PSDONE          => Mmcm_PsDone      -- out
    );
-----------------------------------------------------------------------------------------------
Gen_1 : for n in 0 to 6 generate
    Gen_10 : if C_UseBufg(n) = '0' generate
        IntMmcm_SysClk(n) <= IntMmcm_Bufg_SysClk(n);
    end generate Gen_10;
    --Gen_11 : if C_UseBufg(n) = '1' generate
    --    RxGenClockMod_I_Bufg_Clk :
            IntMmcm_SysClk(n) <= IntMmcm_Bufg_SysClk(n);
            --        BUFG port map (I => IntMmcm_Bufg_SysClk(n), O => IntMmcm_SysClk(n));    
    --end generate Gen_11;
end generate Gen_1;
--
Gen_2 : if C_UseFbBufg = 0 generate
    IntMmcm_ClkFbOut <= IntMmcm_Bufg_ClkFbOut;
end generate Gen_2;
--
Gen_3 : if C_UseFbBufg = 1 generate
    RxGenClockMod_I_Bufg_ClkFbOut :
            BUFG port map (I => IntMmcm_Bufg_ClkFbOut, O => IntMmcm_ClkFbOut);
end generate Gen_3;
--
Mmcm_SysClk0 <= IntMmcm_SysClk(0);
Mmcm_SysClk1 <= IntMmcm_SysClk(1);
Mmcm_SysClk2 <= IntMmcm_SysClk(2);
Mmcm_SysClk3 <= IntMmcm_SysClk(3);
Mmcm_SysClk4 <= IntMmcm_SysClk(4);
Mmcm_SysClk5 <= IntMmcm_SysClk(5);
Mmcm_SysClk6 <= IntMmcm_SysClk(6);
Mmcm_ClkFbOut <= IntMmcm_ClkFbOut;
Mmcm_Locked <= IntMmcm_Locked;
-----------------------------------------------------------------------------------------------
RxGenClockMod_I_LifeIndicator : entity Common.LifeIndicator
    generic map (
        C_Width             => 1,
        C_AlifeFactor       => 5,
        C_AlifeOn           => "00000001"
    )
    port map (
        RefClkIn    => IntMmcm_SysClk(0), -- Clocked at 312.5 MHz
        LifeRst     => Mmcm_RstIn,
        LifeIn      => IntAliveIn,
        LifeOut     => IntAliveOut
    );
IntAliveIn(0) <= IntMmcm_Locked;
Mmcm_AliveOut <= IntAliveOut(0);
-----------------------------------------------------------------------------------------------
RxGenClockMod_I_AppsRstEna : entity Common.AppsRstEna
    generic map (
        C_PrimRstOutDly => C_PrimRstOutDly,
        C_UseRstOutDly  => C_UseRstOutDly,
        C_RstOutDly     => C_RstOutDly,
        C_EnaOutDly     => C_EnaOutDly
    )
    port map (
        Locked      => IntMmcm_Locked,      -- in
        Rst         => Mmcm_RstIn,          -- in
        SysClkIn    => Mmcm_ClkIn1,         -- in -- When CLKIN2 is used modify this line.
        ExtRst      => Low,                 -- in
        ReadyIn     => Mmcm_ReadyIn,        -- in
        ClkIn       => IntMmcm_SysClk(3),   -- in -- Clocked at 312.5 MHz - CLKDIV
        PrimRstOut  => Mmcm_PrimRstOut,     -- out
        RstOut      => IntMmcm_RstOut_SysClk3,      -- out ClkIn domain (IntMmcm_SysClk(3))
        EnaOut      => IntMmcm_EnaOut       -- out ClkIn domain (IntMmcm_SysClk(3))
        );

AppsRstEna_I_LocalRstEna : entity Common.LocalRstEna
    generic map (
        C_LocalUseRstDly => C_UseRstOutDly,
        C_LocalRstDly => C_RstOutDly,
        C_LocalEnaDly => C_EnaOutDly
    )
    port map (
        ClkIn     => IntMmcm_SysClk(5),     -- in
        Ena       => Mmcm_ReadyIn,   -- in
        Rst       => Low,    -- in
        RstOut    => IntMmcm_RstOut_SysClk5,    -- out
        EnaOut    => open     -- out
    );


        
Mmcm_RstOut_SysClk3 <= IntMmcm_RstOut_SysClk3;
Mmcm_RstOut_SysClk5 <= IntMmcm_RstOut_SysClk5;
Mmcm_EnaOut <= IntMmcm_EnaOut;
-----------------------------------------------------------------------------------------------
-- The purpose of this circuit is to generate a regular clock tick.
-- The tick is as wide as one input clock cycle.
-- The frequency of the tick depents from: Input clock, division, and etcetera.
-- Except the input clock, who is connected here, the other things that determine the 
-- occurence of the tick must be set in the /JesdAppsClk/Vhdl/TimeTickCnt.vhd file.
-- For this design the tick occurs every 1 ms (the input clock is 200 MHz).
--RxGenClockMod_I_TimeTickCnt : entity Common.TimeTickCnt
--    port map (
--        RefClkIn        => IntMmcm_SysClk(0), -- in -- Clocked at 312.5 MHz
--        TickEna         => IntMmcm_EnaOut,  -- in
--        TickOut_Fast    => Mmcm_TimeTick_Fast,  -- out  
--        TickOut_Slow    => Mmcm_TimeTick_Slow   -- out  
--    );
---------------------------------------------------------------------------------------------
end RxGenClockMod_struct;
--
