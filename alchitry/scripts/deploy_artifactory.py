#################################################################################
##
## deploy_artifactory
##
## Alex Stezskal, Nicholas Dietz
##
## I decided not to do any check here. This will deploy whatever is there. If you don't want to deploy, check and fail before you call this script.
##
## run from scripts/deploy_artifactory
##
#################################################################################
from scripts.fpgabuild import fpga_build
import typer
from typing_extensions import Annotated

import logging
# give this module its own logger, tied to its namespace.
# This will inherit the output location of the module that calls this
log = logging.getLogger(__name__) 



# project specific settings:

# why are the developer files targeted to Blackhawk_FPGA/TX_FPGA/AD1_AD2_AD3_ADX3 and others to Blackhawk/TX_FPGA_AD1_AD2_AD3_ADX3?


# no longer including raw bin and bit files here, so we can be certain to always have build/date/time in the header in flash
# all files and subdirectories will be deployed to artifactory as "dist" files
dist_dir = "artifactory/staging/dist/"

# all files and subdirectories will be deployed to artifactory as "meta" files
meta_dir = "artifactory/staging/meta/"


def get_fpga_version(version_file_path = "./par/TX_ver_std.bin"):
    # Read the content of the binary file
    with open(version_file_path, "rb") as file:
        content = file.read(4)

    # Convert the bytes to string and concatenate with periods
    FPGAversion = ".".join([str(byte) for byte in content])
    version = {}
    version["MAJOR"] = content[0]
    version["MINOR"] = content[1]
    version["PATCH"] = content[2]
    version["BUILD"] = content[3]

    return version





def main(
    artifact_component: str, # e.g. "ATLAS/protonpack"
    dist_dir: str = dist_dir,
    meta_dir: str = meta_dir,
    developer: Annotated[
        bool,
        typer.Option(help="Force deploy to the developer repo. Otherwise use CI repo."),
    ] = False,
):
    rtl_version_file="rtl/version_pkg.sv"
    ## instantiate the helper build scripts
    ## This reads the current revision from the rtl version package file
    build = fpga_build.fpga_build(rtl_version_file=rtl_version_file)

    # why is this dist vs meta?
    # answer: https://confluence.shure.com/display/DEVOPS/Common+Tool+Chain+Integration
    # https://confluence.shure.com/display/DEVOPS/Save+Component+Artifacts

    # Push Build artifacts to artifactory
    # Comma separated file lists for dist_files(image) and meta(other)_files

    # deploy under continuous repo only if building in jenkins and not specifying otherwise
    if developer:
        commit_artifactory = build.commit_artifactory_developer_dirs
        print("deploying branch to developer repo")
    else:
        # master/trunk branch, built on jenkins
        commit_artifactory = build.commit_artifactory_dirs       
        print("deploying to continuous repo")

    # Push Build artifacts to artifactory
    # directory names for dist files(e.g. binary image) and meta (e.g. other) files

    status = commit_artifactory(
        artifact_component=artifact_component,
        artifact_dist_dir=dist_dir,
        artifact_meta_dir=meta_dir,
    )


    print("Build version: "+build.get_version()+"  Artifact URL: "+build.get_artifactory_url_all_shure(artifact_component))
    
    return status

    # return exit code on failure
    # do not allow overwrite so easily from the script
    # https://artifactory.shure.com/All_Shure_Components/Wideband/NGPSM_RX/0.4.99.11020211108115230/
    # commit_artifactory should return an error code if it fails. this script should too.


if __name__ == "__main__":
    import typer

    # if called as top level, configure root logger
    logging.basicConfig(
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(message)s",
        filename="log.txt",   # send to a file instead of stderr
    )
    typer.run(main)
