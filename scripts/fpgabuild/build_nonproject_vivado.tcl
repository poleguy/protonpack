####
#### #######################################
#### Minimum Required Parameters to be set prior to sourceing this tcl script from a build.tcl file
####
####   
####   PRJ_TOP_NAME          This is the exact name of the top module, e.g. "fpga_top"
####
####   PRJ_PART              This is the exact name of the part, e.g. "xc7z045ffg900-2"
####
####
####
#### ########################################
#### Optionally can set the following :
###
####
####    outputDir             by default all reports/logs/bitstream goes to par/output, can specify alt
####
####    IMAGE_OUTPUT_NAME     If set, will change the naming of output bin,bit,ltx. If not set, will use PRJ_TOP_NAME.
####
####    DISABLE_AUTO_BUILD    If set to 1, only sources this tcl file, does not run build, can call proc manually
####                          This might be useful if have to do any particular properties to files
####                          before synth.
####
####    DISABLE_LATCH_ERROR   If set to 1, latches reported as default critical warning instead of error.
####
####    SYNTH_FLATTEN         If set, use this synth flatten method, otherwise default
####    SYNTH_FSM_EXTRACTION  If set, use this fsm extraction method, otherwise default
####    SYNTH_EXTRA_ARGS      If set, this string is appended to the end of the synth_design command.
####                                This must be a tcl list here is an example:
####                                set SYNTH_EXTRA_ARGS [list -generic NUM_CH=4 -generic INCLUDE_DEBUG=true]
####
####
####    TIMING_OPTIMIZED_PAR  If set to 1, run PAR commands focused on timing performance (does not use SYNTH_* spec above)
####
####    DISABLE_MCS_FILE      If set to 1, do not generate an mcs fild during build_bitstream
####
####    FAIL_ON_CRITICAL_WARN      If set to 1, fail build on any critical warnings.
####    FAIL_ON_CRITICAL_CDC       If set to 1, fail build on any critical warnings from report_cdc.
####
####    CDC_WAIVER_XDC_FILE   Optionally point to an xdc file relative to /par which is read at very end 
####                          of build process right before running report_cdc.
####                          Reference Vivado 2018.2 bug related to cdc_waiver and checkpoint error
####                            
####    ENCRYPT_BITSTREAM     If set to 1, generate an encrypted bitstream using an nky keyfile, requested from PMP
####                            
####
####
#### ########################################
####  Source compile.txt How-To
####
####    The build process utilizes one or more compile.txt files that list the relative source files to be built.
####  The first compile.txt file should be in the parent directory of the design OR in /rtl file.  Beyond this 
####  requirement, each compile.txt can link to another compile.txt file with a relative path.  The files in 
####  each compile.txt file is relative to that compile.txt files location.
####
####  e.g. ../compile.txt:
####
####        ## ../compile.txt
####        rtl/compile.txt
####        ../DAC/compile.txt
####        ../ADC/compile.txt
####
####  In the above example DAC and ADC are modules checked out separately from the FPGA repo itself.
####  They contain their own compile.txt files.
####
####  rtl/compile.txt e.g.
####
####        ## rtl/compile.txt
####        fpga_top.vhd
####        gtwizard_eth.xci
####        regs/register.vhd --2008
####
####  Comments can be included in the compile.txt files via a leading # character.
####
####  Files listed in compile.txt files can have arguments.  The current arguments are 
####  
####        2008                Optionally sets the vhdl-2008 property. (see e.g. above)
####                            Default is to not set vhdl-2008.
####
####        gen_and_remove      This argument is for .xci files and if set adds the IP, generates the sources,
####                            but then removes the IP file.  This allows the user to add and manage the 
####                            IP sources manually, while still generating sources from a IP file.
####
####
#### ########################################
####  Build Processes
####
####  There are a series of build processes that are called automatically (or manually via tcl console).
####
####    build_setup_source      Setup the project and read the compile.txt source files.
####                            Reads all constraint files in par/constraints
####
####    build_synth             Run synthesis and save post_synth.dcp
####
####    build_par               Run par and save post_par.dcp
####
####    build_bitstream         Build bitstream and flash binary.
####
####    build_final_summary     Output some final summary results of the build
####
####
####  Each build process calls a post build step custom procedure if it exists.  They are as follows:
####     build_setup_source_post, build_synth_post, build_par_post, build_cdc_exceptions, build_bitstream_post
####  If these *_post processes exist in build.tcl, they will be called at the appropriate time in the build.
####    
#### ########################################
####  Outputs
####
####    All outputs are written to par/output including reports, design checkpoints, and images.
####
####
####
####
####
####
####


# ## if script not sourced while working directory is /par, cd
# set script_path [ file dirname [ file normalize [ info script ] ] ]
# puts $script_path
# cd $script_path

## set the output directory where all vivado reports, logs, and bitstreams will be written
if {![info exists outputDir]} {
    set outputDir output
}


## read the source based on compile.txt files and then add it to vivado
# also blows away output directory or creates it if it doesn't exist
proc build_setup_source {} {
    global PRJ_PART script_path outputDir 
    #CDC_WAIVER_XDC_FILE

    ##set up the build scratch folder and the build output folders
    if {[file exists $outputDir]} { file delete -force $outputDir }
    file mkdir $outputDir

#    # check existence of files and error out early if not found
#    if {[info exists CDC_WAIVER_XDC_FILE]} {
#        puts "Checking existance of CDC_WAIVER_FILE..."
#        if {[file exists $CDC_WAIVER_XDC_FILE]==0} { 
#            puts "ERROR: $CDC_WAIVER_XDC_FILE is not found. Check settings of CDC_WAIVER_XDC_FILE variable."
#            return -code 1
#        } else {
#            puts "CDC_WAIVER_FILE file found here: $CDC_WAIVER_XDC_FILE"
#        }
#    } else {
#        puts "CDC_WAIVER_XDC_FILE not set."
#    }

    set build_compile_file "compile_cmd_list.txt"
    
    if {[file exists $build_compile_file]==0} { 
        puts "ERROR: $build_compile_file is not found.  This file should be produced and exist in the vivado working directory by calling compile_file_generation.py prior to calling vivado with this build_nonproject_vivado.tcl file."
        return -code 1
    } else {
        puts "build_setup_source: Python compile_file_generation.py completed and compile cmd file exists $build_compile_file.  Starting to add files to Vivado"
    }

    set f [open $build_compile_file r]
    set sourcelist [split [string trim [read $f]] "\n"]

    ## create the project in memory for non-proj mode
    create_project -in_memory -part $PRJ_PART

    # assume all our designs in Verilog and that's the target (can still read in VHDL with no isses)
    # if this is set to VHDL you might end up with generated outputs having PREFHDL set to VHDL not Verilog
    set_property target_language Verilog [current_project]

    ## The following message comes as a critical warnings - however the time it takes to add files is not concerning so downgrade to a Warning...
            ## CRITICAL WARNING: [Vivado 12-3645] Please note that adding or importing multiple files, one at a time, can be performance intensive.  Both add_files and import_files commands accept multiple files as input, and passing a collection of multiple files to a single add_files or import_files commands can offer significant performance improvement.
    set_msg_config -id {[Vivado 12-3645]} -new_severity "WARNING"

    ## source the command list produced by calling compile_file_generation
    source $build_compile_file

    report_compile_order -file $outputDir/report_compile_order.rpt

  #  file copy -force compile.txt $outputDir/compile.txt

    if {[info procs build_setup_source_post] != ""} {
        build_setup_source_post
    }
}

proc build_synth {} {
    ## required 
    global PRJ_TOP_NAME PRJ_PART outputDir
    ## optional if set
    global SYNTH_FLATTEN SYNTH_FSM_EXTRACTION DISABLE_LATCH_ERROR TIMING_OPTIMIZED_PAR SYNTH_EXTRA_ARGS

    ## latches in designs are strongly discouraged so set an ERROR if one exists
    if {!([info exists DISABLE_LATCH_ERROR] && $DISABLE_LATCH_ERROR==1)} {
        set_msg_config -id {[Synth 8-327]} -new_severity "ERROR"
    }

    ## If an rtl architecure is replaced, flag as ERROR to stop the build (as opposed to warning)
    set_msg_config -id {[Synth 8-2489]} -new_severity "ERROR"


    ## determine any synthesis arguments
    if {![info exists SYNTH_FLATTEN]} {
        # if not set, use default:
        set SYNTH_FLATTEN "rebuilt"
    }
    if {![info exists SYNTH_FSM_EXTRACTION]} {
        # if not set, use default:
        set SYNTH_FSM_EXTRACTION "auto"
    }
    ## if nothing set, set to an empty list
    if {![info exists SYNTH_EXTRA_ARGS]} {
        set SYNTH_EXTRA_ARGS [list]
    }

    set timing_opt_par 0
    if {[info exists TIMING_OPTIMIZED_PAR]} {
        if {$TIMING_OPTIMIZED_PAR==1} {
            set timing_opt_par 1
        }
    }

    ## note for SYNTH_EXTRA_ARGS, {*} syntax expands a list into normal commands

    if {$timing_opt_par} {
        synth_design -flatten_hierarchy $SYNTH_FLATTEN -top $PRJ_TOP_NAME -part $PRJ_PART -directive AreaOptimized_high -shreg_min_size 10 -control_set_opt_threshold 0 -fsm_extraction off {*}$SYNTH_EXTRA_ARGS
    } else {
        synth_design -top $PRJ_TOP_NAME -part $PRJ_PART -flatten $SYNTH_FLATTEN -fsm_extraction $SYNTH_FSM_EXTRACTION {*}$SYNTH_EXTRA_ARGS
    }

    if {[info procs build_synth_post] != ""} {
        build_synth_post
    }

    #report_control_sets -hierarchical -hierarchical_depth 4 -verbose -file $outputDir/post_synth_control_sets.rpt
    ## summary first then append useful hierarchical
    report_utilization -file $outputDir/post_synth_util.rpt
    report_utilization -hierarchical -hierarchical_depth 3 -append -file $outputDir/post_synth_util.rpt

    ## this should be the very last step, to account for any changes done in build_synth_post
    write_checkpoint -force $outputDir/post_synth.dcp
}
proc build_opt {} {
    global TIMING_OPTIMIZED_PAR
    global outputDir
    global OPT_EXTRA_ARGS

    #open_checkpoint $outputDir/post_synth.dcp

    set timing_opt_par 0
    if {[info exists TIMING_OPTIMIZED_PAR]} {
        if {$TIMING_OPTIMIZED_PAR==1} {
            set timing_opt_par 1
        }
    }

    ## if nothing set, set to an empty list
    if {![info exists OPT_EXTRA_ARGS]} {
        set OPT_EXTRA_ARGS [list]
    }

    ## note for OPT_EXTRA_ARGS, {*} syntax expands a list into normal commands

    if {$timing_opt_par} {
        opt_design -directive ExploreSequentialArea {*}$OPT_EXTRA_ARGS
    } else {
        opt_design  {*}$OPT_EXTRA_ARGS
    }

    if {[info procs build_opt_post] != ""} {
        build_opt_post
    }

    #report_control_sets -hierarchical -hierarchical_depth 4 -verbose -file $outputDir/post_opt_control_sets.rpt
    ## summary first then append useful hierarchical
    report_utilization -file $outputDir/post_opt_util.rpt
    report_utilization -hierarchical -hierarchical_depth 3 -append -file $outputDir/post_opt_util.rpt

    ## this should be the very last step, to account for any changes done in build_opt_post
    write_checkpoint -force $outputDir/post_opt.dcp
}

proc build_par {} {
    global outputDir
    global TIMING_OPTIMIZED_PAR
    global timing_passed
    global PLACE_EXTRA_ARGS

    #open_checkpoint $outputDir/post_opt.dcp

    set timing_opt_par 0
    if {[info exists TIMING_OPTIMIZED_PAR] && $TIMING_OPTIMIZED_PAR==1} {
        set timing_opt_par 1
    }

    ## if nothing set, set to an empty list
    if {![info exists PLACE_EXTRA_ARGS]} {
        set PLACE_EXTRA_ARGS [list]
    }

    if {$timing_opt_par} {
        place_design -directive Explore
        phys_opt_design -directive AggressiveExplore
        route_design -directive Explore
        phys_opt_design -directive AggressiveExplore
    } else {
        place_design {*}$PLACE_EXTRA_ARGS
        if {[info procs build_place_post] != ""} {
            build_place_post
        }
        route_design
    }

    if {[info procs build_par_post] != ""} {
        build_par_post
    }

    report_timing_summary -file $outputDir/post_route_timing_summary.rpt

    #report_control_sets -hierarchical -hierarchical_depth 4 -verbose -file $outputDir/post_route_control_sets.rpt
    ## summary first then append useful hierarchical
    report_utilization -file $outputDir/post_route_util.rpt
    report_utilization -hierarchical -hierarchical_depth 3 -append -file $outputDir/post_route_util.rpt
	
    #report_power -file $outputDir/post_route_power.rpt
    #report_drc -file $outputDir/post_imp_drc.rpt

    ## this should be the very last step, to account for any changes done in build_par_post
    write_checkpoint -verbose -force $outputDir/post_route.dcp

}

proc count_critical_warnings {} {
    global outputDir errors_passed critical_warn_passed cdc_critical_passed error_warning_string
    global FAIL_ON_CRITICAL_WARN FAIL_ON_CRITICAL_CDC
    ## open vivado.log and parse
    set f [open vivado.log]
    set text [read $f]
    close $f

    # Remove lines starting with ##. Avoids counting text in build scripts
    regsub -all -line "^.*##.*(?:\n|$)" $text "" text
    
    # Count matches
    set cnt_critical [regexp -all  "CRITICAL WARNING:" $text]
    set cnt_errors [regexp -all  "ERROR:" $text]

    ## open cdc critical report and parse
    set f_cdc [open $outputDir/report_cdc.rpt]
    set text_cdc [read $f_cdc]
    close $f_cdc
    # todo: parsing this text file could be fragile. Maybe find a programmatic way of getting the count?
    # we now fail on any cdc that is not waived because they should all be treated carefully
    set cnt_cdc_critical [regexp -all "Critical" $text_cdc]
    set cnt_cdc_warning [regexp -all "Warning" $text_cdc] 
    set cnt_cdc_total [expr $cnt_cdc_critical + $cnt_cdc_warning ]

    # report the results
    set error_warning_string " $cnt_errors ERRORS found in vivado.log.\n\
     $cnt_critical CRITICAL WARNINGS found in vivado.log. \n\
     $cnt_cdc_total WARNING/CRITICAL Clock Domain Crossing warnings in report_cdc.rpt."

    if {$cnt_errors==0} {
        set errors_passed 1
    } else {
        set errors_passed 0
    }

    set critical_warn_passed 1
    if {[info exists FAIL_ON_CRITICAL_WARN] && $FAIL_ON_CRITICAL_WARN==1} {
        if {$cnt_critical>0} {
            set critical_warn_passed 0
        }
    }
    set cdc_critical_passed 1
    if {[info exists FAIL_ON_CRITICAL_CDC] && $FAIL_ON_CRITICAL_CDC==1} {
        if {$cnt_cdc_critical>0} {
            set cdc_critical_passed 0
        }
    }

}

proc check_timing {} {
    global timing_passed
    ## check timing
    # Setup time slack make sure >= 0
    if {[expr {[get_property SLACK [get_timing_paths]] < 0}]} {
        set timing_passed 0
    # Hold time slack make sure >= 0
    } elseif {[expr {[get_property SLACK [get_timing_paths -hold]] < 0}]} {
        set timing_passed 0
    } else {
        set timing_passed 1
    }
}

proc build_bitstream {} {
    global outputDir PRJ_TOP_NAME timing_passed bitstream_name DISABLE_MCS_FILE errors_passed critical_warn_passed cdc_critical_passed  IMAGE_OUTPUT_NAME ENCRYPT_BITSTREAM
    # CDC_WAIVER_XDC_FILE

    ## purposely open fresh post_route.dcp again because report_cdc & cdc_waivers have bugs which cause DRC related things to fail
    open_checkpoint $outputDir/post_route.dcp
    # if {[info exists CDC_WAIVER_XDC_FILE]} {
    #     puts "read_xdc $CDC_WAIVER_XDC_FILE"
    #     read_xdc $CDC_WAIVER_XDC_FILE
    # }
    # limiting report_cdc with -severity Critical will prevent CDC-15 warnings from showing up, which may mask real problems.
    report_cdc -file $outputDir/report_cdc.rpt -no_header -details -all_checks_per_endpoint
    report_cdc -file $outputDir/report_cdc_waived.rpt -no_header -details -waived -all_checks_per_endpoint
    report_waivers -file $outputDir/report_cdc_waivers.rpt

    ## open fresh checkout without any cdc waivers set to avoid vivado bugs
    open_checkpoint $outputDir/post_route.dcp

    check_timing
    count_critical_warnings

    set gen_mcs 1
    if {[info exists DISABLE_MCS_FILE] && $DISABLE_MCS_FILE==1} {
        set gen_mcs 0
    }

    set image_name_base $PRJ_TOP_NAME
    if {[info exists IMAGE_OUTPUT_NAME]} {
        set image_name_base $IMAGE_OUTPUT_NAME
    }
    
    set enc_append "_enc"
    set image_name_base_enc $image_name_base$enc_append

    if {$errors_passed && $timing_passed && $critical_warn_passed && $cdc_critical_passed} {
        set image_name $image_name_base
        set image_name_enc $image_name_base_enc
    } else {
        ## append failed to bitstream image to clearly indicate build had problems
        set bit_append "_FAILED"
        set image_name $image_name_base$bit_append
        set image_name_enc $image_name_base_enc$bit_append
    }
    if {$gen_mcs} {
        set_property BITSTREAM.CONFIG.CONFIGRATE 22 [current_design]
        set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes [current_design]
    }

    write_debug_probes -force $outputDir/$image_name_base.ltx
    write_bitstream -force -bin_file $outputDir/$image_name.bit

    if {$gen_mcs} {
        write_cfgmem -force -format MCS -size 32 -interface SPIx1 -loadbit "up 0x0 $outputDir/$image_name.bit" $outputDir/$image_name.mcs
    }

    set key_append "_bitstream_enc"
    set keyfile $image_name_base$key_append
    if {[info exists ENCRYPT_BITSTREAM] && $ENCRYPT_BITSTREAM==1} {
        if {[file exists ./$keyfile.nky]} {
            set_property BITSTREAM.ENCRYPTION.ENCRYPT YES [current_design]
            set_property BITSTREAM.ENCRYPTION.ENCRYPTKEYSELECT EFUSE [current_design]
            set_property BITSTREAM.ENCRYPTION.KEYFILE ./$keyfile.nky [current_design]
            write_bitstream -force -bin_file $outputDir/$image_name_enc.bit
            file copy -force $outputDir/$image_name_enc.bin $outputDir/$image_name.enc
            file delete -force ./$keyfile.nky
        } else {
            puts "WARNING: Bitstream encryption requested but $keyfile.nky is not found. Either PMP (password manager pro) related issue or build was local. Only Jenkins builds with the appropriate PMP_API_KEY can encrypt."
        }
    }

    if {[info procs build_bitstream_post] != ""} {
        build_bitstream_post
    }
}

proc build_final_summary {} {
    global timing_passed bitstream_name outputDir error_warning_string errors_passed timing_passed critical_warn_passed cdc_critical_passed FAIL_ON_CRITICAL_WARN FAIL_ON_CRITICAL_CDC

    puts "\n"
    puts "-------------------------------------"
    puts "--  Build Result Summary"
    puts "-------------------------------------"
    puts $error_warning_string

    if {$timing_passed} {
        puts "\n TIMING FOR THE DESIGNED PASSED.\n"
    } else {
        puts "\n TIMING FOR THE DESIGNED HAS FAILED!\n"
    }
    set cur_dir pwd
    puts " Output Products: [pwd]/$outputDir"
    puts "\n"

    ## create a result_pass.txt file in $outputDir if build is succesful
    ## use this in Jenkins automation to determine SUCCESS or FAILURE
    ## this file will not exist if build ERROR or timing failed
    if {$errors_passed && $timing_passed && $critical_warn_passed && $cdc_critical_passed} {
        set f [open $outputDir/result_pass.txt w]
        puts " BUILD PASSED"
        puts $f "BUILD PASSED"
        close $f
    } else {
        puts " BUILD FAILED"
    }
    puts "\n-------------------------------------"
    puts " errors_passed=$errors_passed  timing_passed=$timing_passed  critical_warn_passed=$critical_warn_passed  cdc_critical_passed=$cdc_critical_passed"

    if {[info exists FAIL_ON_CRITICAL_WARN] && $FAIL_ON_CRITICAL_WARN==1} {
        set fail_setting_string "FAIL_ON_CRITICAL_WARN=$FAIL_ON_CRITICAL_WARN  "
    } else {
        set fail_setting_string "FAIL_ON_CRITICAL_WARN=(not set)  "
    }
    if {[info exists FAIL_ON_CRITICAL_CDC] && $FAIL_ON_CRITICAL_CDC==1} {
        set fail_setting_string "$fail_setting_string FAIL_ON_CRITICAL_CDC=$FAIL_ON_CRITICAL_CDC  "
    } else {
        set fail_setting_string "$fail_setting_string FAIL_ON_CRITICAL_CDC=(not set)  "
    }
    puts $fail_setting_string

    # copy vivado.log into output directory for eventual archival in artifactory
    # we will do all file copying in scripts/deploy_artifactory, not here
    #file copy -force vivado.log $outputDir/vivado.log
}

proc del_all_except {exception} {
    set path [file dirname $exception]
    set file_list [glob -nocomplain $path/*]

    puts "del_all_except: Cleaning up Vivado IP Directory $path"

    foreach f $file_list {
        if {[string match $exception $f]==0} {
            puts "    file delete $f"
            file delete -force $f
        } else {
            puts "    file keep   $f"
        }
    }
}

## run through the build proces unless DISABLE_AUTO_BUILD is set
if {!([info exists DISABLE_AUTO_BUILD] && $DISABLE_AUTO_BUILD==1)} {
    build_setup_source
    ## create a report of the current status of the SVN checkout modules
    build_synth
    build_opt
    build_par
    build_bitstream
    build_final_summary
}

