# for testing ADXR/ATLAS telemetry

# open sim waveforms with:
# gtkwave tests/sim_build/test_telemetry_serialize/test_main/verilog.dump
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

# can't use the format from cocotb.result import TestFailure because it trys to collect it as a test.
import cocotb.result 
#   /home/poleguy/.virtualenvs/home__poleguy__fpga-data__2024__dpsm_rx/lib/python3.11/site-packages/cocotb/result.py:175: PytestCollectionWarning: cannot collect test class 'TestFailure' because it has a __init__ constructor (from: tests/test_spi_word_write_dual.py)
#    class TestFailure(TestComplete, AssertionError):


import os

#import src_util_pkg as util
#current_dir = os.path.dirname(__file__)
#modules_path = os.path.join(current_dir, 'modules')
#sys.path.append(modules_path)
#print('\n'.join(sys.path))

import cvc 

from conftest import root_dir

import logging as log
#import plot_func
#import FFTPlot
#import math

module_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)),"../rtl")

###################################################################################
## pytest entry point
###################################################################################
# pytest entry point must contain the string test because of stupid pytest magic
def test_main(no_compile, waves):
    """ Execute test"""
    recompile=not no_compile

    ## setup the run directory in root_dir/tests/sim_build/......
    run_dir=cvc.setup_sim_dir(delete_existing=recompile)
    if waves:
        do = "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; log -r /*; run -a; quit"
    else:
        do = "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; run -a; quit"

    cvc.run_rtl_sim_cvc(
        compile_txt_files_list=[  # root_dir+"/modules/telemetry/compile.txt",
            # root_dir+"/rtl/xapp523/compile.txt",
            os.path.join(module_dir, "serial_link/compile_telemetry_serialize.txt")
            #root_dir + "/rtl/xapp523/glbl.v",
            # root_dir+"/tests/compile_unisim_lib.txt"
        ],
        #top_level="shure.tb_telemetry_serialize shure.glbl",
        rtl_run_path           = run_dir,
        #simulator              = "cvc",
        do_argument=do,
        compile_rtl=recompile
        #cocotb_enable=True,
        # rtl_run_opts           = "-ieee_nowarn -L unisims_ver -L secureip -L shure -L src",
        #          cocotb_top_is_verilog  = True,
        #          root_design_path=root_dir
    )


##############################################################
# coccotb entry point 
# automagically used via rtl_tools.run_rtl_sim when cocotb_enable = True
##############################################################

@cocotb.test()
# name can't contain the string "test" because of stupid pytest magic.
async def check_telemetry_serialize(dut):
    # 

    # Test data
    # skip 0 to distinguish 0 init value from 0 input
    # long enough to catch one 'short' period and a few after
    test_data = range(1,4240)

    expected_data = 0x1234ABCD9999AAAA001122
    # check the outputs
    results = {}


    # Clocks are created in testbench for speed
    #clk_in = Clock(dut.clk, 10, units="ns")
    
    # Start the clocks
    #cocotb.start_soon(clk_in.start())
    cocotb.start_soon(check_outputs(dut.unpack_telemetry_inst, results, expected_data))

    ######################################
    ## Telemetry - serial bypass
    ######################################
    fifo_list=[]
    cocotb.start_soon(telem_bytes_collect(dut.telemetry_serialize_inst, fifo_list))
    cocotb.start_soon(telem_bytes_inject(dut.unpack_telemetry_inst, fifo_list))

    await Timer(1, units="ps")  # wait to prevent crash at start line

    # Apply input data
    #for data in test_data:
        #dut.data_128MHz.value = data
    #    await RisingEdge(dut.clk)await RisingEdge(dut.clk)
    #dut.trig_in = 0
    #dut.spi_word0 = expected_data
    #dut.spi_word1 = 0xa6f3
    
    # initial values
    dut.telemetry_serialize_inst.packet_valid.value = 0
    dut.telemetry_serialize_inst.reset_clk.value = 1

    # start data
    await RisingEdge(dut.telemetry_serialize_inst.clk)
    dut.telemetry_serialize_inst.reset_clk.value = 1
    dut.telemetry_serialize_inst.packet.value = 1
    await RisingEdge(dut.telemetry_serialize_inst.clk)
    dut.telemetry_serialize_inst.reset_clk.value = 0
    dut.telemetry_serialize_inst.packet.value = 2
    await RisingEdge(dut.telemetry_serialize_inst.clk)
    dut.telemetry_serialize_inst.packet.value = expected_data
    dut.telemetry_serialize_inst.packet_valid.value = 1
    await RisingEdge(dut.telemetry_serialize_inst.clk)
    dut.telemetry_serialize_inst.packet.value = 4
    dut.telemetry_serialize_inst.packet_valid.value = 0

    #for data in test_data:
    # dut.data_128MHz.value.value = data
    #    await RisingEdge(dut.telemetry_serialize_inst.clk)

    await Timer(10, units="us")  # sim for a bit to inspect output


    assert "passed" in results, f"Not all checks passed."
    

##############################################################
# functions to make the sim go brrr...
##############################################################


async def telem_bytes_collect(dut, fifo_list):
    """ Collect the telemetry data from dpsm_rx every valid.
    Need the byte data and indicator for whether it is a k-char.
    fifo_list is list of [byte, data_is_k]

    Byte is valid every clock to get the proper rate.
    """
    while True:
        await FallingEdge(dut.clk)
        #if(dut.valid_enc_in.value):
        #print(f"data: {dut.data_enc_in.value}")
        data = resolve_x_to_0(dut.data_enc_in.value)
        k = dut.k_enc_in.value
        valid = dut.valid_enc_in.value
        fifo_list.append([data, k, valid])
        
      #  if(k==0):
      #      dut._log.info(f"data={hex(data)}")

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

      
async def telem_bytes_inject(dut, fifo_list):
    """ Inject bytes into telemetry receiver side to bypass serial.
    dut should be reference to gt_unpack_telemetry module.
    fifo_list is list of [byte, data_is_k]
    """

    ## spin and wait for the fifo to fill up with several bytes
    while len(fifo_list) < 3:
        await FallingEdge(dut.clk)

    #from remote_pdb import RemotePdb; rpdb = RemotePdb("127.0.0.1", 4000)

    cnt_show_first=0
    while True:
        await FallingEdge(dut.clk)
        dut.valid_in.value = 0
        await FallingEdge(dut.clk)

        if len(fifo_list) >= 1:

            item=fifo_list.pop(0) # pop oldest byte
            data = int(
                item[0]
            )  # int to fix: TypeError: unsupported operand type(s) for <<: 'coroutine' and 'int'
            k=item[1]
            valid=item[2]

            dut.data_in.value = data
            dut.k_in.value = k
            dut.valid_in.value = valid

            if cnt_show_first < 60:  # long enough to see actual iq data flowing
                dut._log.info(
                    f"//telem_bytes_inject// len(fifo_list)={len(fifo_list)} Injecting data:{hex(data)} data_is_k:{hex(resolve_x_to_0(k))}"
                )
                cnt_show_first+=1

        else:
            raise Exception(
                f"telem_bytes_inject starved. Need 1 bytes but len(fifo_list )={len(fifo_list)}"
            )


##############################################################
# checks
##############################################################

async def check_outputs(dut, results, expected_data):
    # Check the output data matches expected
 #   for i in range(2):
        # skip a few at the start because of the pipeline
#        await RisingEdge(dut.telemetry_serialize_inst.clk)
        #output_data = dut.sampled_data_64MHz.value.integer

        #print(f'dropping initial {output_data}')

    output_data = 0
    # dummy data at start to align phase
    
    await RisingEdge(dut.valid_out)
    await RisingEdge(dut.clk)
    assert dut.valid_out == 1, "valid was no longer high at the clock edge"       
    output_data = dut.data_out

    await RisingEdge(dut.clk)
    assert dut.valid_out == 0, "valid stayed high for more than one clock edge"       

    #await Timer(10, units='us') # sim for a bit to inspect output

    assert output_data == expected_data, (
        f"Data not as expected: got {output_data} expected {expected_data}"
    )

    results["passed"] = True
