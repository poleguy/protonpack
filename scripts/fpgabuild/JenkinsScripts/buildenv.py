#!/usr/bin/python3
import os
import platform
import re
import sys

COMMENT_RE  = re.compile("^\s*#.*")
VARIABLE_RE = re.compile("-*([A-Za-z0-9_]+) *= *(.+)")
FIXUP_RE = re.compile("%([A-Za-z0-9_]+)%")

########################################################
# Helper function to remove line endings from a string #
########################################################
def chomp(x):
    if x.endswith("\r\n"): return x[:-2]
    if x.endswith("\n"): return x[:-1]
    return(x)

###############################################################
# This class encapsulate the data found in the JenkinsScripts #
# configuration files.                                        #
#                                                             #
# The format of the file is the classic ini file format with  #
# the following exceptions:                                   #
#                                                             #
# 1. a # will start a comment that will continue to the end   #
# of the line                                                 #
#                                                             #
# 2. String substitutions can be performed on a value         #
# by enclosing the name of the variable to use in the         #
# substitution is '%' chareacter.                             #
#                                                             #
# ex:                                                         #
#                                                             #
#    DYNAMIC_FOLDER=here                                      #
#    BUILD_DIR=build/files/%DYNAMIC_FOLDER%/                  #
#                                                             #
#    Will result in BUILD_DIR to be 'build/files/here/'.      #
#                                                             #
# Usage:                                                      #
#                                                             #
#     from buildenv import BuildEnv                           #
#                                                             #
#     buildmap = {}                                           #
#                                                             #
#     env = BuildEnv('/somefile.conf')                        #
#     build_dir = env.Var("BUILD_DIR")                        #
#     buildmap = env.Buildmap()                               #
#     build_dir = buildmap("BUILD_DIR)                        #
#                                                             #
###############################################################
class BuildEnv(object):
    def __init__(self, filename, section = ''):
        self.env_vars = {}
        if "WORKSPACE" in os.environ:
            self.env_vars["WORKSPACE"] = os.environ["WORKSPACE"]

        if os.path.isfile(filename):
            with open(filename) as fh:
                for ln in fh:
                    ln = chomp(ln)
                    match = COMMENT_RE.search(ln)
                    if not match:
                        match = VARIABLE_RE.search(ln)
                        if match:
                            name = match.group(1).upper()
                            value = match.group(2)
                            self.env_vars[name] = value

        for name in self.env_vars:
            self.__fixup__(name)

    #########################################################
    # Parse the command line variables and add any args in  #
    # the form of key=value to the list of configuration    #
    # values. Allow the presence of leading '-' characters  #
    # but strip it from the name.                           #
    #########################################################
    def ParseCommandLineArgs(self, argv):
        for arg in argv[1:]:
#            print("arg = {}".format(arg))
            match = VARIABLE_RE.search(arg)
            if match:
                name = match.group(1).upper()
                value = match.group(2)
#                print("name = {}, value = {}".format(name, value))
                self.env_vars[name] = value
        for name in self.env_vars:
            self.__fixup__(name)

    ######################################################
    # Replace all of th %<name>% with the variables that #
    # have been defined.                                 #
    ######################################################
    def __fixup__(self, name):
        rv = 0
        if name in self.env_vars:
            string = self.env_vars[name]
            for match in FIXUP_RE.finditer(string):
                rv += 1
                subrepl = match.group(0)
                subname = match.group(1)
                if subname in self.env_vars and len(self.env_vars[subname]):
                    string = string.replace(subrepl, self.env_vars[subname])
            self.env_vars[name] = string

        ####################################################
        # Recurse your way through until everyone is fixed #
        ####################################################
        if rv > 0:
            self.__fixup__(name)
        return(rv)

    ##################################################
    # This function returns the string for the named #
    # parameter                                      #
    ##################################################
    def Var(self, name):
        rv = ''
        if name in self.env_vars:
            rv = self.env_vars[name]
        return(rv)

    ########################################################
    # This function returns a dictionary with the full set #
    # of variables in the configuration file               #
    ########################################################
    def BuildMap(self):
        return(self.env_vars)

###########################################################
# Running buildenv.py itself will echo the config data    #
# (with all of the translations etc) as a sequnece of key #
# value pairs that can be injected into the envoronment.  #
#                                                         #
# This is to provide jenkins jobs direct access to the    #
# parameters defined within the config file.              #
#                                                         #
# Only one argument is accepted.                          #
#                                                         #
#     config=<fn>                                         #
#                                                         #
# If this is not present, the filename of the config file #
# will be taken from the environment variable CONFIG.     #
###########################################################
if __name__ == "__main__":
    config_fn = ""
    if "COMMON" in os.environ:
        sys.path.insert(0, os.environ["COMMON"])
    if "CONFIG" in os.environ:
        config_fn = os.environ["CONFIG"]
    for arg in sys.argv[1:]:
        if len(arg.split('=')) > 1:
            (cmd, val) = arg.split('=', 2)
            if len(val) > 0:
                if "config" in cmd.lower():
                    config_fn = val
    env = BuildEnv(config_fn)
    env.ParseCommandLineArgs(sys.argv)
    for env_key in env.env_vars.keys():
        if env_key not in os.environ:
            print('{}={}'.format(env_key, env.env_vars[env_key]))
