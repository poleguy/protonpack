#!/usr/bin/env python
# verilog/cvc only support
# xilinx support is stripped out: modules should be simulated only, with xilinx stuff only at the top level, or stubbed out with generic sim models (e.g. DSP48, ila, mmcm)
# shurc support is stripped out because it is shure proprietary and this code is intended to support a public telemetry repository.

# from distutils.errors import CompileError
import os
import shutil

import filecmp
import logging as log


class compile_item(object):
    def __init__(self, str):
        self.item_row = str

        ## information about which compile.txt file the compile item came from
        self.compile_txt_file = ""
        self.compile_txt_rel_src = ""
        self.compile_txt_line = ""

        ## properties related to duplicate filenames or entity/module names
        self.duplicate_file_name = False
        self.duplicate_include = False
        self.duplicate_entity = False

        ## extension of the compile item i.e. .vhd
        self.file_ext = str.split(" ")[0].split(".")[-1].lower()
        ## entire absolute path to file i.e. /home/fpga/ws/FPGA/rtl/ram.vhd
        self.file_abs = str.split(" ")[0]
        ## just the file name part i.e. ram.vhd
        self.file_name = str.split(" ")[0].split("/")[-1]

        ## default compile library is shure bc work is a special keywork in vhdl for current library
        self.library = "shure"

        ## all the arguments with - or -- removed
        self.row_args = []
        self.parse_arguments()

    def parse_arguments(self):
        ## row_args will be a list of the arguments with no - or -- at the front
        ## i.e. --variable=123 -work my_lib  will be  ['variable=123',work my_lib']
        ## if there's no arguments, list will be empty
        if len(self.item_row.split(" ")) == 1:
            self.row_args = []
        else:
            self.row_args = self.item_row.split("-")[1:]
            while "" in self.row_args:
                self.row_args.remove("")
            for ii in range(0, len(self.row_args)):
                self.row_args[ii] = self.row_args[ii].strip()

    def set_compile_txt_info(self, compile_txt, line, rel_src):
        self.compile_txt_file = compile_txt
        self.compile_txt_line = line
        self.compile_txt_rel_src = rel_src

    def get_str_details(self):
        s = "{}     (from {} line {}: {})".format(
            self.file_abs,
            self.compile_txt_file,
            self.compile_txt_line,
            self.compile_txt_rel_src,
        )
        s = s + "\n      raw_args={}  duplicate_file_name={}\\n".format(
            self.row_args, self.duplicate_file_name
        )
        s = s + "      file_abs={}\n".format(self.file_abs)
        return s

    def get_str_details_summary(self):
        s = "{}     (from {} line {}: {})".format(
            self.file_abs,
            self.compile_txt_file,
            self.compile_txt_line,
            self.compile_txt_rel_src,
        )
        return s


# after this object is created you must call
# parse_compile_txt() 
# one or more times
# to build the internal self.items list
# then you must run 
# vivado_compile_cmd_gen()
# to create the output files on disk to build
# or you must run
# gen_cvc_compile_list()
# to get a list to use by cvc.py

class compile_file_generation(object):
    ## Hard-coded paths to simulators, this could be overwritten if necessary after instantiating the object

    def __init__(
        self,
        root_dir,  # relative to current directory
        run_dir,  # relative to current directory
        sim_or_build = "sim", # set to build to use IF BUILD conditionals
        # quiet=False
    ):
        #############################################
        ##### clean and configure the system paths
        self.root_dir = os.path.abspath(
            root_dir.strip()
        )  ## root directory i.e. /home/fpga/SM_FPGA
        self.run_dir = os.path.abspath(
            run_dir.strip()
        )  ## execution directory i.e. /home/fpga/SM_FPGA/par  or /home/fpga/SM_FPGA/scratch/test/rtl_sim

        # self.quiet=quiet

        ## if the paths don't end with a /, add it
        if self.root_dir[-1] == "/":
            self.root_dir = self.root_dir[0:-1]
        if self.run_dir[-1] == "/":
            self.run_dir = self.run_dir[0:-1]

        log.debug(f"compile_file_generation: root_dir={self.root_dir}")
        log.debug(f"compile_file_generation: run_dir={self.run_dir}")
        #############################################

        self.sim_or_build = (
            #"sim"  # build support removed, except for `IF BUILD conditional syntax
            sim_or_build.lower()
        )

        if sim_or_build not in ["sim","build"]:
            raise Exception("error sim_or_build passed in should be string 'sim' or 'build'")

        #######################
        #### this is the main object list for compile items parsed from compile.txt flow
        self.items = []
        #######################

        ## use as running tab to make sure compile.txt recursion doesn't go into infinite loop on same compile.txt file references
        self.compile_file_visited_list = []

        self.compile_parse_log_file = self.run_dir + "/" + "compile_parse_log.txt"
        log.info("self.compile_parse_log_file" + str(self.compile_parse_log_file))

        ## parse log file is appended if parse_compile_txt is called more than once so remove it if it exists at initialization
        if os.path.isfile(self.compile_parse_log_file):
            os.system("rm " + self.compile_parse_log_file)

        self.pass_through_file_list = [
            #"shurc", # no shurc support in open source projects
            "rom",
            "mem",
            "mif",
            "coe",
            "txt",
            "pkl",
            "p",
            "xci",
            "xdc",
            "hex",
            "dat",
            "vh",
            "checksum",
        ]

    def gen_cvc_compile_list(self):
        self.compile_list_check_and_gen()
        # todo: vh was not included in this list before making it a class member variable. Which way is right?
        # pass_through_file_list = ["shurc","rom","mem", "mif","coe","txt","pkl","p","xci","xdc","hex", "dat"]
        # pass_through_file_list = ["shurc","rom","mem","mif","coe","txt","pkl","p","xci","xdc","hex", "dat", "vh"]
        compile_list = []
        for item in self.items:
            if item.file_ext not in self.pass_through_file_list:
                compile_list = compile_list + [item.file_abs]
        return compile_list

        
    #######################################################################################3#
    ## 
    ## targeting xilinx vivado synthesis (xsyn)
    #######################################################################################3#
    def vivado_compile_cmd_gen(self):
        # write the commands to disk, given the compile list in self.items

    #######################################################################################3#
    ## compile_cmd_gen
    ## this function turns the raw compile item list into actual commands depending if
    ## targeting modelsim, xilinx sim, or xilinx synthesis (xsyn)
    #######################################################################################3#
    #def compile_cmd_gen(self):        

        cmd_v = "read_verilog"

        cmd_arg_library = "library"


        # This is the list of files that no compile command needs to be generated for e.g. for .vhd or .v files.
        #pass_through_file_list = ["shurc","rom","mem","mif","coe","txt","pkl","p","xci","xdc","hex", "dat", "vh"]        

        cmd_list = []
        # Compile RTL
        library_list = []

        self.mytest="mytest"

        ## write the commands to a cmd list for sim debug but also this file is sourced for build
        with open(self.run_dir+"/compile_cmd_list.txt","w") as ff:
            def cmd_write(cmd):
                log.info(cmd)
                cmd_list.append(cmd)
                ff.write(cmd+'\n')

            for item in self.items:
                        
                ## Handle vhdl files
                if(item.file_ext == "vhd"):
                    str_2008=""
                    if ("2008" in item.row_args):
                        if("force" not in item.row_args): # Requires comprehension that the 2008 file won't cause issues with --force argument
                            assert(False),"vhdl-2008 file detected in build. not supporting this due to know synthesis issues."+item.get_str_details()
                        str_2008="-vhdl2008 "
                    str_library = "-"+cmd_arg_library + " "+item.library+" "

                    str_93=""

                    cmd_write("read_vhdl "+str_2008+str_library+str_93+item.file_abs)

                ## Handle verilog files
                elif (item.file_ext == "v" or item.file_ext == "sv"):
                    str_library = "-"+cmd_arg_library+" "+item.library+" "
                    str_sv = ""
                    if(item.file_ext=="sv" or "sv" in item.row_args):
                        str_sv = "-sv "
                    cmd_write(cmd_v+" "+str_sv+str_library+item.file_abs)

                ## handle other files only valid for building
                elif(item.file_ext== "xci" and "dont_touch_xci"in item.row_args):
                    # the if here checks property generate_synth_checkpoint true indicating the IP is global (as opposed to out of context)
                    #   if it's out of contet, Exit with error and provide msg
                    # Then generate all the source files associated with the IP
                    cmd="read_ip "+item.file_abs+"\n\
    if {[get_property generate_synth_checkpoint [get_files  "+item.file_abs+"]]} {puts \"\
\\nERROR! Change IP "+item.file_abs+" from Out of Context to Global!! This can be done in the Vivado GUI project with the xci added.  Right click on the xci and choose Generate Output Products >  Global. Out of context setting in IPs cause issues when using our framework.\\n\";exit -1}\n\
generate_target all [get_files "+item.file_abs+"]"
                            
                    cmd_write(cmd)
                elif(item.file_ext=="bd" and "dont_touch_bd" in item.row_args):
                    cmd="\
## Necessary for module references on block design]\n\
set_property source_mgmt_mode All [current_project]\n\
read_bd "+item.file_abs+"\n\
generate_target all [get_files "+item.file_abs+"]\n"
                    cmd_write(cmd)
                elif(item.file_ext=="dcp"):
                    cmd="read_checkpoint "+item.file_abs
                    cmd_write(cmd)
                elif(item.file_ext=="xdc"):
                    cmd="read_xdc "+item.file_abs
                    cmd_write(cmd)
                elif(item.file_ext=="ngc"):
                    cmd="read_edif "+item.file_abs
                    cmd_write(cmd)
                elif(item.file_ext=="vp"): # Encrypted Verilog (.vp)
                    cmd="add_files -norecurse "+item.file_abs
                    cmd_write(cmd)
                elif(item.file_ext in self.pass_through_file_list or "shurc_assem" in item.file_name):
                    msg="## No command needed passing this file through the command generation step "+item.file_abs
                    log.info(msg)

                #elif("shurc_assembler" in item.file_abs):
                #    msg="## No command needed for shurc_assembler "+item.file_abs
                #    log.info(msg)

                else:
                    raise ValueError(f"Could not determine what to do with item: {item.get_str_details()}")
                    
        return cmd_list



    def compile_list_check_and_gen(self):
        ## generate any necessary xilinx IPs early
        ## this should happen before any checks since the IP may produce files that do not exist yet
        # self.xilinx_ip()
        ## check that all necessary files exist
        self.file_exist_check()
        ## check for duplicate file names, vhdl entites/pkg and verilog modules
        self.duplicate_check()
        ## shurc compile flow
        # self.shurc_compile()
        ## copy and initialization files to run_dir/memory_init/
        self.copy_init_files()
        log.debug("end of compile_list_check_and_gen()")

    #######################################################################################3#
    ## Simple check through items list to make sure each file exist
    ## should run after any file generate steps are run
    #######################################################################################3#
    def file_exist_check(self):
        for item in self.items:
            if not os.path.isfile(item.file_abs):
                # if the file does not exist, raise error with details
                raise FileNotFoundError(f"{item.get_str_details()}")

    #######################################################################################3#
    ## This function will go through the existing items list and check for duplicate isses
    ## both in terms of filenames and entity, package, and module name duplicates
    #######################################################################################3#
    def duplicate_check(self):
        file_names_list = []
        module_names_list = []

        def error_duplicate_str(description, item_a, item_b):
            return (
                "\
            \n\ncompile_file_generation error: 2 files have the same "
                + description
                + "\n"
                + "1st occurence:\n  "
                + item_a.get_str_details()
                + "\n"
                + "2nd occurence:\n  "
                + item_b.get_str_details()
                + "\n"
            )

        ## sub function within this module that opens a provided rtl file and finds the entity name,
        ## module name, or package name and checks it against a running list, if not a duplicate
        ## adds it to the list for further checking
        def check_rtl_for_duplicates(item):
            ## only run this for rtl files
            if item.file_ext in ["vhd", "v", "sv"] and not item.file_abs.endswith(
                "_vh_rfs.vhd"
            ):
                ## errors='replace' handles the (c) copywrite character gracefully
                with open(item.file_abs, "r", errors="replace") as gg:
                    name = "(no entity or package name found in file)"
                    for row2 in gg:
                        row_clean = row2.strip().lower()
                        if item.file_ext == "v" or item.file_ext == "sv":
                            if row_clean.startswith("module"):
                                name = row_clean.split(" ")[1].strip()
                                break
                ## before appending the current name, check it against the running list so far
                for entry in module_names_list:
                    ## if the entity names match
                    if entry[0] == name:
                        raise Exception(
                            error_duplicate_str(
                                "module name: "
                                + name
                                + " found while checking for no duplicate naming across any rtl files.",
                                item,
                                entry[1],
                            )
                        )
                ## didnt find the name in the list, so append it and continue checking next call
                module_names_list.append([name, item])

            else:  ## not an rtl file, so do nothing and return
                return

        ## iterate throught the compile list to look for duplicates
        for aa in range(0, len(self.items)):  ## iterate through each compile item
            for entry in (
                file_names_list
            ):  ## check the current compile item against a building list as we go
                if self.items[aa].file_name == entry[0]:
                    ## if duplicate files are exact matches for file content ang arguments,
                    ## we want to compile the first one that comes along in the list so that cvc
                    ## wont try to recompile a 2nd time
                    self.items[entry[1]].duplicate_file_name = True
                    self.items[aa].duplicate_file_name = True

                    ## filecmp should do an exact binary match of the file to check if its an exact copy
                    filecmp.clear_cache()
                    identical = filecmp.cmp(
                        self.items[entry[1]].file_abs,
                        self.items[aa].file_abs,
                        shallow=False,
                    )

                    ## if filenames match and files are identical, this is OK
                    if not identical:
                        raise Exception(
                            error_duplicate_str(
                                "names, same but the files are different!",
                                self.items[entry[1]],
                                self.items[aa],
                            )
                        )

                    self.items[entry[1]].duplicate_compile_this = True
                    self.items[aa].duplicate_compile_this = False

            ## if duplicate file name and exact file, dont want to do rtl duplicate check since we already know its a duplicate match
            ## duplicate filename that isnt an exact match will have already errored out just above here
            if not self.items[aa].duplicate_file_name:
                check_rtl_for_duplicates(self.items[aa])

            ## didn't err out so append current file and index to building list
            file_names_list.append(
                [self.items[aa].file_name, aa]
            )  ##append name and the index for referencing later

    #######################################################################################3#
    ## Move any ram/rom initialization files to run directory
    ## same relative directory for sim and build s.t. any paths defined in RTL
    ## work for either case.
    #######################################################################################3#
    def copy_init_files(self):
        rom_init_folder = self.run_dir + "/memory_init"
        ## some xilinx IP do not allow specification of mif file location, so must be in rtl_run dir
        mif_init_folder = self.run_dir
        if not (os.path.exists(rom_init_folder)):
            os.mkdir(rom_init_folder)
        if not (os.path.exists(mif_init_folder)):
            os.mkdir(mif_init_folder)
        for item in self.items:
            if item.file_ext in [
                "rom",
                "mem",
                "mif",
                "hex",
                "vh",
                "txt",
                "checksum",
            ]:  # move verilog header files to memorty_init for each reference
                shutil.copy2(item.file_abs, rom_init_folder + "/")

    #######################################################################################3#
    ## Add items to overall item list found in passed-in compile.txt file
    ## If another compile*.txt file is encountered, this function calls itself recursively.
    ## This function can be called multiple times externally to add to the list
    ##  i.e. once for design, another time for testbench, etc
    ## resultant list is stored in self.items
    #######################################################################################3#
    def parse_compile_txt(
        self, compile_file
    ):  #  full path and filename of compile.txt file to parse recursively
        # to prevent infinite loops of compile.txt including itself via recursion, and to allow files being included numerous times in various places,
        # we keep a list of each file parsed and only process it once
        if os.path.abspath(compile_file) not in self.compile_file_visited_list:
            self.compile_file_visited_list.append(os.path.abspath(compile_file))
            compile_file_directory = os.path.abspath(os.path.dirname(compile_file))
            local_sim_or_build = "both"
            if not os.path.isfile(compile_file.split(" ")[0]):
                raise Exception(
                    "A specified compile text file does not exist: "
                    + compile_file.split(" ")[0]
                    + "\n"
                    + "The following compile.txt files have been compiled thus far (last one is error):"
                    + str(self.compile_file_visited_list)
                )
            compile_file_ext = compile_file.split(" ")[0].split(".")[-1]
            if compile_file_ext == "txt":
                with (
                    open(compile_file, "r") as ff,
                    open(self.compile_parse_log_file, "a") as log_file,
                ):
                    log_file.write(
                        f"Start of parse_compile_file for compile file {compile_file}\n"
                    )
                    line_num = 0
                    for row in ff:
                        line_num += 1  # for aid in debug
                        row = row.lstrip()
                        row = row.rstrip()

                        # process each line
                        if len(row) == 0:
                            # skip blank rows
                            pass
                        elif row[0].startswith("#"):
                            # skip commented out rows
                            pass
                        elif row[0].startswith("`"):
                            #### Look for lines that start with the tick `
                            #### these provide designer special directions for a set of files

                            if "IF SIM" in row.upper():
                                ## if sim only, set a flag
                                local_sim_or_build = "sim"
                            elif "IF BUILD" in row.upper():
                                ## if build only, set a flag
                                local_sim_or_build = "build"
                            elif (
                                "END" in row.upper()
                            ):  ## end ends all previously set `flags
                                if local_sim_or_build == "both":
                                    raise Exception(
                                        f"Compile file error: unexpected `end detected in {compile_file}"
                                    )
                                local_sim_or_build = "both"
                            else:
                                err_str = (
                                    "Compile file error: unexpected syntax starting with `"
                                    + " file="
                                    + compile_file
                                    + " line#"
                                    + line_num
                                )
                                log.error(err_str)
                                raise Exception(err_str)

                        else:
                            # process normal rows by splitting by spaces (bad form... because spaces are technically legal...)
                            # but the compile.txt format does not allow spaces except to separate comments after the line, etc.
                            current_file_name = row.split(" ")[0].split("/")[-1]
                            current_file_rel_path = row.split(" ")[0]

                            # first check if this file should be included based on any special build or sim flags set via tick mark check above
                            if (local_sim_or_build == "both") or (
                                local_sim_or_build == self.sim_or_build
                            ):
                                # this is a compile.txt file
                                if (current_file_name.startswith("compile")) and (
                                    current_file_name.endswith(".txt")
                                ):  # allow for compile_something.txt
                                    ## Take the first section before spaces ignoring any arguments, then take the filename part after the last /
                                    # if it is a relative path, interpret it relative to the current compile.txt path
                                    # if it is already absolute this will have no effect
                                    new_compile_file_abs_path = os.path.join(
                                        compile_file_directory, current_file_rel_path
                                    )
                                    #         # recursive call
                                    self.parse_compile_txt(new_compile_file_abs_path)
                                    str_log = (
                                        "parse_compile_file call complete for compile file "
                                        + new_compile_file_abs_path
                                    )
                                # this is not a compile.txt file, so append it to the list of source files
                                else:
                                    # if it is a relative path, interpret it relative to the current compile.txt path
                                    # if it is already absolute this will have no effect
                                    compile_item_full_path = os.path.join(
                                        compile_file_directory, row
                                    )

                                    # create a new compile item to add to the list
                                    item = compile_item(str=compile_item_full_path)
                                    # also log the source file and line for aid in debug
                                    item.set_compile_txt_info(
                                        compile_file, line_num, row
                                    )
                                    self.items.append(item)
                                    str_log = item.get_str_details_summary()
                            else:
                                try:
                                    str_log = (
                                        "IGNROING FILE due to `if "
                                        + local_sim_or_build
                                        + " keyword: "
                                        + item.get_str_details_summary()
                                    )
                                except ValueError as e:
                                    str_log = (
                                        "IGNROING FILE due to `if "
                                        + local_sim_or_build
                                        + " keyword: "
                                        + current_file_rel_path
                                    )

                            # if(not self.quiet):
                            log.info(str_log)
                            log_file.write(str_log + "\n")

            ## compile file did not have .txt extension so assume it is a source file
            else:
                # create a new compile item to add to the list
                if compile_file[0] == "/":  # indicates absolute path so use this
                    this_file = compile_file
                else:
                    # do the usual relative add for where the file is specified
                    # if it is a relative path, interpret it relative to the current compile.txt path
                    # if it is already absolute this will have no effect
                    this_file = os.path.join(compile_file_directory, compile_file)
                item = compile_item(str=this_file)
                # also log the source file and line for aid in debug
                item.set_compile_txt_info(
                    compile_file, -1, "compile file is a source file"
                )
                self.items.append(item)
                str_log = item.get_str_details_summary()
                # if(not self.quiet):
                log.info(str_log)
                with open(self.compile_parse_log_file, "a") as log_file:
                    log_file.write(str_log + "\n")


if __name__ == "__main__":
    ########
    ## when this file is called directly, assumptions are made based on
    ## assuming the current working directory is [run_dir] which is [root_dir]/par/
    ## have / at end of dir paths to match sim calls
    run_dir = os.getcwd()

    # remove the last element of the path (the par directory)
    #
    # https://stackoverflow.com/questions/3315045/remove-last-path-component-in-a-string

    # first find the path excluding the workspace directory and the workspace directory
    head, tail = os.path.split(run_dir)
    # root_dir = "/".join(run_dir.split("/")[0:-1])  ## do equivalent of a ../ with [0:-1]
    root_dir = head
    compile_top = root_dir + "/compile.txt"

    compile_file_generation_i = compile_file_generation(
        root_dir=root_dir, run_dir=run_dir
    )
    compile_file_generation_i.parse_compile_txt(compile_top)
#    compile_file_generation_i.gen_build_compile()
