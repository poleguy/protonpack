#!/usr/bin/python3
from . Artifactory.Artifacts import ArtifactStates, ArtifactRepos, Artifact, ArtifactTypes, \
                                  Component, FILE_TYPE_PROPERTY_NAME, VERSION_PROPERTY_NAME, SOURCE_PROPERTY_NAME, \
                                  DuplicateArtifactException
#                                  Component, Package, FILE_TYPE_PROPERTY_NAME, VERSION_PROPERTY_NAME, SOURCE_PROPERTY_NAME, \

#from .buildenv import BuildEnv
from .common import ErrorCodes
from logging import critical, error, info, warning, debug, \
                    CRITICAL, ERROR, INFO, WARNING, DEBUG, \
                    basicConfig
import glob
import getpass
import os
import re
import sys
from pathlib import Path

import logging
# give this module its own logger, tied to its namespace.
# This will inherit the output location of the module that calls this
log = logging.getLogger(__name__) 

def get_all_files(root_path):
    """Return a list of all files recursively under root_path."""
    return [str(p) for p in Path(root_path).rglob('*') if p.is_file()]

VERSION_RE = re.compile("([0-9]+)[-._]([0-9]+)[-._]([0-9]+)[-._]([0-9]+)", re.I)

#############################################################
# This function tests for all of the filenames and filename #
# globs specified in the parameter filenames and appends    #
# any of those names that could not be found withing the    #
# directory named by the parameter build_dir to the list of #
# missing filenames passed in the parameter missing_files.  #
#                                                           #
# The function returns error_list with any additional names #
# appended to it.                                           #
#############################################################
def test_filenames(filenames, build_dir, missing_files):
    debug("test_filenames(): filenames = {}".format(filenames))
    for fn in filenames:
        if not fn == '':
            debug("test_filenames(): raw fn = {}".format(fn))
            pathname = os.path.join(build_dir, fn.strip())
            flist = glob.glob(pathname)
            debug("test_filenames(): flist = {}".format(flist))
            if len(flist) > 0:
                for fn in flist:
                    debug("test_filenames(): fn = {}".format(fn))
                    if not os.path.isfile(fn):
                        missing_files.append(fn)
                        debug("Adding missing_file = '{}'".format(fn))
            else:
                missing_files.append(pathname)
                debug("Adding missing pathname = '{}'".format(pathname))
    return missing_files


def count_path_elements(path):
    norm = os.path.normpath(path)
    return len(norm.split(os.sep))

def main(component_name: str,
    version:str,
    build_dir,
    commit_distributable_dir,
    commit_meta_dir,
    developer:bool = False):
                     
    user_id         = getpass.getuser()
    


    if developer:
        repo_type = ArtifactRepos.DEVELOPER
    else:
        repo_type = ArtifactRepos.CONTINUOUS

    # you could change this to "DEBUG" for example
    basicConfig(level=ERROR, stream=sys.stdout)
    info("log_level = ERROR")


    match = VERSION_RE.search(version)
    if not match:
        raise Exception("version number not formatted correctly.")

    comp_version = match.group(1)
    comp_version += "." + match.group(2)
    comp_version += "." + match.group(3)
    comp_version += "." + match.group(4)
    debug("version = {}".format(comp_version))



    debug(f"build_dir = {build_dir}")
    p = Path(component_name)
    family_name = p.parent.name
    component_name =  p.name


    
    debug("component_name = {}".format(component_name))
    debug("family_name = {}".format(family_name))
    artifact = Component(family_name, component_name, comp_version, user_id)

    if repo_type is not None:
        debug(f'repo_type {repo_type}')
        artifact.SetRepository(repo_type)
    else:
        repo_type = artifact.repo_type
    existing = artifact.FindAllVersions()
    ###################################################
    # If we are saving to the developer repo and we   #
    # found an item in another repo, or we are saving #
    # the component in a non-developer repo, cause a  #
    # duplicate artifact exception.                   #
    ###################################################
    if len(existing) > 0:
        for vs, rp, exp in existing:
            if repo_type != ArtifactRepos.DEVELOPER or rp != repo_type:
                raise DuplicateArtifactException(str(rp))

    info("repo set to {}".format(artifact.repo_type))

    #####################################################
    # save the distributable files that will go into    #
    # the packages                                      #
    #####################################################
#        if "BUILD_URL" in os.environ:
#            source_url = "Jenkins: " + os.environ["BUILD_URL"]
#        else:
    source_url = "User: " + getpass.getuser()

    property_map = {'state': artifact.states.developer if developer else artifact.states.incremental,
                    VERSION_PROPERTY_NAME: comp_version,
                    SOURCE_PROPERTY_NAME: source_url,
                    FILE_TYPE_PROPERTY_NAME: str(ArtifactTypes.component),
                    }

    ########################################
    # Create the Release Files folder area #
    ########################################
    # FPGA team doesn't include this cruft
    #artifact.InitializeReleaseFolders()
    
    file_list = get_all_files(commit_distributable_dir)
    # count elements in path and trim them away
    keep_commit_path = count_path_elements(commit_distributable_dir)

    print(commit_distributable_dir)
    print(keep_commit_path)
    

    debug("commit_distributables = {}".format(file_list))    
    for fn in file_list:
        if not fn == '':
            debug("distributable raw fn = {}".format(fn))

            pathname = os.path.join(build_dir, fn.strip())
            debug("distributable pathname = {}".format(pathname))
            flist = glob.glob(pathname)
            debug("flist = {}".format(flist))
            if len(flist) > 0:
                for fn in flist:
                    debug("exec fn = {}".format(fn))
                    if os.path.isfile(fn):
                        artifact.PushDistributableFile(fn, property_map, keep_commit_path)
    
    ###################################################
    # Next save the meta files that are for reference #
    ###################################################    
    file_list = get_all_files(commit_meta_dir)
    debug("commit_meta = {}".format(file_list))    
    for fn in file_list:
        if not fn == '':
            debug("meta  raw fn = {}".format(fn))
            pathname = os.path.join(build_dir, fn.strip())
            flist = glob.glob(pathname)
            debug("flist = {}".format(flist))
            if len(flist) > 0:
                for fn in flist:
                    debug("meta fn = {}".format(fn))
                    if os.path.isfile(fn):
                        artifact.PushMetaFile(fn, property_map, keep_commit_path)

    ################################
    # Next save the release files  #
    ################################
    # todo: we don't do release notes. Maybe we should in the future?    
    # commit_release = ""
    # file_list = commit_release.split(',')
    # debug("commit_release = {}".format(commit_release))
    # for fn in file_list:
    #     if not fn == '':
    #         debug("release  raw fn = {}".format(fn))
    #         pathname = os.path.join(build_dir, fn.strip())
    #         flist = glob.glob(pathname)
    #         debug("flist = {}".format(flist))
    #         if len(flist) > 0:
    #             for fn in flist:
    #                 debug("release fn = {}".format(fn))
    #                 if os.path.isfile(fn):
    #                     artifact.PushReleaseNote(fn, property_map)


    artifact.SetProperties(property_map)

    print("Artifact URL: {}".format(artifact.Url()))

    return ErrorCodes.SUCCESS

if __name__ == "__main__":
    # if called as top level, configure root logger
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(message)s",
        filename="log.txt",   # send to a file instead of stderr
    )

    exit_val = main()
    sys.exit(exit_val)
