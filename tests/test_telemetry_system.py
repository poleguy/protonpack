# for testing ADXR/ATLAS telemetry
# Top level testbench instantiation file of dpsm_rx top and telem
# mobile top to simulate the entire serial telemetry system.
# checks to see a number of packets appear at the alchitry packet_valid signal.

# open sim waveforms with:
# gtkwave tests/sim_build/test_telemetry_serialize/test_main/verilog.dump
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer
#from cocotb_test.simulator import run
import tests.verilator as verilator
# can't use the format from cocotb.result import TestFailure because it trys to collect it as a test.
import cocotb.result 
import os

from tests.conftest import root_dir

import logging
# give this module its own logger, tied to its namespace.
# This will inherit the output location of the module that calls this
log = logging.getLogger(__name__) 


###################################################################################
## pytest entry point
###################################################################################
# pytest entry point must contain the string test because of stupid pytest magic
def test_main(no_compile, waves):
    """ Execute test"""
    recompile=not no_compile

    ## setup the run directory in root_dir/tests/sim_build/......
    run_dir=verilator.setup_sim_dir(delete_existing=recompile)
    if waves:
        do = "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; log -r /*; run -a; quit"
    else:
        do = "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; run -a; quit"

    verilator.run_rtl_sim_verilator(
        compile_txt_files_list=[  # root_dir+"/modules/telemetry/compile.txt",
            # root_dir+"/rtl/xapp523/compile.txt",
            os.path.join(root_dir, "tests/compile_telem_boards.txt")
            #root_dir + "/rtl/xapp523/glbl.v",
            # root_dir+"/tests/compile_unisim_lib.txt"
        ],
        #top_level="shure.tb_telemetry_serialize shure.glbl",
        cocotb_toplevel="tb_telem_boards",
        rtl_run_path           = run_dir,
        #simulator              = "cvc",
        do_argument=do,
        compile_rtl=recompile
        #cocotb_enable=True,
        # rtl_run_opts           = "-ieee_nowarn -L unisims_ver -L secureip -L shure -L src",
        #          cocotb_top_is_verilog  = True,
        #          root_design_path=root_dir
    )



async def force_triggers(dut):

    # this _discover_all code is fragile... it may fail cryptically if one of the objects does not exist
    # todo: catch this type of error message and warn the user about flaky _discover_all()
    # INFO     root:cocotb_support.py:86 # ** Warning: (vsim-3116) Problem reading symbols from /home/****/workspace/FPGA/Wideband/NGPSM_RX_Sim/dpsm_rx/cenv/lib/python3.7/site-packages/cocotb/libs/libcocotbfli_modelsim.so : module was loaded at an absolute address.
    # ...
    # ERROR    root:cocotb_support.py:80 # ** Warning: (vsim-3116) Problem reading symbols from /home/****/workspace/FPGA/Wideband/NGPSM_RX_Sim/dpsm_rx/cenv/lib/python3.7/lib-dynload/_dateti     0.00ns ERROR    FATAL: We are calling up again
    # ...
    # # Attempting stack trace sig 11
    # # Signal caught: signo [11]
    # # vsim_stacktrace.vstf written
    # # Current time Wed May 11 16:54:46 2022
    # # ModelSim DE Stack Trace
    # # Program = vsim
    # # Id = "10.6a"
    # # Version = "2017.03"
    # # Date = "Mar 16 2017"
    # # Platform = linuxpe
    # ...
    #
    # ** Fatal: (SIGSEGV) Bad pointer access. Closing vsimk.
    # ** Fatal: vsimk is exiting with code 211.
    # Exit codes are defined in the "Error and Warning Messages"
    # appendix of the ModelSim User's Manual.


    #dut.alchitry_top.dpsm_rx_datapath.test_pattern_inst._discover_all()
    #dut.alchitry_top.dpsm_rx_datapath.test_counters_inst._discover_all()
    while(True):
        await Timer(500, 'ns')
        #dut.alchitry_top.dpsm_rx_datapath.test_pattern_inst.r_trigger_ctr.value = 0x1FFFF
        await Timer(500, 'ns')
        #dut.alchitry_top.dpsm_rx_datapath.test_counters_inst.r_trigger_ctr.value = 0x3FFFF




##############################################################
# coccotb entry point 
# automagically used via rtl_tools.run_rtl_sim when cocotb_enable = True
##############################################################

@cocotb.test()
async def cocotb_tone_gen(dut):
    """ check that data from serializer makes it through the system
    """
    dut._log.info(f"sim start")
    #listen_host, listen_port = debugpy.listen(("localhost", 5678))
    #cocotb.log.info("Waiting for Python debugger attach on {}:{}".format(listen_host, listen_port))
    # Suspend execution until debugger attaches
    #debugpy.wait_for_client()




    #### !!Necessary when instantiating mixed design verilog module into vhdl top.!!
    #dut.alchitry_top._discover_all()
    #dut._log.info(f"discovery alchitry done")
    #dut.alchitry_top.gen_telem._discover_all()
    #dut._log.info(f"discovery  gen_telem done")
    #dut.alchitry_top.gen_telem.telemetry_serialize_0._discover_all()

    dut._log.info(f"discovery done")

    ######################################
    ## Clocks
    ######################################
    cocotb.start_soon(telemetry_serialize_clocks(dut))
    cocotb.start_soon(alchitry_clocks(dut))

    dut._log.info(f"clocks done")

    ######################################
    ## Telemetry - serial bypass
    ######################################
    fifo_list=[]
    cocotb.start_soon(telem_bytes_collect(dut.telemetry_serialize, fifo_list))
    cocotb.start_soon(telem_bytes_inject(dut.alchitry_top, fifo_list))

    dut._log.info(f"inject done")

    ######################################
    ## telemetry_serialize Stimulus
    ######################################
    #cocotb.start_soon(gen_tone(dut.alchitry_top))
    cocotb.start_soon(force_triggers(dut))


    # todo: get it to stop when it hits a certain memory usage.

    dut._log.info(f"triggers done")
    
    ######################################
    ## telemetry_serialize Stimulus
    ######################################

    await Timer(1, unit='ns') # wait to prevent crash at start line
    
    # wait for a few clocks before starting fm
    #for ii in range(0,100):
    #    await FallingEdge(dut.alchitry_top.clk_64mhz_fpga)

        
    dut._log.info("let it go")    
    # let it go
    

    # If you don't do a discover_all() on a verilog block under a vhdl block you'll get a cryptic error like this:
    # If you spell a signal wrong (telemtry anyone?) that you're trying to set, it'll blow up
    # with a very cryptic error
    # todo: Ask Alex if there is a way to catch this and try to explain the warning...
    # todo: or can we report this to cocotb and get a fix so the tool is more robust?

    # ** Fatal: (vsim-4) ****** Memory allocation failure. *****
    # Attempting to allocate 4124280344 bytes
    # Please check your system for available memory and swap space.
    # ** Fatal: (vsim-4) ****** Memory allocation failure. *****
    # Attempting to allocate 4124280320 bytes
    # Please check your system for available memory and swap space.
    # # Attempting stack trace sig 11
    # # Signal caught: signo [11]
    # # vsim_stacktrace.vstf written
    # # Current time Fri May 13 09:22:55 2022
    # # ModelSim DE Stack Trace
    # # Program = vsim
    # # Id = "10.6a"
    # # Version = "2017.03"
    # # Date = "Mar 16 2017"
    # # Platform = linuxpe

    #dut.alchitry_top.gen_datapath.dpsm_rx_datapath._discover_all()
    #dut._log.info("discover all output:")    
    #for item in dut.alchitry_top.gen_datapath._sub_handles.items():
    #    dut._log.info(item)
    #dut._log.info("discover all output:")    
    #for item in dut.alchitry_top.gen_datapath.dpsm_rx_datapath._sub_handles.items():
    #    dut._log.info(item)
        #if isinstance(item, HierarchyObject):
        #    for obj in HierarchyObject._sub_handles.items():
        #        dut._log.info("hierarchy object")
        #        dut._log.info(item)

    #dut._log.info('genblk1')
    #dut.alchitry_top.gen_datapath.dpsm_rx_datapath.gen_telem._discover_all()
    #for item in dut.alchitry_top.gen_datapath.dpsm_rx_datapath.gen_telem._sub_handles.items():        
     #   dut._log.info(item)

   #dut.alchitry_top.gen_datapath.dpsm_rx_datapath.gen_telem.dpsm_rx_telemetry_inst._discover_all()
    #dut.alchitry_top.gen_datapath.dpsm_rx_datapath.gen_telem.dpsm_rx_telemetry_inst.telemetry_config_inst._discover_all()


    # set rate count for sim to not be a slow 100ms, but a snappy 500us
    # reg [31:0] 			 r_telemetry_metadata_trigger_rate_count = 32'h00c35000; // 100 ms
    #dut.alchitry_top.gen_datapath.dpsm_rx_datapath.dpsm_rx_telemetry_inst.telemetry_config_inst.r_telemetry_metadata_trigger_rate_count.value = 0xfa00 # 500us
    #dut.alchitry_top.gen_datapath.dpsm_rx_datapath.gen_telem.dpsm_rx_telemetry_inst.telemetry_config_inst.r_telemetry_metadata_trigger_rate_count.value = 0x100 # 2us

    # enable telemetry output
    # should be on by default
    #dut.alchitry_top.telemetry_1.TELEMETRY_CONTROL_ENABLE_i.value = 1
    # set mux to use regular datapath telemetry
    #dut.alchitry_top.telemetry_1.TELEMETRY_CONTROL_IQ_ENABLE_i.value = 0

    # hit register
    #simple_bus_write(dut.alchitry_top, 0x2c20, 0x11800)
    
    

    dut._log.info(f"w/r a telemetry config")
        
    ## Turn on the test telemetry streams 15+16
    # turn this on and the whole thing crashes... for now this test only effectively checks syntax errors etc.
    #await spi_write(dut.alchitry_top, 0x2c20, 0x1c000) # 16 is enable, 15 is meta, 14 is B
    #await spi_write(dut.alchitry_top, 0x2c20, 0x1A000) # 16 is enable, 15 is meta, 13 is A
    #await spi_write(dut.alchitry_top, 0x2c20, 0x12000) # 16 is enable, 15 is meta, 13 is A

    
    


    ######################################
    ## Telemetry - wait for packet output
    ######################################
    packets=14
    # todo: change this check to timeout if we don't see the packets at the expected time
    for p in range(0,packets):
        dut._log.info(f"Waiting for packet {p+1} of {packets}..")
        dut._log.info("packet")        
        #await FallingEdge(dut.alchitry_top.ethernet_telemetry_subsystem.mobile_telem_to_eth.telemetry.rd_en[15]) #stream0 rd_en goes low when packet output is done
        await cocotb.triggers.with_timeout(FallingEdge(dut.alchitry_top.packet_valid),
                                    200, "us") #stream0 rd_en goes low when packet output is done
                                    # try to run long enough to get a whole packet? ~180 us for the first one then ~100 us 
                                    # if we expect this to timeout in error, we can set it long enough to debug the output if it does

    await Timer(1, unit='us') # wait to make sure packet fully propogated to pcapng

    
    dut._log.info(f"sim done")


async def telem_bytes_collect(telemetry_serialize, fifo_list):
    """ Collect the telemetry data from dpsm_rx every valid.
    Need the byte data and indicator for whether it is a k-char.
    fifo_list is list of [byte, data_is_k]

    Byte is valid every clock to get the proper rate.
    """
    while(True):
        await FallingEdge(telemetry_serialize.clk)
        if(telemetry_serialize.valid_enc_in.value):
            #print(f"data: {telemetry_serialize.gen_telem.telemetry_serialize_0.data_enc_in.value}")
            data = resolve_x_to_0(telemetry_serialize.data_enc_in.value)
            
            k = telemetry_serialize.k_enc_in.value
            fifo_list.append([data, k])
      #  if(k==0):
      #      telemetry_serialize._log.info(f"data={hex(data)}")

def resolve_x_to_0(signal_value):
    # takes in a byte value that may have x's in it, and returns a byte value with 0's in place of the x's
    byte_value = str(signal_value)

    resolved_value = ""
    # Resolve each character in the byte value
    for char in byte_value:
        if char.lower() in ["x", "z"]:
            # Replace 'x' or 'z' with '0'
            resolved_value += "0"
        else:
            # Keep '0' or '1' as is
            resolved_value += char

    # Convert the resolved string of bits back to an integer if needed
    if resolved_value == "":
        # convert binary string to int
        resolved_integer_value = int(signal_value, 2) 
    else:
        resolved_integer_value = int(resolved_value, 2)
        

    return resolved_integer_value

async def telem_bytes_inject(alchitry_top, fifo_list):
    """ Inject bytes into telemetry receiver side to bypass serial.
    gt_unpack_telemetry should be reference to gt_unpack_telemetry module.
    fifo_list is list of [byte, data_is_k]
    """

    # set default at startup
    alchitry_top.gt_unpack_telemetry.gt_data.value = cocotb.handle.Force(0)
    alchitry_top.gt_unpack_telemetry.gt_data_is_k.value = cocotb.handle.Force(0)

    alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// spinning')
    ## spin and wait for the fifo to fill up with 12 bytes (3 GT outputs)
    while(len(fifo_list)<12):
        await FallingEdge(alchitry_top.gt_unpack_telemetry.clk_256M)

    #from remote_pdb import RemotePdb; rpdb = RemotePdb("127.0.0.1", 4000)
    alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// starting')
    cnt_show_first=0
    while(True):
        await FallingEdge(alchitry_top.gt_unpack_telemetry.gt_clk)
        #alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// trying')
        if(len(fifo_list)>=4):
            #alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// working')
            # GT outputs 4 bytes at once on 128MHz gt clock
            data_4byte=0
            k_4byte=0
            for ii in range(0,4):
        #        rpdb.set_trace()
                item=fifo_list.pop(0) # pop oldest byte
                byte=int(item[0])  # int to fix: TypeError: unsupported operand type(s) for <<: 'coroutine' and 'int'
                k=item[1]
                data_4byte += byte << (8*ii) # oldest byte is lowest signifant byte
                k_4byte += int(k) << ii # same for k indicator

            ## Assign values at top level sim should instantiate empty GT
            #bv = BinaryValue(n_bits=32)
            #bv.integer =  data_4byte            
            #alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// gt_data {alchitry_top.gt_unpack_telemetry.gt_data.value}')
            #alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// data_4byte {data_4byte}')

            # can only drive it where there are no other drivers in verilator
            alchitry_top.gt_serial_telem_rx_subsystem.gt_serial_telem_rx_i.gt0_rxdata_out.value = data_4byte
            alchitry_top.gt_serial_telem_rx_subsystem.gt_serial_telem_rx_i.gt0_rxcharisk_out.value = k_4byte
            #alchitry_top.gt_unpack_telemetry.gt_data.value = cocotb.handle.Force(data_4byte)  # BinaryValue was swapping stuff. uck.
            #alchitry_top.gt_unpack_telemetry.gt_data_is_k.value = cocotb.handle.Force(k_4byte)
            #alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// gt_data {alchitry_top.gt_unpack_telemetry.gt_data.value}')
            if(cnt_show_first<600): # long enough to see actual iq data flowing
                alchitry_top.gt_unpack_telemetry._log.info(f'//telem_bytes_inject// len(fifo_list)={len(fifo_list)} Injecting gt data:{hex(data_4byte)} data_is_k:{hex(k_4byte)}')
                # Break into debugger for user control
                #breakpoint()  # or debugpy.breakpoint() on 3.6 and below

                cnt_show_first+=1

        else:
            raise Exception(f'telem_bytes_inject starved. Need 4 bytes but len(fifo_list )={len(fifo_list)}')


async def telemetry_serialize_clocks(dut):
    #cocotb.start_soon(Clock(dut.alchitry_top.clk_64mhz_fpga, 15.624, unit='ns').start())
    #cocotb.start_soon(Clock(dut.alchitry_top.ADC_CLKOUTp, 31.248, unit='ns').start())
    #cocotb.start_soon(Clock(dut.alchitry_top.ADC_CLKOUTn, 31.248, unit='ns').start(start_high=False))
    pass


async def alchitry_clocks(dut):
    # create clock
    # Clock tries to divide number by 2, so make sure it's "even"
    # 200 MHz
    cocotb.start_soon(Clock(dut.SYSCLKP_I, 5.000, unit='ns').start())
    cocotb.start_soon(Clock(dut.SYSCLKN_I, 5.000, unit='ns').start(start_high=False))

    # 128MHz
    cocotb.start_soon(Clock(dut.user_clk_p, 7.812, unit='ns').start())
    cocotb.start_soon(Clock(dut.user_clk_n, 7.812, unit='ns').start(start_high=False))

    # 128MHz
    cocotb.start_soon(Clock(dut.GTREFCLK1P_I, 7.812, unit='ns').start())
    cocotb.start_soon(Clock(dut.GTREFCLK1N_I, 7.812, unit='ns').start(start_high=False))

    # set default inputs to design
    #dut.stream_enables[0].value = 0xFFFFFFFF
    #dut.stream_enables[1].value = 0xFFFFFFFF

    # GT clock on the alchitry board is 1024Mbps * (8/10)  * (1/32) = 25.6MHz gt_clk
    # note verilator can't seem to force the signal except maybe at the reg location
    cocotb.start_soon(Clock(dut.alchitry_top.gt_serial_telem_rx_subsystem.gt_serial_telem_rx_i.gt0_rxusrclk2_out, 39.062, unit='ns').start())
    pass


def bit_value(value, bit):
    return (value >> bit) & 0x1



def bit_slice(value, lsb, bit_width):
    assert bit_width <= 7, "only supports up to 7 bits"
    mask = 2**bit_width-1
    return (value >> lsb) & mask



async def sb_write_readback_check(dut,addr,value):
    await simple_bus_write(dut,addr,value)
    rd_val = await simple_bus_read(dut,addr)
    msg="Wrote "+str(hex(value))+" and readback "+str(hex(rd_val))
    assert(value==rd_val),msg
    dut._log.info(msg)

## COCOTB supporting coroutines
async def spi_end(dut):
    dut.qspi_csn.value = 1
    dut.sclk_ena_vector[0].value = 0

async def spi_send_bit(dut,value):
    dut.qspi_mosi.value = value
    dut.qspi_csn.value = 0
    dut.sclk_ena_vector[0].value = 1

    dut.qspi_sclk.value = 1
    await Timer(100, unit='ns')

    dut.qspi_sclk.value = 0
    await Timer(100, unit='ns')


async def spi_write(dut,addr,value):

    await spi_send_bit(dut,0)  # write flag

    # send 29-bit address
    for n in reversed(range(29)):
        bit = (addr >> n) & 0x1
        await spi_send_bit(dut,bit)

    # two dummy bits
    await spi_send_bit(dut,0)
    await spi_send_bit(dut,0)

    # send data
    for n in reversed(range(32)):
        bit = (value >> n) & 0x1
        await spi_send_bit(dut,bit)

    await spi_end(dut)

async def spi_read(dut,addr):

    await spi_send_bit(dut,1)  # read flag

    # send address
    for n in reversed(range(29)):
        bit = (addr >> n) & 0x1
        await spi_send_bit(dut,bit)

    # two dummy bits
    await spi_send_bit(dut,0)
    await spi_send_bit(dut,0)

    value = 0
    # read data
    for n in reversed(range(32)):
        bit = await spi_read_bit(dut)
        value = (value << 1) | bit

    await spi_end(dut)
    return value


async def simple_bus_write(dut,addr,value):
    dut.sb_addr.value = 0  ## initialize signals
    dut.sb_we.value = 0
    dut.sb_re.value = 0
    dut.sb_data_out.value = 0

    await RisingEdge(dut.clk_64)
    dut.sb_addr.value = addr
    dut.sb_we.value = 1
    dut.sb_data_out.value = value

    await RisingEdge(dut.clk_64)
    dut.sb_we.value = 0

async def simple_bus_read(dut,addr):
    dut.sb_addr.value = 0  ## initialize signals
    dut.sb_we.value = 0
    dut.sb_re.value = 0
    dut.sb_data_out.value = 0

    await RisingEdge(dut.clk_64)
    dut.sb_addr.value = addr
    dut.sb_re.value = 1

    await RisingEdge(dut.clk_64)
    dut.sb_re.value = 0
    await FallingEdge(dut.clk_64)
    val = dut.sb_data_in.value.integer
    #await RisingEdge(dut.clk_64)
    return val



# https://zendesk.engineering/hunting-for-memory-leaks-in-python-applications-6824d0518774
# install muppy
#pip install pympler# Add to leaky code within python_script_being_profiled.py

def dump_memory(dut):
    all_objects = muppy.get_objects()
    sum1 = summary.summarize(all_objects)# Prints out a summary of the large objects
    #dut._log(sum1)
    summary.print_(sum1)# Get references to certain types of objects such as dataframe



def psutil_memory_status(dut):

    # https://www.google.com/search?q=python+print+system+memory+usage+and+what+it+is+used+for&client=ubuntu&hs=LVP&sca_esv=ea7b27f3c7f5bbf6&channel=fs&sxsrf=AE3TifMUUVdx6Bry1btWCgpuEBcwedcX_A%3A1749566092125&ei=jEJIaJK7B-CxptQPme6rkQs&ved=0ahUKEwiSsbrLieeNAxXgmIkEHRn3KrIQ4dUDCBA&uact=5&oq=python+print+system+memory+usage+and+what+it+is+used+for&gs_lp=Egxnd3Mtd2l6LXNlcnAiOHB5dGhvbiBwcmludCBzeXN0ZW0gbWVtb3J5IHVzYWdlIGFuZCB3aGF0IGl0IGlzIHVzZWQgZm9yMgUQIRigATIFECEYoAEyBRAhGKsCSPNKUM4cWKxJcAF4AZABAJgBmwGgAYUWqgEENC4yMLgBA8gBAPgBAZgCGaACiBjCAgoQABiwAxjWBBhHwgIGEAAYFhgewgIFEAAY7wXCAggQABiiBBiJBcICCBAAGIAEGKIEwgIFECEYnwXCAgsQABiABBiGAxiKBZgDAIgGAZAGCJIHBDIuMjOgB_afAbIHBDEuMjO4B_sXwgcIMC4xLjE1LjnIB7AB&sclient=gws-wiz-serp

    # Get virtual memory information
    virtual_memory = psutil.virtual_memory()

    # Print total, available, used, and percentage of memory used
    print(f"Total RAM: {virtual_memory.total / (1024**3):.2f} GB")
    print(f"Available RAM: {virtual_memory.available / (1024**3):.2f} GB")
    print(f"Used RAM: {virtual_memory.used / (1024**3):.2f} GB")
    print(f"Memory Usage Percentage: {virtual_memory.percent}%")

    # Get memory usage of the current process
    pid = os.getpid()
    python_process = psutil.Process(pid)
    memory_use = python_process.memory_info()[0] / 2**30
    print(f"Memory used by this process: {memory_use:.2f} GB")
