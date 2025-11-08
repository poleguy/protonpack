####################################################
## 
##  xil_ip_generate.tcl
##
##  This file is used to create a temporary IP project 
##  and generate the source files for a .xci IP file
##
##  The input argument is the .xci path/filename
##
##  Files are generated in the [ipname]_generated folder
##
##
##  From python you might do(depending on relative path of python script to this tcl file)
##
##        import os
##        ipfile='../DigitalBoard/rtl/clk_wiz3/clk_wiz_3.xci'
##        os.system('vivado -mode batch -notrace -source xil_ip_generate.tcl -tclargs '+ipfile)
##


## Check for correct number of arguments (just file name)
if {[llength #argv] != 1} {
    error "xil_ip_generate.tcl:  ERROR! Expecting 1 argument for IP filename #args=[llength#argv]"
    return -code 1
}

set gen_list_file [lindex $argv 0]
puts "xil_ip_generate.tcl:  File list file name argument is [lindex $argv 0]"; #indexes start at 0

set first_time 1

set f_list [open $gen_list_file]

## iterate through each xci file in the gen file list 
while {[gets $f_list line] != -1} {
    set ip_file $line
    puts "xil_ip_generate.tcl:  ip_file=$ip_file"

    ## Verify the IP file exists
    if {[file exists $ip_file]==0} { 
        error "xil_ip_generate.tcl:  ERROR! $ip_file not found!"
        return -code 1
    } else {

        ## Open the .xci and pull out the part number to create a temp project with correct part number
        set f [open $ip_file]

        while {[gets $f line] != -1} {
            if {[regexp {DEVICE\">(.*)<} $line all value]} {
                set family $value
            }
            if {[regexp {PACKAGE\">(.*)<} $line all value]} {
                set package $value
            }
            if {[regexp {SPEEDGRADE\">(.*)<} $line all value]} {
                set speed $value
            }
            if {[regexp {TEMPERATURE_GRADE\">(.*)<} $line all value]} {
                set temperature $value
            }
            # 2025.1 has a different format.
            # this should be coded in python with an xml library, not regex
            if {[regexp {DEVICE\": \[ \{ \"value\": \"(.*)\"} $line all value]} {
                set family $value
            }
            if {[regexp {PACKAGE\": \[ \{ \"value\": \"(.*)\"} $line all value]} {
                set package $value
            }
            if {[regexp {SPEEDGRADE\": \[ \{ \"value\": \"(.*)\"} $line all value]} {
                set speed $value
            }
            if {[regexp {TEMPERATURE_GRADE\": \[ \{ \"value\": \"(.*)\"} $line all value]} {
                if {$value != ""} {
                    # handle no value as a special case
                    set temperature $value
                }
            }
        }
        close $f
        if {![info exists family] || ![info exists package] || ![info exists package]} {
            error "xil_ip_generate.tcl:  ERROR! partname could not be pulled from $ip_file. Looking for DEVICE, PACKAGE, AND SPEEDGRADE within the xci file. (TEMPERATURE_GRADE optional for new parts)"
            return -code 1
        }
        if {![info exists temperature]} {
            set partname $family-$package$speed
        } else {
            set partname $family-$package$speed-$temperature
        }
        puts "xil_ip_generate.tcl:  Partname pulled from xci text is $partname"
    }

    # maybe better to just push in a partname from the calling scripts?
    ## xc7a100tfgg484-2
    set partname "xc7a100tfgg484-2"
    
    ## only create the project for the first xci file
    ## part number is going to be drive from the first xci
    ## pull each time for reference in case have mismatch part xci files
    if {$first_time} {

        set first_time 0
        ## create the project in memory for non-proj mode
        #create_project -in_memory -ip -part $partname
        # create the temp project on disk to facilitate manual generation of output products, or unlocking ip in the case of:
        # CRITICAL WARNING: [filemgmt 20-1365] Unable to generate target(s) for the following file is locked: ...
        
        create_project -name blahblahblah -force -ip -part $partname
        ##create_project -in_memory -part $partname
        ## need this otherwise most ip will generate vhdl source
        set_property target_language Verilog [current_project]        
    }

    ## disect the xci abs path and copy the xci to ./[name]_generated folder to separate the generated outputs from other possible source files
    #set path [file dirname $ip_file]
    #set ipfile [file tail $ip_file]
    #set ipname [lindex [split $ipfile "."] 0]
    #set path_output "${path}/${ipname}_generated"
    #if {[file exists $path_output]} { file delete -force $path_output }
    #file mkdir $path_output
    #file copy -force $ip_file $path_output
    ### src_new is the new temporary xci file in the *_generated folder
    #set src_new "$path_output/$ipfile"


#    ## if the _generated folder contains an [xci name].mif file, add it to the project.  e.g. fir IP has a .mif file with rom initalization
#    set ip_file_no_ext [lindex [split $ip_file "."] 0]
#    set mif_file "$ip_file_no_ext.mif"
#    puts "mif_file=$mif_file"
#
#    if {[file exists $mif_file]} { 
#        puts "xil_ip_generate.tcl .mif file found in _generated folder, add it before generating sourece "
#        add_files $mif_file
#    }
    #
    # read ip in to the project and generate the output products
    read_ip $ip_file

    set ip_list [get_ips *]

    
    # Extract the filename without extension
    # presume this will always match the result of get_ips
    # if it doesn't this will have to get fancier
    set filename [file rootname [file tail $ip_file]]
    
    foreach ip $ip_list {
        if {$ip == $filename} {
            set ip $filename
            # some IP's switch back to VHDL for some reason, try to force them to Verilog
            #set_property PREFHDL Verilog [current_project]

            # if it is locked, unlock it
            set is_locked [get_property IS_LOCKED [get_ips $ip]]
            if {$is_locked} {
                puts "The IP '$ip' is locked."
                puts "WARNING: Once it is upgraded the user must copy the updated, generated .xci file over the original .xci."
                puts "e.g.:"
                puts "meld rtl/gt_support/ila_1/ila_1_generated/ila_1.xci rtl/gt_support/ila_1/ila_1.xci"
                upgrade_ip [get_ips $ip]
            } else {
                puts "The IP '$ip' is not locked."
            }
        }
    }
    puts "generating target"
    generate_target all [get_files $ip_file]

    #set path [file dirname $ip_file]
    set export_sim_dir "[file dirname $ip_file]/export_sim_modelsim/"

    ## export simulation for reference
    export_simulation -absolute_path -quiet -of_objects [get_files $ip_file] -directory $export_sim_dir -simulator modelsim -force
    puts "xil_ip_generate.tcl:  Generated source for IP $ip_file"
} 
#end of while

close_project

exit
