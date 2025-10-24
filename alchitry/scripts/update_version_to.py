#!/usr/bin/env python
#################################################################################
##
## update version to given version
#################################################################################
import os
from fpgabuild import fpga_build

def update_to(version="0.0.0.0"):
    rtl_version_file="rtl/version_pkg.v"
    
    
    version_bin_filename = "par/version.bin"
    if os.path.isfile(version_bin_filename):
        os.remove(version_bin_filename)
    
    ## instantiate the helper build scripts
    ## This reads the current revision from the rtl version package file
    build = fpga_build.fpga_build(rtl_version_file=rtl_version_file)
        
    version_part =  version.split(".")
    version_part = list(map(int,version_part))

    build.version["MAJOR"] = version_part[0]
    build.version["MINOR"] = version_part[1]
    build.version["PATCH"] = version_part[2]
    build.version["BUILD"] = version_part[3]
    
    # setting use_branch_version_scheme to false is necessary to set the patch arbitrarily (not forced to 99 if a branch)
    # we updated manually, so we don't need this function
    #build.update_version(use_branch_version_scheme=False)  
    build.write_pkg_version()
    
    # convert to bcd
    def bcd(decimal_int):
        decimal_string = str(decimal_int)
        digits = [int(c) for c in decimal_string]
        value = 0
        for digit in digits:
    #        print(digit)
            value = (value<<4) + digit
    #        print(f'value: {value:X}')
        return value
    
    ver = (build.version["MAJOR"]<<24) + (build.version["MINOR"]<<16) + (build.version["PATCH"]<<8) +build.version["BUILD"]
    ver = ver.to_bytes(4, byteorder='big', signed=False)
    
    date = (bcd(build.version["YEAR"])<<16) + (bcd(build.version["MONTH"])<<8) + bcd(build.version["DAY"])
    date = date.to_bytes(4, byteorder='big', signed=False)
    
    time = (bcd(build.version["HOUR"])<<24) + (bcd(build.version["MINUTE"])<<16) + (bcd(build.version["SECOND"])<<8)
    time = time.to_bytes(4, byteorder='big', signed=False)
    with open(version_bin_filename,'wb') as file:
        file.write(ver)
        file.write(date)
        file.write(time)
    
if __name__ == '__main__':
    import typer
    typer.run(update_to)
