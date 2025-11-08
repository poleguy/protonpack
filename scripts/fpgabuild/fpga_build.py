###############################################################
## Helper scripts for 1647 FPGA Design Builds
## Includes svn checkout of workspace, SVN revision control check in, and Artifactory commits
##
##  A. Stezskal, N. Dietz, C. Zebedee
##
###############################################################

import os
import datetime

from .JenkinsScripts import SaveComponentArtifacts

#from dataclasses import dataclass
#@dataclass
#class VersionDateTime


import os
import shutil
import re
from typing import Dict, Any, Optional

NUMERIC_VERSION_KEYS = {"MAJOR", "MINOR", "PATCH", "BUILD"}
DATE_TIME_KEYS = {"YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND"}

def ensure_file_from_template(target_file: str, template_path: str) -> None:
    """
    Ensure the target file exists; if not, copy from the provided template.
    """
    if not os.path.exists(target_file):
        if not os.path.exists(template_path):
            raise FileNotFoundError(f"Template file not found: {template_path}")
        os.makedirs(os.path.dirname(os.path.abspath(target_file)), exist_ok=True)
        shutil.copyfile(template_path, target_file)


def _to_int(value: Any) -> int:
    """
    Convert a value to int. Accepts int, decimal string, or hex string.
    """
    if isinstance(value, int):
        return value
    s = str(value).strip()
    try:
        return int(s, 10)
    except ValueError:
        return int(s, 16)


def _hex_padded_bits(value: int, bits: int) -> str:
    """
    Convert value to uppercase hex string, masked and padded to bits' nibble width.
    """
    mask = (1 << bits) - 1 if bits < 64 else (1 << bits) - 1  # generic mask
    v = value & mask
    nibble_width = (bits + 3) // 4
    return f"{v:0{nibble_width}X}"


def update_version_constants_in_file(
    file_path: str,
    version: Dict[str, Any],
    template_path: str,
) -> None:
    """
    Update only the C_VERSION_* localparam assignments in a SystemVerilog source file.

    - Ensures the target file exists (copies from template if missing).
    - Updates the right-hand side of matching localparams without touching other content.
    - Numeric version keys (MAJOR/MINOR/PATCH/BUILD) are emitted as decimal (d).
    - Date/time keys (YEAR/MONTH/DAY/HOUR/MINUTE/SECOND) are emitted as hex (h).
    """
    ensure_file_from_template(file_path, template_path)

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    def make_pattern_for_key(key: str) -> re.Pattern:
        # Matches: ... C_VERSION_<KEY> = <bits>'<base><value> ... ;
        # Keeps prefix/suffix to preserve formatting/comments.
        return re.compile(
            rf"(?P<prefix>(?:^|.*?))"
            rf"(C_VERSION_{re.escape(key)}\s*=\s*)"
            rf"(?P<bits>\d+)"
            rf"'(?P<base>[dh])"
            rf"(?P<val>-?[0-9A-Fa-f]+)"
            rf"(?P<suffix>\s*;.*?)$",
            re.MULTILINE
        )

    updated_content = content

    # Iterate provided keys and update only if found
    for key, raw_val in version.items():
        pattern = make_pattern_for_key(key)
        value_int = _to_int(raw_val)

        def repl(m: re.Match) -> str:
            bits = int(m.group("bits"))
            prefix = m.group("prefix")
            lhs = m.group(2)  # "C_VERSION_<KEY> = "
            suffix = m.group("suffix")

            if key in NUMERIC_VERSION_KEYS:
                # Decimal assignment
                return f"{prefix}{lhs}{bits}'d{value_int}{suffix}"
            elif key in DATE_TIME_KEYS:
                value_bcd = _bcd_to_int(value_int)
                # Hex assignment, padded to bits
                hex_str = _hex_padded_bits(value_bcd, bits)
                
                return f"{prefix}{lhs}{bits}'h{hex_str}{suffix}"
            else:
                # Default to decimal for unknown keys
                return f"{prefix}{lhs}{bits}'d{value_int}{suffix}"

        # Replace occurrences for this key (if none, leave content unchanged)
        updated_content = pattern.sub(repl, updated_content)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(updated_content)

def _int_to_bcd(val):
    # convert bcd, e.g. year as 0x2025 (8229) to integer 2025
    return int(f"{val:x}",10)

def _bcd_to_int(val):
    # convert integer, e.g. year as 2025 to bcd 0x2025 (8229)
    return int(f"{val}",16)

def read_version_constants(file_path: str) -> Optional[Dict[str, int]]:
    """
    Parse C_VERSION_* localparam assignments in a SystemVerilog source file and
    return a dict of values.

    Accepts decimal ('d', supports negative) and hex ('h') bases.
    """
    if not os.path.exists(file_path):
        return None

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    result: Dict[str, int] = {}
    # Example match: localparam logic [7:0] C_VERSION_MAJOR = 8'd12;
    # Or: localparam logic [15:0] C_VERSION_YEAR = 16'h2025;
    param_re = re.compile(
        r"C_VERSION_(?P<key>[A-Z_]+)\s*=\s*(?P<bits>\d+)'(?P<base>[dh])(?P<val>-?[0-9A-Fa-f]+)",
        re.MULTILINE
    )

    for m in param_re.finditer(content):
        key = m.group("key")
        base = m.group("base")
        val_str = m.group("val")
        try:
            val = int(val_str, 10 if base == "d" else 16)
        except ValueError:
            # Skip malformed entries
            continue
        # convert date time keys from bcd to decimal
        if key in DATE_TIME_KEYS:    
            ## get just the hex value bcd string and convert to int
            ## in the below example want the 2021
            ##   localparam logic [15:0] C_VERSION_YEAR   = 16'h2021;
            result[key] = _int_to_bcd(val)
        else:
            result[key] = val

    return result if result else None


class fpga_build(object):
    # no default for rtl_version_file, so it's easy to understand where the source is when this object is used in a script
    # the default use should be:
    # build=fpga_build(rtl_version_file="rtl/version_pkg.sv")
    def __init__(self, rtl_version_file): 
        # todo: version shouldn't be allowed to be uninitialized like this:
        # this should probably not be a class at all, or if it is it should be initialized with a file name
        self.rtl_version_file=rtl_version_file
        self.template_path: str = "scripts/fpgabuild/version_pkg_sv.template"

        ensure_file_from_template(rtl_version_file, self.template_path)
        self.version = self.read_pkg_version(rtl_version_file=rtl_version_file)

    def get_artifact_version(self):
        # returns a version in the format 0_10_20_255  
        v = self.version
        artifact_version = f"{v['MAJOR']}_{v['MINOR']}_{v['PATCH']}_{v['BUILD']}"
        return artifact_version

    def get_version(self):
        # returns a version in the format 0.10.20.255  
        v = self.version
        artifact_version = f"{v['MAJOR']}.{v['MINOR']}.{v['PATCH']}.{v['BUILD']}"
        return artifact_version

    def read_pkg_version(self, rtl_version_file):
        """Reads a package file containing constants in the C_VERSION_* naming convention with std_logic_vector(to_unsigned assignments
           returns a version dictionary with the version in the package file.
           See write_pkg_version for more info on file format.           
           Doesn't try to be smart about branches/git/svn
        """
        
        assert(os.path.isfile(rtl_version_file)),"rtl_version_file does not exist: "+str(rtl_version_file)

     
        return read_version_constants(rtl_version_file)

    def write_pkg_version(self):
        """ Writes version verilog package file based on the current self.version state.
            Order of operations should be read_pkg_version, update_version, write_pkg_version
        """
        update_version_constants_in_file(self.rtl_version_file,version=self.version,template_path=self.template_path)


    def update_version(self): #, use_branch_version_scheme=True):
        """update_version takes the current version variable (which requires read_pkg_version() be called prior)
           and increments the build number.  

           If build number rolls over from 255 to 256, the minor number will be automatically incremented.
           
           If you want build number to roll to 0 (without updating the minor), then you can 
            manually put a -1 in the VHDL for build number and check-in.  Then when the build goes it will be 0. 
                constant C_VERSION_BUILD : std_logic_vector(07 downto 0) := std_logic_vector(to_unsigned(-1,8)); 
            todo: I've unfortunately seen bugs related to having -1 in there. I think you can't sim it that way.
           
        """
        #self.use_branch_version_scheme=use_branch_version_scheme

        #if(self.parent_is_branch and use_branch_version_scheme):
        #    self.version["PATCH"]=99
        self.version["BUILD"]+=1

        ## if build number rolls over to 256 increment the minor number
        if(self.version["BUILD"]==256):
            self.version["MINOR"]+=1
            self.version["BUILD"]=0
            
        ## Set the current date time to the self.version dictionary
        self.version["YEAR"]   = int(datetime.datetime.now().strftime("%Y"))
        self.version["MONTH"]  = int(datetime.datetime.now().strftime("%m"))
        self.version["DAY"]    = int(datetime.datetime.now().strftime("%d"))
        self.version["HOUR"]   = int(datetime.datetime.now().strftime("%H"))
        self.version["MINUTE"] = int(datetime.datetime.now().strftime("%M"))
        self.version["SECOND"] = int(datetime.datetime.now().strftime("%S"))


    def read_pkg_version_and_update(self, rtl_version_file): 
        #print("fpga_build.read_pkg_version_and_update")
        self.read_pkg_version(rtl_version_file=rtl_version_file)
        self.update_version() 
        self.write_pkg_version()


    def get_artifactory_url_all_shure(self, artifact_component):
        """get artifactory url of current version.
        Can be used to help generate a commit message.
        """
        artifactory_url_all_shure="https://artifactory.shure.com/All_Shure_Components/"+artifact_component+"/"+self.get_version()+"/"

        return artifactory_url_all_shure


    # todo: these functions are unrelated to the version update scripting, put them in a different module

    def commit_artifactory_dirs(self, artifact_component, artifact_dist_dir, artifact_meta_dir):
        """Commit build output artifacts to artifactory.shure.com
        under Continuous repo
        Artifact_dist_dir is the directory for image(s) that would flow to product package
        Meta dir is the directory for reports and other files not used by higher level packages
        These file inputs should be directory paths
        All files and subdirectories will be pulled in relative to these paths 
        relative to the current working directory when this is called.
        """

        self.artifact_component=artifact_component

        ret = SaveComponentArtifacts.main(component_name=artifact_component,
            version=self.get_artifact_version(),
            build_dir="./",
            commit_distributable_dir=artifact_dist_dir,
            commit_meta_dir=artifact_meta_dir)
    
        return ret


    def commit_artifactory_developer_dirs(self, artifact_component, artifact_dist_dir, artifact_meta_dir):
        """Commit build output artifacts to artifactory.shure.com
        under Developer repo
        Artifact_dist_dir is the directory for image(s) that would flow to product package
        Meta dir is the directory for reports and other files not used by higher level packages
        These file inputs should be directory paths
        All files and subdirectories will be pulled in relative to these paths 
        relative to the current working directory when this is called.
        """

        self.artifact_component=artifact_component

        ret = SaveComponentArtifacts.main(component_name=artifact_component,
            version=self.get_artifact_version(),
            build_dir="./",
            commit_distributable_dir=artifact_dist_dir,
            commit_meta_dir=artifact_meta_dir,
            developer=True)
        return ret


#if __name__ == "__main__":
#    read_pkg_version(rtl_version_file)
#    update_version()
#    write_pkg_version()
