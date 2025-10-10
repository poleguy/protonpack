############################################################################
# this is the main entry point
# this will build the project and produce reports and outputs

## Required parameters for build_nonproject_vivado.tcl
set PRJ_TOP_NAME "alchitry_top"
# using slowest speed grade to make sure we have margin. We can then use
# any faster speed grade with low risk of failing timing.
set PRJ_PART "xc7a100tfgg484-2"
# we determine this name, not software. They can rename it.
set IMAGE_OUTPUT_NAME "alchitry_top" 

#set PYTHONSIM_PATH "../src/pythonsim/PythonSim"

## Optional parameters
## Run the timing focused PAR for this design (required to meet timing)
## This significantly reduced the LUT utilization:
set TIMING_OPTIMIZED_PAR 1

## keep generated IP outputs for faster rebuild
#set KEEP_IP_OUTPUT 1

# opt_design:
#
#  -remap - (Optional) Remap the design to combine multiple LUTs into a single
#  LUT to reduce the depth of the logic.
#
#  -aggressive_remap - (Optional) Similar to the -remap option to reduce LUT
#  logic depth but more exhaustive. This may reduce more LUT levels at the
#  expense of longer optimization runtime.
#
#      ERROR: [Vivado_Tcl 4-167] Cannot specify '-aggressive_remap' when '-directive' is specified
#      Resolution: Please use only -directive switch.
#set OPT_EXTRA_ARGS "-aggressive_remap"

# todo: if you comment this out it can't actually build an mcs: bug in build_nonproject_vivado.tcl?
set DISABLE_MCS_FILE 1

# undefine or set to 0 to disable encryption
set ENCRYPT_BITSTREAM 0

## strict design check fail on vivado log critical warning OR CDC report critical 
set FAIL_ON_CRITICAL_WARN 0 
set FAIL_ON_CRITICAL_CDC 0 
set CDC_WAIVER_XDC_FILE constraints/cdc_waivers.xdc

# don't set here, accept the default or wrap this script with a telemetry speficfic scripts build_telemetry.tcl
# to set this parameter
#set SYNTH_EXTRA_ARGS [list -generic INCLUDE_TELEM_NOT_UI=true]
#set SYNTH_EXTRA_ARGS [list -generic INCLUDE_UI_SUBSYSTEM=true -generic INCLUDE_HDQ=true]

############################################################################

proc build_setup_source_post {} {
    ## change critical warning about eplicit dont care 
    #INFO: [Synth 8-638] synthesizing module 'operand_mux' [/home/****/workspace/FPGA/SpecMgr/SpecMgr_Build_branch_alex/PICOPU/rtl/operand_mux.vhd:65]
    #CRITICAL WARNING: [Synth 8-5550] found explicit dontcare in slice;  simulation mismatch may occur 
    set_msg_config -id {[Synth 8-5550]} -new_severity "WARNING"
    
    ## change critical warning about ILA CDC waiver being empty
    #WARNING: [Vivado 12-508] No pins matched 'get_pins -hierarchical -filter {NAME =~ u_ila_0/*/CLK}'. [/home/****/workspace/FPGA/SpecMgr/SpecMgr_Build/SM_FPGA/par/constraints/cdc_waivers.xdc:5]
    #CRITICAL WARNING: [Vivado_Tcl 4-919] Waiver ID 'CDC-1' -from list should not be empty. [/home/****/workspace/FPGA/SpecMgr/SpecMgr_Build/SM_FPGA/par/constraints/cdc_waivers.xdc:5]
    #WARNING: [Vivado 12-508] No pins matched 'get_pins -hierarchical -filter {NAME =~ u_ila_0/*/CLK}'. [/home/****/workspace/FPGA/SpecMgr/SpecMgr_Build/SM_FPGA/par/constraints/cdc_waivers.xdc:6]
    #CRITICAL WARNING: [Vivado_Tcl 4-919] Waiver ID 'CDC-10' -from list should not be empty. [/home/****/workspace/FPGA/SpecMgr/SpecMgr_Build/SM_FPGA/par/constraints/cdc_waivers.xdc:6]
    set_msg_config -id {[Vivado_Tcl 4-919]} -new_severity "WARNING"

    ## change ciritical warning about null range in re-used as-is AXD rx_dwncnvt
    # the error applies to an attempted sign extend that is not needed so the error applies to a line that becomes not applicable
    # CRITICAL WARNING: [Synth 8-507] null range (24 downto 25) not supported [/home/jenkins/workspace/FPGA/SpecMgr/SpecMgr_Build_branch_alex/ws/Downconvert_Subsystem/rtl/ddc_fir.vhd:288]
    set_msg_config -id {[Synth 8-507]} -new_severity "WARNING"

    ## Change critical warning about IOBs from critical warning to warning.
    ## When we build telem image without ui_subsystem and without HDQ we get thise IOB messages.
    ## Don't want to fail the build for these critical warnings.
    #CRITICAL WARNING: [Place 30-722] Terminal 'DEBUG_LED' has IOB constraint set to TRUE, 
    #but it is either not connected to a FLOP element or the connected FLOP element could not be brought into the I/O
    set_msg_config -id {[Place 30-722]} -new_severity "WARNING"

    ## This shows as a critical warning but sometimes timing is fixed after this step.  The build process
    ## checks timing anyway, so don't want to fail on this critical warning.
    # CRITICAL WARNING: [Route 35-39] The design did not meet timing requirements. Please run report_timing_summary for detailed reports.
    set_msg_config -id {[Route 35-39]} -new_severity "WARNING"
}

proc build_par_post {} {
    set_property CONFIG_MODE    SPIx4 [current_design]

    set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
    set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes [current_design]
    set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR NO [current_design] 
    set_property BITSTREAM.CONFIG.SPI_BUSWIDTH    4 [current_design]
    set_property BITSTREAM.GENERAL.COMPRESS        TRUE       [current_design]

    #set_property BITSTREAM.CONFIG.TIMER_CFG 32'h5ffff [current_design],  timeout 1/65e6*256*hex2dec('5FFFF') = 1.5s
    set_property BITSTREAM.CONFIG.TIMER_CFG 32'h5ffff [current_design]
}

proc build_bitstream_post {} {
    global PRJ_TOP_NAME IMAGE_OUTPUT_NAME outputDir image_name errors_passed timing_passed critical_warn_passed cdc_critical_passed ENCRYPT_BITSTREAM

    # this should be run from the par directory to find version.bin
    
    # originally from build_jade_tx_working.tcl
    # http://subversion.shure.com/Projects/Taishan/RX_FPGA_DUAL/Toplevel_DBA/branches/Jade_branches/Spartan7Tx/Portable_SLXD/par

    # this gets called from:
    # $PYTHONSIM_PATH/VivadoBuild/build_nonproject_vivado.tcl
    # a.k.a. src/pythonsim/PythonSim/VivadoBuild/build_nonproject_vivado.tcl
    #
    # $outputDir is a global we can use. This is a bad practice, but I'm not ready to refactor this script just for this.

    # this logic must match the logic in build_bistream in order to be sure the filename is correct here
    # the will have _FAILED added to it if the build has trouble with timing, cdc, critical warnings, errors.
    # but we still want to produce the _working output files to allow the artifacts to be produced
    # and the scripts and reports to complete
    
    set image_name_base $PRJ_TOP_NAME
    if {[info exists IMAGE_OUTPUT_NAME]} {
        set image_name_base $IMAGE_OUTPUT_NAME
    }

    set working_append "_working"
    set working_name $image_name_base$working_append

    set key_append "_bitstream_enc"
    set keyfile $IMAGE_OUTPUT_NAME$key_append

    set enc_append "_enc"
    #set golden_name_enc $golden_name$enc_append

     if {$errors_passed && $timing_passed && $critical_warn_passed && $cdc_critical_passed} {
        set image_name $image_name_base
        set image_name_enc $image_name_base$enc_append
        set working_name_enc $working_name$enc_append
    } else {
        ## append failed to bitstream image to clearly indicate build had problems
        set bit_append "_FAILED"
        set image_name $image_name_base$bit_append
        set image_name_enc $image_name_base$enc_append$bit_append
        set working_name_enc $working_name$enc_append$bit_append
        set working_name $working_name$bit_append
        #set image_name_enc $image_name_base_enc$bit_append
    }
   



    # version.bin is generated by scripts/update_version

    puts "write _working .bin and .mcs files. These files have version information in the first four bytes. Use scripts/bin_version to read the version"
    write_cfgmem -force -format bin -size 32 -interface SPIx4 -loaddata "up 0x0 version.bin up 0x100 $outputDir/${image_name}.bin" $outputDir/${working_name}
    write_cfgmem -force -format MCS -size 32 -interface SPIx4 -loaddata "up 0x0 version.bin up 0x100 $outputDir/${image_name}.bin" $outputDir/${working_name}
 
    if {[info exists ENCRYPT_BITSTREAM] && $ENCRYPT_BITSTREAM==1} {
        #if {[file exists ./$keyfile.nky]} {
            puts "Write Encrypted .bin and .mcs"
            write_cfgmem -force -format bin -size 32 -interface SPIx4 -loaddata "up 0x0 version.bin up 0x100 $outputDir/${image_name_enc}.bin" $outputDir/${working_name_enc}
            write_cfgmem -force -format MCS -size 32 -interface SPIx4 -loaddata "up 0x0 version.bin up 0x100 $outputDir/${image_name_enc}.bin" $outputDir/${working_name_enc}
            file copy -force $outputDir/$image_name_enc.bin $outputDir/$image_name.enc
            #file delete -force ./$keyfile.nky
        #} else {
        #    puts "WARNING: Bitstream encryption requested but $keyfile.nky is not found. Either PMP (password manager pro) related issue or build was local. Only Jenkins builds with the appropriate PMP_API_KEY can encrypt."
        #}
    }

#   combined --------
    # puts "write multiboot"


    # _MB stands for multiboot
    # _image.bit files are the input files

# How to determine maximum bin size.
# https://docs.xilinx.com/r/en-US/ug470_7Series_Config/Configuration-Bitstream-Lengths


    ######
    # We are not producing _MB images, because the software packager will be in charge of putting together golden, FM, Digital and future images into a multiboot setup.
    # Embedded and FPGA will have to coordinate the order of these so the offsets in this code match theirs

}


## This initiates the building process automatically.
## You can manually go through the process by doing:
##
##     source scripts/setup_vivado
##     vivado -mode tcl
##     Vivado% set DISABLE_AUTO_BUILD 1
##     Vivado% source build.tcl --notrace
##     Vivado% build_setup_source; build_synth
##


# https://stackoverflow.com/questions/49873768/tcl-equivalent-to-pythons-if-name-main
if {$::argv0 eq [info script]} {
    puts [info script]
    # Do the things for if the script is run as a program (e.g. via vivado command line)...

    source "../scripts/fpgabuild/build_nonproject_vivado.tcl"

    # This is equivalent:
    # set DISABLE_AUTO_BUILD 1
    # source $PYTHONSIM_PATH/VivadoBuild/build_nonproject_vivado.tcl
    # build_setup_source
    # build_synth
    # build_opt
    # build_par
    # build_bitstream
    # build_final_summary
    

} else {
    # for interactive debug
    puts [info script]
    set DISABLE_AUTO_BUILD 1
    source $PYTHONSIM_PATH/VivadoBuild/build_nonproject_vivado.tcl
    puts "running via source"

    # you can jump straight to this point
    # generate golden bitstream
    #build_golden_bitstream
}

