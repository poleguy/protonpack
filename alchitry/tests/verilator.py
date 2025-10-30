# this is a module to support the cvc simulator
# it provides a library of functions 
import logging
# give this module its own logger, tied to its namespace.
# This will inherit the output location of the module that calls this
log = logging.getLogger(__name__) 

# see readme.txt for more documentation
import cocotb
#from coctob_test.simulator import run
#from cocotb_tools.runner import get_runner
from pathlib import Path
import shutil 

import os
import inspect
import shlex
import subprocess

## Treating PythonSim as a package so do relative imports as such:
from scripts.fpgabuild.compile_file_generation import compile_file_generation


from shutil import which
import shutil
#import logging as log
import time
import scripts.bash as bash

def _get_test_module(num_callers_back=2):
    ## get some details about the module that called this
    ## num_callers_back=2 uses the name of the function that calls this setup_sim_dir
    ##   setting this to 3 would use the name of caller 2 times back
    frame = inspect.stack()[num_callers_back]
    caller_function = frame.function
    module = inspect.getmodule(frame[0])
    caller_filename = module.__file__
    caller_dir = os.path.dirname(caller_filename)
    caller_module = module.__name__
    log.debug(
        f"get_module_name:  (num_callers_back={num_callers_back}) caller filename={caller_filename} caller_dir={caller_dir} caller_module={caller_module} caller function={caller_function}"
    )
    return caller_module


def _get_test_dir(num_callers_back=2):
    ## get some details about the module that called this
    ## num_callers_back=2 uses the name of the function that calls this setup_sim_dir
    ##   setting this to 3 would use the name of caller 2 times back
    frame = inspect.stack()[num_callers_back]
    caller_function = frame.function
    module = inspect.getmodule(frame[0])
    caller_filename = module.__file__
    caller_dir = os.path.dirname(caller_filename)
    caller_module = module.__name__
    log.debug(
        f"get_caller_dir:  (num_callers_back={num_callers_back}) caller filename={caller_filename} caller_dir={caller_dir} caller_module={caller_module} caller function={caller_function}"
    )

    return caller_dir


def _get_test_function(num_callers_back=2):
    ## get some details about the module that called this
    ## num_callers_back=2 uses the name of the function that calls this setup_sim_dir
    ##   setting this to 3 would use the name of caller 2 times back
    frame = inspect.stack()[num_callers_back]
    return frame.function


# call this before run_rtl_sim_cvc() to set up stuff on disk
def setup_sim_dir(run_dir_common="sim_build", delete_existing=True, num_callers_back=2):
    """creates the simulation build/execution directory if it doesn't exist based on the calling modules (test) name
    returns the dir used by the test in other places
    """

    # caller_module=get_module_name(num_callers_back)

    ## setup directories
    run_dir_common = _get_test_dir(num_callers_back) + "/" + run_dir_common
    ## the run_dir will be the test_* file + the test function name
    run_dir_group = run_dir_common + "/" + _get_test_module(num_callers_back)
    run_dir = run_dir_group + "/" + _get_test_function(num_callers_back)

    """
    eg for path   sim_build/test_datapath/test_datapath_rbw_cnt
    
    run_dir_common = sim_build
    run_dir_group  = sim_build/test_datapath
    run_dir        = sim_build/test_datapath/test_datapath_rbw_cnt
    """

    ## if common dir doesn't exist, create it
    if not os.path.exists(run_dir_common):
        os.mkdir(run_dir_common)

    # delete the run dir if it exists
    if os.path.exists(run_dir) and delete_existing:
        shutil.rmtree(run_dir)

    ## create the new dirs if necessary, group dir first then sub dir
    if not os.path.exists(run_dir_group):
        os.mkdir(run_dir_group)
    if not os.path.exists(run_dir):
        os.mkdir(run_dir)

    ## necessary for cocotb
    os.environ["SIM_RUN_DIR"] = run_dir

    return run_dir


# top level is determined by the first highest level module in the compile.txt list
# careful: order is not important in the compile.txt list for CVC (but is important for vivado)
# cocotb is always enabled
def run_rtl_sim_verilator(
    compile_txt_files_list:list[str],  ## REQUIRED provide at least one or more compile.txt files as a python list
    rtl_run_path:str,  ## REQUIRED rtl run path, where libraries should be compiled to and simulation executed from
    cocotb_toplevel:str, ## required top level module name for cocotb
    compile_rtl=True,  ## optional to disable compiling step
    compile_recent_rtl=False,  ## will not compile old files (use with compile_rtl=False)    
    do_argument="run -a; quit",  ## optional when in batch mode (not gui), run this do_argument could be commands or a do file.. if gui this is not used and must be set to ''
):
    """Function for compiling and executing an rtl simulation.
    It has only the list of inputs needed for cvc which keeps it maintainable and understandable
    Support for CVC simulator only.
    Verilog only.
    Modelsim, xilinx, riviera-pro support is in the original run_rtl_sim that tries to do everything.
    Most of the arguments are optional.  Required input arguments are marked REQUIRED in the comment.

    This function calls compile_file_generation to perform the necessary compile.txt flow.
    Errors are raised for compile errors and sim execution errors.

    This function stands-alone and doesn't necessarily need other function calls prior to this one.
    However often setup_sim_dir would be called prior with the run execution path passed into this function via rtl_run_path input.
    """
    # logging is handled by magic in pytest, so this isn't what we want:
    # https://stackoverflow.com/questions/4673373/logging-within-pytest-tests
    # if called as top level, configure root logger
    # logging.basicConfig(
    #     level=logging.DEBUG,
    #     format="%(asctime)s [%(levelname)s] %(message)s",
    #     filename="log.txt",   # send to a file instead of stderr
    # )

    # remove: we only want to set things via the api, not env variables
    ## if no rtl_run_path is input, try env variable, else set current directory
    #if rtl_run_path == None:
    #    if os.environ.get("SIM_RUN_DIR") is not None:
    #        rtl_run_path = os.environ.get("SIM_RUN_DIR")
    #    else:
    #        rtl_run_path = "./"

    #######################################################
    ## Validate and check inputs
    #######################################################

    root_design_path = "./"  ## optional root design path, this helps with compile.txt print and logging messages
    ## validate the inputs
    assert os.path.exists(root_design_path), " root_design_path=" + root_design_path
    assert os.path.exists(rtl_run_path), "rtl_run_path=" + rtl_run_path

    #    print(psutil.Process(os.getpid()).cwd())
    # print(root_design_path)
    # print(os.getcwd())
    # make it absolute at this point, because we're about to do some os.chdir commands
    root_design_path = os.path.abspath(root_design_path)
    # print(root_design_path)

    ## Check cocotb inputs and setup some details

    cocotb_lib_dir = ""

    # import cocotb
    cocotb_lib_dir = os.path.join(os.path.dirname(cocotb.__file__), "libs")

    if os.environ.get("SIM_RUN_DIR") is None:
        ## necessary for cocotb
        os.environ["SIM_RUN_DIR"] = rtl_run_path

    ## execute out of the rtl_run_path location
    ## could consider a subprocess call where we provide this path for the executable instead of doing a chdir
    starting_cwd = os.getcwd()
    os.chdir(rtl_run_path)

    log.info("all commands are logged to go_sim.tcl file for debugging in gui mode")
    f_go_sim_tcl = open(rtl_run_path + "/go_sim.tcl", "w")
    f_go_sim_tcl.write("##  go_sim.tcl auto-generated for test case \n")
    f_go_sim_tcl.write(
        "##    This tcl file can be sourced from Modelsim or Vivado GUIs\n"
    )
    f_go_sim_tcl.write(
        "##    in order to recompile and rerun the go_sim.py test case\n"
    )
    f_go_sim_tcl.write(
        "##    without leaving the GUI window and re-running go_sim.py.\n"
    )
    f_go_sim_tcl.write(
        "##      Example command in the GUI to recompile and rerun the sim:.\n"
    )
    f_go_sim_tcl.write(
        "##        quit -sim;  do go_sim.tcl;  log -r /*;  run 1 us \n\n\n"
    )

    if compile_rtl or compile_recent_rtl:
        ## create a tcl file which can recompile and rerun the simulation (useful for debugging in a gui mode)

        #######################################################
        ## run compile_file_generation class to read and interpret compile.txt files and generate compile commands
        #######################################################

        compile_file_generation_i = compile_file_generation(
            root_design_path, rtl_run_path
        )
        ## run parse_compile_txt 3 times adding to overall compile list each time

        if type(compile_txt_files_list) is not list:
            raise Exception(
                "run_rtl_sim compile_txt_files_list input must be a python list!"
            )

        for compile_file in compile_txt_files_list:
            ## allow for arguments if the compile.txt file IS a source file so do the split on space
            assert os.path.isfile(compile_file.split(" ")[0]), (
                "check specified compile files, this one does not exist " + compile_file
            )
            compile_file_generation_i.parse_compile_txt(compile_file)

    compile_list = compile_file_generation_i.gen_cvc_compile_list()

    #######################################################
    ## now execute compile and sim commands generated for CVC
    #######################################################

    # in verilator all source is compiled at once
    
    # todo: use https://github.com/uwsampl/verilator-unisims

    # todo: there is no check for duplicate glbl.v files and the error message is not caught.
    # you'lle have to add glbl.v manually in compile.txt
    # xil_glbl = "%s/data/verilog/src/glbl.v" % (xil_basepath)
    xil_glbl = ""
    ### !!! xil_glbl ORDER IS IMPORTANT !!! ###

    os.environ["VERILOG_SOURCES"] = ' '.join(compile_list)
    #os.environ["VERILOG_SOURCES"] = "/home/poleguy/fpga-data/2025/protonpack/alchitry/tests/my_design.sv"
    

    # copy template code into place for Makefile
    makefile_template = os.path.abspath(os.path.join(__file__, '..', 'Makefile.template'))
    shutil.copy(makefile_template, os.path.join(rtl_run_path, "Makefile"))
    
    
    # /home/poleguy/.virtualenvs/home__poleguy__fpga-data__2025__protonpack__alchitry/lib/python3.11/site-packages/cocotb/libs
    # `cocotb-config --lib-dir `
    command = ( f"make -C {rtl_run_path}"

        # +interp +verbose -informs
        #f"verilator -cc --build -exe --trace -DCOCOTB_SIM=1 -DVM_TRACE_FST --trace-fst --timing --vpi -j 0 -Wall -Wno-PINCONNECTEMPTY -Wno-PROCASSINIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC " \
        #f' -LDFLAGS "-Wl,-rpath, /home/poleguy/.virtualenvs/home__poleguy__fpga-data__2025__protonpack__alchitry/lib/python3.11/site-packages/cocotb/libs -L /home/poleguy/.virtualenvs/home__poleguy__fpga-data__2025__protonpack__alchitry/lib/python3.11/site-packages/cocotb/libs -lcocotbvpi_verilator " '\
        #f"{xil_unisims} /home/poleguy/fpga-data/2025/protonpack/alchitry/rtl/alchitry_top.v {} {xil_glbl}"
    )

    # the rest is for cocotb:
    # cocotb_s = cocotb_support.cocotb_setup(conda_env_path=None)
    # cocotb_log_parser = cocotb_support.cocotb_log_parser()  # what's this?

    # todo: this needs a comment! It can't be moved into the compile_and_run_cvc function because it is magic
    frame = inspect.stack()[1]

    compile_and_run_verilator(compile_list, cocotb_lib_dir, command, frame, cocotb_toplevel)
    # must restore directory here, because it might (will?) get deleted by pytest , and break everything!
    os.chdir(starting_cwd)


def compile_and_run_verilator(compile_list, cocotb_lib_dir, command, frame, cocotb_toplevel):
    module = inspect.getmodule(frame[0])
    caller_filename = module.__file__
    caller_module = module.__name__
    caller_module_no_ext = caller_module.split(".py")[0]
    module = caller_module_no_ext
    caller_dir = os.path.dirname(caller_filename)
    log.info(
        "cocotb caller filename="
        + caller_filename
        + " \n"
        + " caller_dir="
        + caller_dir
        + " \n"
        + " caller_module="
        + caller_module
    )
    os.environ["MODULE"] = caller_module  # point to this file as the cocotb module
    os.environ["COCOTB_TOPLEVEL"] = cocotb_toplevel # todo: fix this to be programmatic
    os.environ["PYTHONPATH"] = (
        caller_dir  # this is required so that the cocotb library can find this module
    )

    # os.environ['LIBPYTHON_LOC'] = '/home/fpga/workspace/telemetry/cenv/lib/libpython3.8.so.1.0'
    os.environ["NO_COLOR"] = "1"
    os.environ["COCOTB_REDUCED_LOG_FMT"] = "1"
    os.environ["CCACHE_PREFIX"] = str.strip(bash.bash("which g++-13"));

    # command = f"{command} {vpi} > tmp.txt"

    command = f"{command}"

    # compile AND run rtl simulation
    print(command)
    try:
        output = bash_cocotb_parse(command)
    except ValueError as e:
        if "Bash command failed with return code 1" in str(e):
            log.warning(
                "Ignoring bash failure in hopes it's just a false CVC alarm. The proof is in the FAIL results in the string. This may be a cvc64 bug."
            )
            output = str(e).partition(":")[2]
            # print(f"outpuuut: {output}")
        else:
            raise

    # https://stackoverflow.com/questions/4760215/running-shell-command-and-capturing-the-output
    passed = False
    for stdout_line in output.splitlines():
        if all(x in stdout_line for x in ["TESTS", "PASS", "FAIL", "SKIP"]):
            # grabbing the errors from this line:
            #   ** TESTS=1 PASS=1 FAIL=0 SKIP=0
            errors = int(stdout_line.split(" SKIP")[0].split("FAIL=")[-1])
            if errors == 0:
                passed = True

    if not passed:
        # with open('tmp.txt', 'r') as f:
        #    results = f.read()
        results = output
        raise ValueError(
            f"No TESTS, PASS, FAIL, SKIP line in results... assuming it didn't run right:\n{results}"
        )


# helper functions


# checks if results.txt file says PASS
# returns true if it passed
def results_txt_pass(result_file="results.txt"):
    ## use the first line of the scratch/[test]/rtl_sim/results.txt
    ## as a PASS/FAIL indication
    ##   For example the first line of the results.txt file might have:
    ##      FAIL - There were 23 errors.

    if os.path.isfile(result_file):
        with open(result_file, "r") as f:
            flines = f.readlines()
            if flines:  # make sure the file is not empty
                if len(flines[0]) >= 4:
                    ## if first 4 characters of result.txt is pass, declare it as such
                    ## anything else keep as default False indicating fail
                    if flines[0][0:4].lower() == "pass":
                        return True

    # file not found, file is empty, or first four characters are not "pass"
    return False


# https://chatgpt.shure.com/


def get_filename(line):
    # Split the line into words
    words = line.split()

    # Go through each word
    for word in words:
        # Check if it is a file path
        if os.path.isfile(word):
            # If it is a file path, return the file name
            return word


# https://chatgpt.shure.com/


def is_file_newer_than_one_hour(filename):
    # Get the current time
    now = time.time()

    # Get the file's last modification time
    mtime = os.path.getmtime(filename)

    # If the file is newer than one hour, return True
    if now - mtime < 3600:
        return True
    else:
        return False


# https://stackoverflow.com/questions/4256107/running-bash-commands-in-python/51950538
def bash_cocotb_parse(cmd, log_level="debug"):
    # log_level sets the level of messages that bash prints for normal lines
    # it will promote these lines to other levels if they have certain strings in them
    # https://stackoverflow.com/questions/3503719/emulating-bash-source-in-python
    log.debug(f"Runinng bash command: {cmd}")
    if "'" in cmd:
        print("warning: apostrophe's might cause trouble")
    bashCommand = f"env bash -c '{cmd}'"
    bashCommand = shlex.split(bashCommand)
    # bashCommand = "cwm --rdf test.rdf --ntriples > test.nt"
    log.debug(bashCommand)
    print(bashCommand)
    # pipe stderr to stdout so we don't miss error messages
    process = subprocess.Popen(
        bashCommand,
        stderr=subprocess.STDOUT,
        stdout=subprocess.PIPE,
        universal_newlines=True,
    )

    # https://stackoverflow.com/questions/4417546/constantly-print-subprocess-output-while-process-is-running
    output = ""
    for stdout_line in iter(process.stdout.readline, ""):
        print(stdout_line, end="")

        log_msg = "    " + stdout_line.strip()
        if " DEBUG" in log_msg:
            log.debug(log_msg)
        elif " INFO" in log_msg:
            log.info(log_msg)
        elif " WARNING" in log_msg:
            log.warning(log_msg)
        elif " ERROR" in log_msg:
            log.error(log_msg)
        elif log_level.lower() == "info":
            log.info(log_msg)
        else:  # default use debug
            log.debug(log_msg)

        output = output + stdout_line
    process.stdout.close()
    return_code = process.wait()
    if return_code:
        # raise subprocess.CalledProcessError(return_code, cmd)
        #    print(output)
        raise ValueError(
            f"Bash command failed with return code {return_code}. {cmd}: {output}"
        )
    return output
