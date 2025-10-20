###############################################################
## Helper scripts for 1647 FPGA Design Builds
## Includes svn checkout of workspace, SVN revision control check in, and Artifactory commits
##
##  A. Stezskal, N. Dietz
##
###############################################################

import os
import datetime

from .JenkinsScripts import SaveComponentArtifacts

#from dataclasses import dataclass
#@dataclass
#class VersionDateTime




class fpga_build(object):
    def __init__(self): 

        self.version = {
            'MAJOR' : 0,
            'MINOR' : 1,
            'PATCH' : 2,
            'BUILD' : 3,
            'YEAR'  : 4,
            'MONTH' : 5,
            'DAY'   : 6,
            'HOUR'  : 7,
            'MINUTE': 8,
            'SECOND': 9
         }
        self.artifact_version=None

#        self.use_branch_version_scheme=True

#    def check_if_svn_repo_is_branch(self, svn_checkout_path):
#        """ This function checks if the svn repo associated with svn_checkout_path is a branch or trunk
#        if the svn comand does not properly work it will raise an error
#        The svn_checkout path can just be the version_pkg.vhd file path.
#        """
#        process = Popen(["svn", "info", svn_checkout_path], stdout=PIPE)
#        (output, err) = process.communicate()
#        info_str=output.decode(encoding='UTF-8')
#        exit_code = process.wait()
#        start=info_str.find("URL:")
#        end=info_str.find("\n",start)
#        url=info_str[start:end]
#
#        if('branches' in url and 'trunk' in url):
#            print(info_str)
#            print("url=",url)
#            assert(False),"branches and trunk both found in url cannot determine if trunk or branch build. SVN info:\n"+info_str
#        elif('trunk' in url):
#            self.parent_is_branch=False
#        elif('branches' in url):
#            self.parent_is_branch=True
#        else:
#            print(info_str)
#            print("url=",url)
#            assert(False),"neither branches or trunk found in url cannot determine if trunk or branch build. SVN info:\n"+info_str
#
#        print("svn repo detected")
#        print("self.parent_is_branch="+str(self.parent_is_branch))
#
#        return self.parent_is_branch
#
#    def check_if_git_repo_is_branch(self):
#        """ checks if current location repo is git master or a branch 
#        if it's not a git repo, it will error out
#        """
#        #https://stackoverflow.com/questions/37890510/bash-script-to-check-if-the-current-git-branch-x
#        #git rev-parse --abbrev-ref HEAD
#        process = Popen(["git", "rev-parse", "--abbrev-ref","HEAD"], stdout=PIPE)
#        (output, err) = process.communicate()
#        result=output.decode(encoding='UTF-8')
#        exit_code = process.wait()
#        assert(exit_code==0),"git call returned a non-zero exit code:"+str(exit_code)
#
#        self.branch_name=result.strip() #keep case sensitivity
#        self.parent_is_branch=True
#        if(self.branch_name.lower() in ['master', 'head']):
#            self.branch_name='master'
#            self.parent_is_branch=False
#
#        #print("git branch checked is: "+str(self.branch_name))
#        #print("self.parent_is_branch="+str(self.parent_is_branch))
#
#        return self.parent_is_branch

    def get_artifact_version(self):
        if self.artifact_version:
            return self.artifact_version
        else:
            raise ValueError("call read_pkg_version() and set_artifact_version()  first")

#    def svn_export(self, modules_svn_url):
#        self.modules_svn_url=modules_svn_url
#        ### Step:  SVN Export (download)  set_up_local_workspacy.py for 
#        # If SVN is succesful, os.system will return 0, otherwise it will return something else on error.
#        set_up_local_workspace_url="http://svn.shure.com/Common/1647/Scripts/PythonSim/trunk/set_up_local_workspace.py@427499"
#        assert (os.system("svn --non-interactive --force export "+set_up_local_workspace_url)==0), "SVN Export failed.  Check network connections and SVN credentials for "+set_up_local_workspace_url
#
#        ### SVN Export (download)  modules.txt
#        assert (os.system("svn --non-interactive --force export "+self.modules_svn_url)==0), "SVN Export failed.  Check network connections and SVN credentials for "+self.modules_svn_url

#    def check_repo_url(self, parent_repo):
#        """  Check that modules.txt file matches parent repo.  
#             This protects against making a branch and forgetting to update modules.txt to point to the branch.
#         """
#        self.parent_repo=parent_repo
#        modules_argument_dir = os.path.dirname(self.modules_svn_url)
#        modules_argument_filename = os.path.basename(self.modules_svn_url)
#
#        modules_parent_repo_line=""
#        with open(modules_argument_filename, 'r') as infile:
#            lines=""
#            for line in infile:
#                lines+=line
#                if line.strip().lower()[0:len(self.parent_repo)]==self.parent_repo.lower():
#                    modules_parent_repo_line=line
#        assert(modules_parent_repo_line!=""),"\nCould not find the parent repo "+self.parent_repo+" in the downloaded modules.txt file "+self.modules_svn_url+"\n"+lines
#        modules_file_dir=modules_parent_repo_line.split(" ")[-1].replace("subversion","svn").strip().lower()
#        modules_argument_dir=modules_argument_dir.replace("subversion","svn").strip().lower()
#        repo_url_info_str= "argument parent repo:     "+modules_argument_dir+"\n"+"modules file name:"+modules_file_dir
#
#        assert(modules_argument_dir==modules_file_dir),"Expected the provided modules.txt svn url as an argument to match the parent repo url in the modules.txt file, but it does not.  Possibly someone created a copy of the design and did not update the modules checkout file."+"\n"+repo_url_info_str
#        print(repo_url_info_str, flush=True)
#        if "branches" in modules_file_dir : 
#            print("Setting branch true", flush=True)
#            self.parent_is_branch=True
#
#    ## utilize set_up_local_workspace.py to do a module checkout procedure according to a modules.txt or module_version_file.txt framework file
#    ## this modules file lists the modules that need to be checked out for a given design.
#    def module_checkout(self, modules_svn_url, parent_repo):
#        self.svn_export(modules_svn_url)
#        self.check_repo_url(parent_repo)
#        assert(os.system("python3 ./set_up_local_workspace.py -c ./"+os.path.basename(self.modules_svn_url))==0),"set_up_local_workspace.py returned a non-zero error code"

    def read_pkg_version(self, rtl_version_file):
        """Reads a package file containing constants in the C_VERSION_* naming convention with std_logic_vector(to_unsigned assignments
           Saves the version in the package file to the class variable self.version
           See write_pkg_version for more info on file format.
           self.version stores version as an integer.
           Doesn't try to be smart about branches/git/svn
        """
        #print("fpga_build.read_pkg_version")

        self.rtl_version_file=rtl_version_file
        assert(os.path.isfile(self.rtl_version_file)),"rtl_version_file does not exist: "+str(self.rtl_version_file)
        with open(self.rtl_version_file, 'r') as f:
            for key in ["MAJOR", "MINOR", "PATCH", "BUILD", "YEAR", "MONTH", "DAY", "HOUR", "MINUTE", "SECOND"]:
                for line in f:
                    find_idx=line.find("VERSION_"+key)
                    if(find_idx!=-1):
                        if key in ["MAJOR", "MINOR", "PATCH", "BUILD"]:
                            ## get just the string integer from the to_unsigned
                            ## in the below example want the 39
                            ## constant C_VERSION_BUILD   : std_logic_vector(07 downto 0) := std_logic_vector(to_unsigned(  39,8));
                            val_int=line.split('to_unsigned(')[1].split(",")[0]
                        else:
                            ## get just the hex value string and convert to int
                            ## in the below example want the 2021
                            ## constant C_VERSION_YEAR    : std_logic_vector(15 downto 0) := X"2021";
                            val_int=line.split(':= X"')[1].split('";')[0]
                        self.version[key]=int(val_int)
                        #print("Read "+str(val_int)+" dec for "+key+" from file"+self.rtl_version_file, flush=True)
                        break


    def set_artifact_version(self):
#        """
#           use_branch_version_scheme inserts a 99 for patch if built from a branch (in update_version()), 
#           and appends DATE and TIME to the usual version in artifactory if built from a branch (in set_artifact_version())
#           it also prevents builds with 99 patch to be built in master
#        """

#        if(self.parent_is_branch==False and self.version["PATCH"]==99):
#            assert(False),"This is not a branch however PATCH number in "+str(self.rtl_version_file)+" is already set to 99.  Maybe someone accidently merged branch version_pkg.vhd to trunk? set .parent_is_branch=True to override."

        ## artifactory is all decimal display so fix all revision fields to 3 wide to support 0 through 255
        ## then if its a branch, append the entire datetime to the BUILD field
        self.artifact_version=str(self.version["MAJOR"])+"_"+str(self.version["MINOR"])+"_"+str(self.version["PATCH"])+"_"
        ## handle build number a little different whether a branch or not, if branch make fixed width and also append DATETIME 
        #if(self.parent_is_branch and self.use_branch_version_scheme):
        #    self.artifact_version+="{0:0>3}".format(str(self.version["BUILD"]))+"{0:0>4}".format(str(self.version["YEAR"]))+"{0:0>2}".format(str(self.version["MONTH"]))+"{0:0>2}".format(str(self.version["DAY"]))+"{0:0>2}".format(str(self.version["HOUR"]))+"{0:0>2}".format(str(self.version["MINUTE"]))+"{0:0>2}".format(str(self.version["SECOND"]))
        #else:
        self.artifact_version+=str(self.version["BUILD"])

        #print("artifact version="+self.artifact_version, flush=True)



# todo: change this so that it just updates the part of the file that matters, rather than re-writing the whole file from scratch.
# it should still be a source file that should be able to contain other things.
# see tcl implementation by frantisak
    def write_pkg_version(self):
        """ Writes version vhdl package file based on the current self.version state.
            Order of operations should be read_pkg_version, update_version, write_pkg_version
        """

        def mhex(val, w=2):
            return "{0:0{1}x}".format(val,w)


        pkg_name=os.path.basename(self.rtl_version_file).split(".")[0]
        pkg_file_str='\n\
-------------------------------------------------\n\
-- '+str(self.rtl_version_file)+'\n\
--------------------------------------------------\n\
--\n\
-- Copyright 2025 Shure Incorporated\n\
-- CONFIDENTIAL AND PROPRIETARY TO SHURE\n\
--\n\
--------------------------------------------------\n\
--\n\
-- This pkg file is auto-generated by fpga_build.py and \n\
-- contains the version and date/time information.\n\
--\n\
\n\
library ieee;\n\
use ieee.std_logic_1164.all;\n\
use ieee.numeric_std.all;\n\
\n\
package '+pkg_name+' is\n\n'
        pkg_file_str+="    -- Note in order to get a build version of 0, you are able to manually put a -1 for BUILD and the fpga_build.read_pkg_version_and_update()\n    -- will have it roll around to 0 without incrementing the minor number for a roll around.\n"

        for key in self.version.keys():
            if(key=="YEAR"):
                left="15"
                width=4
            else:
                left="07"
                width=2
            longest = max(len(key) for key in self.version.keys())
            const_name="{0: <{width}}".format(str(key),width=longest+1) 
            const_val="{0:>4}".format(str(self.version[key]))
            if(key in ["MAJOR", "MINOR", "PATCH", "BUILD"]):
                pkg_file_str+="    constant C_VERSION_"+const_name+" : std_logic_vector("+str(left)+" downto 0) := std_logic_vector(to_unsigned("+const_val+","+str(int(left)+1)+"));\n"
            else:
                pkg_file_str+="    constant C_VERSION_"+const_name+" : std_logic_vector("+str(left)+" downto 0) := X\""+"{0:0>{width}}".format(str(self.version[key]),width=width)+"\";\n"

        pkg_file_str+='\n\
end '+pkg_name+';\n\
--------------------------------------------------------------------------------\n\
'
        with open(self.rtl_version_file, 'w') as f:
            f.write(pkg_file_str)

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


    def read_pkg_version_and_update(self, rtl_version_file): #, use_branch_version_scheme=True):
        print("fpga_build.read_pkg_version_and_update")
        self.read_pkg_version(rtl_version_file=rtl_version_file)
        self.update_version() #use_branch_version_scheme)
        self.write_pkg_version()


#    def commit_svn_source(self, svn_source_files_commit):
#        """ commit any auto generated source as part of this build process back to SVN
#            with a comment including the artifactory version and url
#            svn_source_files_commit should be python list
#        """
#        svn_co_str="svn commit --non-interactive "
#        for svn_file in svn_source_files_commit:
#            file_stripped=svn_file.strip()
#            assert(os.path.isfile(file_stripped)),"File targeted to commit does not exist: "+svn_file
#            svn_co_str+=" "+file_stripped+" "
#        try:
#            # todo: should this also support Developer_Components
#            artifactory_url="https://artifactory.shure.com/CI_Components/"+self.artifact_component+"/"+self.get_artifact_version().replace("_",".")+"/"
#            artifactory_url_all_shure="https://artifactory.shure.com/All_Shure_Components/"+self.artifact_component+"/"+self.get_artifact_version().replace("_",".")+"/"
#        except:
#            artifactory_url="(need to call commit_artifactory before commit_svn_source)"
#
#        svn_co_str+=" -m 'Auto-commit source from build. Artifact version: "+self.get_artifact_version()+"  Artifact URL: "+artifactory_url_all_shure+"'"
#
#        assert(os.system(svn_co_str)==0),"svn commit did not return a successful 0"


#    def commit_git_source(self, source_files_list, commit_leading_msg="Auto-commit source from build."):
#        """commit any auto generated source as part of this build process back to SVN
#           svn_source_files_commit should be python list
#       """
#        def git_cmd(cmd):
#            print(cmd)
#            process = Popen(shlex.split(cmd))
#            exit_code = process.wait()
#            assert(exit_code==0),"Exit code for "+cmd+" returned non-zero error code "+str(exit_code)
#
#        ## do a git pull (which is also a merge of latest) in case there were changes since this build started
#        ## this should allow us to commit the build results unless there are specific conflicts
#
#        for source_file in source_files_list:
#            file_stripped=source_file.strip()
#            assert(os.path.isfile(file_stripped)),"File targeted to commit does not exist: "+source_file
#            git_cmd("git add "+source_file)
#
#        commit_msg=self.get_commit_message(self.artifact_component, commit_leading_msg)
#
#        git_cmd("git commit -m '"+commit_msg+"'")
#
#        git_cmd("git fetch") # get latest from server for this branch
#
#        git_cmd("git stash") # if there's other local files that are not being commited, have to stash them before rebase
#                             # if a version control file has changed, however maybe it should be actually commited as well?
#
#        ## This will take the local changes and be able to commit them, even if this checkout was out of date.  We want
#        ## to commit the version_pkg.vhd used for this build with the artifactory commit.
#        ## the "theirs" in this rebase command is confusing since we are actually keeping "ours" (local) with this command.
#        ## see https://stackoverflow.com/questions/16825849/choose-git-merge-strategy-for-specific-files-ours-mine-theirs
#        git_cmd("git rebase -X theirs")
#
#        git_cmd("git push")


    def get_commit_message(self, artifact_component, commit_leading_msg="Auto-commit source from build."):
        """get a commit message containing the url and version of the artifactory commit. For checking in auto generated code created as part of the build process.
        """
        artifactory_url_all_shure="https://artifactory.shure.com/All_Shure_Components/"+artifact_component+"/"+self.get_artifact_version().replace("_",".")+"/"
        commit_msg=commit_leading_msg+" Artifact version: "+self.get_artifact_version()+"  Artifact URL: "+artifactory_url_all_shure+""
        
        return commit_msg

    def get_artifactory_url_all_shure(self, artifact_component):
        """get artifactory url of current version.
        """
        artifactory_url_all_shure="https://artifactory.shure.com/All_Shure_Components/"+artifact_component+"/"+self.get_artifact_version().replace("_",".")+"/"

        return artifactory_url_all_shure

#    def commit_artifactory(self, artifact_component, artifact_dist_files, artifact_meta_files):
#        """Commit build output artifacts to artifactory.shure.com
#        under Continuous repo
#        Artifact_dist_files is the image that would flow to product package
#        Meta files are like reports and other files not used by higher level packages
#        These file inputs should be lists of file names
#        The file path location is relative to the current working directory when this is called.
#        """
#
#        ## Set the artifact version based on Revision and Date/Time appended if branch
#        self.set_artifact_version()
#
#        self.artifact_component=artifact_component
#        meta_files_no_spaces = ",".join(artifact_meta_files)
#        dist_files_no_spaces = ",".join(artifact_dist_files)
#
#        # https://stackoverflow.com/questions/49955228/change-python-3-sys-argv-when-calling-a-function
#        saved_argv = sys.argv
#        try:
#            sys.argv = ["dummy_command_name", "--component_name="+artifact_component,
#                        "version="+self.get_artifact_version(),
#                        'BUILD_DIR=./',
#                        "COMMIT_DISTRIBUTABLE_FILES="+dist_files_no_spaces,
#                        "COMMIT_META_FILES="+meta_files_no_spaces
#                        ]
#            print(sys.argv, flush=True)
#            ret = SaveComponentArtifacts.main()
#        finally:
#            sys.argv = saved_argv
#        #assert(os.system(sv_components_str)==0),"python call for SaveComponentArtifacts.py for Artifactory commit did not return a successful 0"
#        return ret
#
#    def commit_artifactory_developer(self, artifact_component, artifact_dist_files, artifact_meta_files):
#        """Commit build output artifacts to artifactory.shure.com
#        under Developer repo
#        Artifact_dist_files is the image that would flow to product package
#        Meta files are like reports and other files not used by higher level packages
#        These file inputs should be lists of file names
#        The file path location is relative to the current working directory when this is called.
#        """
#        ## Set the artifact version based on Revision and Date/Time appended if branch
#        self.set_artifact_version()
#
#        self.artifact_component=artifact_component
#        meta_files_no_spaces = ",".join(artifact_meta_files)
#        dist_files_no_spaces = ",".join(artifact_dist_files)
#
#        # https://stackoverflow.com/questions/49955228/change-python-3-sys-argv-when-calling-a-function
#        saved_argv = sys.argv
#        try:
#            sys.argv = ["dummy_command_name",
#                        "--developer",
#                        "--component_name="+artifact_component,
#                        "version="+self.get_artifact_version(),
#                        'BUILD_DIR=./',
#                        ## These file inputs should be comma separated lists with no spaces i.e.  post_route.dcp,timing.rpt
#                        "COMMIT_DISTRIBUTABLE_FILES="+dist_files_no_spaces,
#                        "COMMIT_META_FILES="+meta_files_no_spaces
#                        ]
#            print(sys.argv, flush=True)
#            ret = SaveComponentArtifacts.main()
#        finally:
#            sys.argv = saved_argv
#        #assert(os.system(sv_components_str)==0),"python call for SaveComponentArtifacts.py for Artifactory commit did not return a successful 0"
#        return ret

    def commit_artifactory_dirs(self, artifact_component, artifact_dist_dir, artifact_meta_dir):
        """Commit build output artifacts to artifactory.shure.com
        under Continuous repo
        Artifact_dist_dir is the directory for image(s) that would flow to product package
        Meta dir is the directory for reports and other files not used by higher level packages
        These file inputs should be directory paths
        All files and subdirectories will be pulled in relative to these paths 
        relative to the current working directory when this is called.
        """

        ## Set the artifact version based on Revision and Date/Time appended if branch
        self.set_artifact_version()

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
        ## Set the artifact version based on Revision and Date/Time appended if branch
        self.set_artifact_version()

        self.artifact_component=artifact_component

        ret = SaveComponentArtifacts.main(component_name=artifact_component,
            version=self.get_artifact_version(),
            build_dir="./",
            commit_distributable_dir=artifact_dist_dir,
            commit_meta_dir=artifact_meta_dir,
            developer=True)
        return ret


#if __name__ == "__main__":
#    args=setup_arguments()
#    svn_export(args)
#    check_repo_url(args)
#    module_checkout(args)
#    os.system("svn co http://svn.shure.com/Projects/Blackhawk/FPGA/SM_FPGA/trunk/par/output SM_FPGA/par/output")
#    read_pkg_version(args)
#    update_version(args)
#    write_pkg_version(args)
#    print("pwd=",os.getcwd())
#    if(not os.path.isfile(args.artifact_dist_files)):
#        print('artifact distributable file '+args.artifact_dist_files+' not found indicating build did not complete.  Not checking in source or artifacts')
#    commit_svn_source(args)
#    commit_artifactory(args)
#
