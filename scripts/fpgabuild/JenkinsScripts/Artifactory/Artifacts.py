#!/usr/bin/python3

###############################################################
# The Artifacts module provides the functionality to store    #
# build artifacts in the form of packages and components      #
# into Artifactory.                                           #
#                                                             #
# Each Artifact can comprise of one or more files. The        #
# Artifact has a name, a family name which represents the     #
# product line, and a version.                                #
#                                                             #
# An Artifact can be of the type component or packages. These #
# types are defined by the enum ArtifactTypes.                #
#                                                             #
# Each file of an Artifact falls into the the class of a meta #
# file or a distributable. The classes are defined with the   #
# enum ArtifactClass.                                         #
###############################################################

from enum import Enum
import getpass
import json
from logging import critical, error, info, warning, debug
import logging
import os
import re
import sys
from time import sleep

from base64 import b64encode
from requests import Session

FILE_CLASS_PROPERTY_NAME            = "class"
FILE_TYPE_PROPERTY_NAME             = "type"
REFERENCED_BY_PROPERTY_NAME         = "referenced-by"
REFERENCES_COMPONENTS_PROPERTY_NAME = "components"
FAMILY_PROPERTY_NAME                = "family"
PACKAGE_PROPERTY_NAME               = "package"
USERNAME_PROPERTY_NAME              = "username"
VERSION_PROPERTY_NAME               = "version"
SOURCE_PROPERTY_NAME                = "source"
STATE_PROPERTY_NAME                 = "state"
REPO_PATH_DEFINITION_NAME           = "repo-path-def"

RELEASE_FILES_PATH                  = "ReleaseFiles"
RELEASE_NOTES_PATH                  = "{}/ReleaseNotes".format(RELEASE_FILES_PATH)
SYS_VERIFICATION_PATH               = "{}/SysVerification".format(RELEASE_FILES_PATH)
BUILD_FILES_PATH                    = "{}/BuildFiles".format(RELEASE_FILES_PATH)

FILE_CLASS_META = "meta-data"
FILE_CLASS_DIST = "distributable"

LEADING_SLASH_RE = re.compile("^/")
TRAILING_SLASH_RE = re.compile("/$")

MAX_RETRY_COUNT =   2
RETRY_DELAY     =   10

class ArtifactException(Exception):
    def __init__(self, message):
        super().__init__(message)

class DuplicateArtifactException(ArtifactException):
    def __init__(self, repo):
        self.message = "Artifact already exists in repository: " + repo
        super().__init__(self.message)

    def str(self):
        return self.message

class ArtifactoryErrorResponseException(ArtifactException):
    def __init__(self, response):
        self.message = response.text
        super().__init__(self.message)

    def str(self):
        return self.message


class ArtifactTypes(Enum):
    component = 0
    package = 1


class ArtifactClass(Enum):
    meta = 0
    distributable = 1


class ArtifactStates(Enum):
    incremental         = 0
    rejected            = 1
    promoted            = 2
    release_candidate   = 3
    release_ate         = 4
    release_customer    = 5
    discontinued        = 6
    end_of_life         = 7
    developer           = 8

class ArtifactRepos(Enum):
    DEVELOPER   = 0
    CONTINUOUS  = 1
    RELEASE     = 2

    def __hash__(self):
        return id(self)

    def __lt__(self, other):
        if self.value < other.value:
            return True
        else:
            return False

    def __eq__(self, other):
        if self.value == other.value:
            return True
        else:
            return False

    def __gt__(self, other):
        if self.value > other.value:
            return True
        else:
            return False

    def __le__(self, other):
        if self.value <= other.value:
            return True
        else:
            return False

    def __ge__(self, other):
        if self.value >= other.value:
            return True
        else:
            return False

COMPONENT_REPOS = \
{
    ArtifactRepos.RELEASE:      'Release_Components',
    ArtifactRepos.DEVELOPER:    'Developer_Components',
    ArtifactRepos.CONTINUOUS:   'CI_Components',
}

#PACKAGE_REPOS = \
#{
#    ArtifactRepos.RELEASE:      'Release_Packages',
#    ArtifactRepos.DEVELOPER:    'Developer_Packages',
#    ArtifactRepos.CONTINUOUS:   'CI_Packages',
#}

class Version(object):
    def __init__(self, version):
        self.version = version
        va = version.split(".")
        self.major = int(va[0])
        self.minor = int(va[1])
        self.patch = int(va[2])
        self.build = int(va[3])

    def __str__(self):
        return("{}.{}.{}.{}".format(self.major, self.minor, self.patch, self.build))

    def __lt__(self, other):
        if (self.major < other.major):
            return(True)
        elif (self.major == other.major):
            if (self.minor < other.minor):
                return(True)
            elif (self.minor == other.minor):
                if (self.patch < other.patch):
                    return(True)
                elif (self.patch == other.patch):
                    if (self.build < other.build):
                        return(True)
        return(False)



#########################################################
# Base Class both Component and Package (or any future  #
# type) Artifacts                                       #
#########################################################
class Artifact(object):
    types = ArtifactTypes
    classes = ArtifactClass
    states = ArtifactStates
    repos = ArtifactRepos
    url = "https://artifactory.shure.com/"

    ##
    #  __init__
    # Creates a new instance of an Artifact
    #
    # @param self The instance variable
    # @param artifact_type One of the enum values from ArtifactTypes
    # @param family_name   The product line name of the Artifact
    # @param artifact_name The name of the component or package name of the Artifact itself
    # @param version The version string in the form of 9.9.9.9
    #
    def __init__(self, artifact_type, family_name, artifact_name, version, username, path_template):
        debug("Artifacts.init(): type = {}, artifact = {}/{}-{}".format(artifact_type, family_name, artifact_name, version))
        self.max_retry_count = MAX_RETRY_COUNT
        self.retry_delay = RETRY_DELAY
        self.full_path_template = path_template
        self.artifact_type = artifact_type
        self.family_name = family_name
        self.artifact_name = artifact_name
        self.username = username
        self.version = version
        self.SetRepository(ArtifactRepos.DEVELOPER)
        vers = self.version.split('.')
        self.build_number = "{}.{}.{}.X".format(vers[0], vers[1], vers[2])
        self.regular_path_template = self.full_path_template.replace('%B/', '')
        self.path_template = self.regular_path_template
        self.use_extended_paths = False
        repo_vers = self.FindAllVersions()
        debug("Artifacts.init(): repo_vers: {}".format(repo_vers))
        if len(repo_vers) == 1:
            vers = repo_vers[0][0]
            repo = repo_vers[0][1]
            exp = repo_vers[0][2]
            debug("Artifacts.init(): Found vers {} in repo {}".format(vers, repo))
            self.SetRepository(repo)
            if exp:
                self.SetExtendedPaths()
        self.password = None


    ###########################################################
    # This function will return a Component or Package object #
    # for the artifact referenced by the url passed in.       #
    #                                                         #
    #  If the url is invalid an appropriate exception will    #
    #  be thrown and a value of None will be returned.        #
    ###########################################################
    def CreateArtifactFromUrl(url):
        rv = None
        properties = {}
        sess = Session()


    def __substitute_path_components(self, path_template, artifact=''):
        rv = self.repo + '/' + path_template
        rv = rv.replace("%U", self.username)
        rv = rv.replace("%P", self.artifact_name)
        rv = rv.replace("%F", self.family_name)
        rv = rv.replace("%A", artifact)
        rv = rv.replace("%V", self.version)
        rv = rv.replace("%B", self.build_number)
        return(rv)

    ##########################################################
    # Build the url for the artifact substituting the path   #
    # components. We have to search for both the regular and #
    # extended paths for already existing artifacts. There   #
    # should only ever be a single artifact for a given      #
    # family, component and version.                         #
    #                                                        #
    # Return the path name of the existing artifact or the   #
    # path to use to create a new artifact.                  #
    ##########################################################
    def __build_full_artifact_name(self, artifact = ''):
        rv = None
        info("__build_full_artifact_name(): fetching path templates")
        rpt = self.regular_path_template
        info("__build_full_artifact_name(): rpt: {}".format(rpt))
        reg_rv = self.__substitute_path_components(self.regular_path_template, artifact)
        ext_rv = self.__substitute_path_components(self.full_path_template, artifact)
        info("__build_full_artifact_name(): testing regular path {}".format(reg_rv))
        if self.__folder_exists(reg_rv):
            info("__build_full_artifact_name(): found regular path {}".format(reg_rv))
            rv = reg_rv
        else:
            info("__build_full_artifact_name(): testing extended path {}".format(ext_rv))
            if self.__folder_exists(ext_rv):
                info("__build_full_artifact_name(): found extended path {}".format(ext_rv))
                rv = ext_rv

        ######################################################
        # If the path does not already exist, use the        #
        # preferred path indicated by the use_extended_paths #
        # flag                                               #
        ######################################################
        if not rv:
            info("__build_full_artifact_name(): Path does not exist, choose the correct pathname, use_extended_paths = {}".format(self.use_extended_paths))
            if self.use_extended_paths:
                rv = ext_rv
            else:
                rv = reg_rv
        info("__build_full_artifact_name(): rv = {}".format(rv))
        return rv

    ###########################################################
    # This function will prepend the family name onto each of #
    # the names in art_names if it is not already present.    #
    #                                                         #
    # This function will return the adjusted list of names.   #
    ###########################################################
#    def __adjust_artifact_names__(self, comp_names):
#        names = []
#        for name in comp_names:
#            if '::' not in  name:
#                names.append(self.Family() + '::' + name)
#            else:
#                names.append(name)
#        return(names)

    def Url(self):
        rv = self.url + self.__build_full_artifact_name()
        debug("url: {}".format(rv))
        return(rv)

 #   def get_login(self, no_headers = False):
 #       return(Artifact.__get_login(self, no_headers))

    ###########################################################
    # This function will return the login credentials needed  #
    # for accessing artifactory from one os several sources.  #
    #                                                         #
    # If the credentials have not already been saved in the   #
    # credentials variable of the object, the presence of     #
    # environment variables ARTIFACTORY_KEY, CREDENTIALS,     #
    # UN/PW will be tested for in the oder listed. If none    #
    # of these variables exist in the environment, the user   #
    # will be queried to enter them in through stdin.         #
    #                                                         #
    # If no_headers is False, the appropriate headers will    #
    # be saved in the object. In any case, the user name      #
    # and password will be returned in a two element array.   #
    ###########################################################
    def __get_login(self, no_headers = False):
        try:
            username, password = self.credentials.split(":")
        except Exception:
            if "ARTIFACTORY_KEY" in os.environ:
#                debug("Have ARTIFACTORY_KEY")
                cred = os.environ["ARTIFACTORY_KEY"]
                username, password = cred.split(":", 1)
#                debug("un = {}, pw = {}".format(username, password))
            elif "CREDENTIALS" in os.environ:
#                debug("Have CREDENTIALS")
                cred = os.environ["CREDENTIALS"]
                username, password = cred.split(":", 1)
#                debug("un = {}, pw = {}".format(username, password))
            elif "UN" in os.environ and "PW" in os.environ:
                debug("Have UN & PW")
                username = os.environ["UN"]
                password = os.environ["PW"]
#                debug("un = {}, pw = {}".format(username, password))
            elif self.password is not None:
                username = self.username
                password = self.password
            else:
                try:
                    username = input("Username: ")
                    password = getpass.getpass("Password: ")
                except KeyboardInterrupt:
                    sys.exit(0)
#        debug("2:un = {}, pw = {}".format(username, password))
        debug("no_headers = {}".format(no_headers))
        if not no_headers:
            if len(username) > 0:
                psw = bytes(username + ":" + password, 'utf-8')
    #            debug("psw: {}".format(psw))
                pswenc = b64encode(psw)
    #            debug("pswenc: {}".format(pswenc))
                self.headers = {"Authorization" : "Basic " + pswenc.decode('ascii')}
            else:
                self.headers = {"X-JFrog-Art-Api" : password}
            debug("self.headers = {}".format(self.headers))
        # cache password to avoid repeated prompts
        self.username = username
        self.password = password
        return username, password

    #########################################################
    # This function will convert backslashes to forward and #
    # remove trim_count folder names from the beginning of   #
    # the path                                              #
    #########################################################
    def __adjust_path__(self, path, trim_count):
        norm_path = os.path.normpath(path)        
        if trim_count > 0:
            parts = norm_path.split(os.sep, maxsplit=trim_count)
            path = parts[-1]
        else:
            path = norm_path
        return path
    
    def __adjust_path__orig(self, path, trim_count):
        path = path.replace("\\", "/")
        paths = path.split("/", trim_count)
        debug("__adjust_path__: paths = {}".format(paths))
        return(paths[len(paths) - 1])


    def __AddDefaultProperties(self, property_map):
        if FAMILY_PROPERTY_NAME not in property_map:
            property_map[FAMILY_PROPERTY_NAME] = self.family_name
        if PACKAGE_PROPERTY_NAME not in property_map:
            property_map[PACKAGE_PROPERTY_NAME] = self.artifact_name
        if VERSION_PROPERTY_NAME not in property_map:
            property_map[VERSION_PROPERTY_NAME] = self.version
        if USERNAME_PROPERTY_NAME not in property_map:
            property_map[USERNAME_PROPERTY_NAME] = self.username

     ###########################################################
    # This function attempts to access the passed in url. If  #
    # it does not get an error, it is assumed that the url is #
    # valid and returns True, Otherwise a False is returned.  #
    #                                                         #
    # On entry any trailing '%A' will be truncated from the   #
    # url before the access is attempted.                     #
    #                                                         #
    # The purpose of this function is to facilitate           #
    # determining if a folder path exists on the Artifactory  #
    # server, though in reality, it can be used to test the   #
    # existence of any url.                                   #
    #                                                         #
    # If the response is any form of an error, the folder     #
    # will be assumed to not exist. This includes bad         #
    # servers, malformed URLs etc                             #
    ###########################################################
    def __folder_exists(self, url):
        rv = True
        sess = Session()
        url = url.replace('%A', '')
        url = url.replace('%B/', '')
        url = self.url + 'api/storage/' + url
        local_url = url
        info("__folder_exists(): url = {}".format(local_url))
#        print("__folder_exists(): url = {}".format(local_url))
        (user, passwd) = self.__get_login()
        retry_count = self.max_retry_count
        response = None
        while retry_count > 0:
#            response = sess.get(local_url, auth=(user, passwd))
            response = sess.get(local_url, headers = self.headers)
            if  response.status_code == 403 or \
                response.status_code == 404 or \
               (200 <= response.status_code < 300):
                info(f"response code {response.status_code}")
                retry_count = 0
            else:
                info("Waiting {} seconds before retrying Artifactory operation".format(self.retry_delay))
                sleep(self.retry_delay)
                retry_count -= 1
        sess.close()
        info("reponse = {}".format(response))
        if response.status_code >= 300:
            rv = False
        info("rv = {}".format(rv))
        return(rv)


    #########################################################
    # This Member function, though complete, the feature it #
    # is implementing is not!!! Whoever wrote this needs to explain it or remove it!
    #########################################################
    def SetRepository(self, repo_type):
        # unconditionally set repo type
        debug("SetRepository(): request to set repo to {}".format(repo_type))
        # what is the motivation of this check? Why not error out if it is wrong?
        # Shouldn't this check all members of CONMPONENT_REPOS instead of this chain of or's?
        if (repo_type == ArtifactRepos.CONTINUOUS or
           repo_type == ArtifactRepos.DEVELOPER or
           repo_type == ArtifactRepos.RELEASE):
#            if self.artifact_type == Artifact.types.component:
            self.repo = COMPONENT_REPOS[repo_type]
#            else:
#                self.repo = PACKAGE_REPOS[repo_type]
            debug("SetRepository(): Setting repo to {}".format(repo_type))
            self.repo_type = repo_type
        else:
            raise ValueError(f"Unhandled repo type {repo_type}")
        debug("SetRepository(): repository_name: {}".format(self.GetRepositoryName()))

    ########################################################
    # This function returns the name of the repository the #
    # artifact does or will reside in                      #
    ########################################################
    def GetRepositoryName(self):
        return(self.repo)

 
     ###########################################################
    # __TestResponse                                          #
    #                                                         #
    # This function tests the response from an http requests, #
    # if it has an error code >= 400 it returns False,        #
    # otherwise it returns True                               #
    ###########################################################
    def __TestResponse(self, response):
        rv = True
        if response.status_code >= 400:
            rv = False
        return(rv)

    ##
    # PushArtifact
    # Pushes an artifact file out to Artifactory. It can also set properties
    # for the artifact as well.
    #
    # @param self The instance variable
    # @param artifact_file The name of the file to save
    # @param artifact_class ArtifactClass enum denoting the class type
    # @param destination_name The base name to save the file under in Artifactory
    # @param property_map A dictionary of properties to set
    #
    # Exceptions:
    #   ArtifactNameError(name) raised if the artifact_name is malformed.
    #
    def PushArtifact(self, artifact_file, file_class, destination_name, property_map):
        debug("*** artifact_file = {}, artifact_type = {}, dest = {}".format(artifact_file, self.artifact_type, destination_name))
        with open(artifact_file, mode='rb') as packfile:
            artifact_contents = packfile.read()

        self.PushArtifactData(artifact_contents, file_class, destination_name, property_map)

    #########################################################
    # PushArtifactData                                      #
    #                                                       #
    # Same functionality and arguments as PushArtifact      #
    # except that instead of reading the artifact, its data #
    # is passed in through the parameter artifact_data.     #
    #########################################################
    def PushArtifactData(self, artifact_data, file_class, destination_name, property_map):
        debug("artifact_name = {}".format(self.artifact_name))
        debug("property_map = {}".format(property_map))

        full_name = self.__build_full_artifact_name(destination_name)
        sess = Session()
        local_url = self.url + full_name
        debug("local_url = {}".format(local_url))

        self.__AddDefaultProperties(property_map)
        for prop in property_map:
            debug("Artifact.PushArtifact() - property[{}] =  {}".format(prop, property_map[prop]))
            local_url = local_url + ';' + prop + '=' + str(property_map[prop]).replace('%', '%25')
        if FILE_CLASS_PROPERTY_NAME not in property_map:
            local_url = local_url + ';' + FILE_CLASS_PROPERTY_NAME + '=' + str(file_class).replace('%', '%25')
        if FILE_TYPE_PROPERTY_NAME not in property_map:
            local_url = local_url + ';' + FILE_TYPE_PROPERTY_NAME + '=' + str(self.artifact_type).replace('%', '%25')
        if REPO_PATH_DEFINITION_NAME not in property_map:
            local_url = local_url + ';' + REPO_PATH_DEFINITION_NAME + '=' + str(self.path_template).replace('%', '%25')

        debug("Artifact.PushArtifact() - url = {}".format(local_url))
        self.__get_login()
        retry_count = self.max_retry_count
        response = None
        while retry_count > 0:
            response = sess.put(local_url, data=artifact_data, headers = self.headers)
            debug("resp = {}".format(response))
            if  response.status_code == 403 or \
                response.status_code == 404 or \
               (200 <= response.status_code < 300):
                retry_count = 0
            else:
                info("Waiting {} seconds before retrying Artifactory operation".format(self.retry_delay))
                sleep(self.retry_delay)
                retry_count -= 1
        sess.close()
        if not self.__TestResponse(response):
            raise ArtifactoryErrorResponseException(response)
        debug("resp = {}".format(response))

    ######################################################
    # This member function saves the file named by fn to #
    # Artifactory as a meta file for the Package         #
    ######################################################
    def PushMetaFile(self, fn, property_map, trim_count = None):
        debug("Artifact.PushMetaFile() - trim_count = {}".format(trim_count))
        if trim_count is None:
            base_name = os.path.basename(fn)
        else:
            base_name = self.__adjust_path__(fn, trim_count)
        debug("Artifact.PushMetaFile() - base_name = {}".format(base_name))
        self.PushArtifact(fn, Artifact.classes.meta, base_name, property_map)

    ########################################################
    # This member function saves the file named by fn as a #
    # distributable file for the Package                   #
    ########################################################
    def PushDistributableFile(self, fn, property_map, trim_count = None):
        debug("Artifact.PushDistributableFile() - trim_count = {}".format(trim_count))
        if trim_count is None:
            base_name = os.path.basename(fn)
        else:
            base_name = self.__adjust_path__(fn, trim_count)
        debug("Artifact.PushDistributableFile() - base_name = {}".format(base_name))
        self.PushArtifact(fn, Artifact.classes.distributable, base_name, property_map)


    def SetProperties(self, property_map, file_name='', recursive=True):
        prop_str = ''
        pv = ''
        for prop in property_map:
            pv = property_map[prop]
            debug("Artifact.SetProperties() - property[{}] =  {}".format(prop, pv))
            if isinstance(property_map[prop], Enum):
                pv = property_map[prop].name
            else:
                pv = property_map[prop]
            if len(prop_str) > 0:
                prop_str += ';'
            prop_str += prop + '=' + pv

        #if recursive:
        recurse_option = "1"
        #else:
        #    recurse_option = "0"
        sess = Session()
        prop_str = prop_str.replace('%', '%25')
        full_name = self.__build_full_artifact_name(file_name)
        local_url = self.url + 'api/storage/' + full_name + "?properties=" + \
                    prop_str + "&recursive=" + recurse_option
        debug("Artifact.SetProperties() - url = {}".format(local_url))
        self.__get_login()
        retry_count = self.max_retry_count
        response = None
        while retry_count > 0:
            response = sess.put(local_url, headers = self.headers)
            debug("resp = {}".format(response))
            if  response.status_code == 403 or \
                response.status_code == 404 or \
               (200 <= response.status_code < 300):
                retry_count = 0
            else:
                info("Waiting {} seconds before retrying Artifactory operation".format(self.retry_delay))
                sleep(self.retry_delay)
                retry_count -= 1
        sess.close()
        if not self.__TestResponse(response):
            raise ArtifactoryErrorResponseException(response)
        return


    #########################################################
    # This function will return a list of tuples each       #
    # representing the version and repository of the        #
    # component which is found in the repository.           #
    # 
    # This can be used to check for duplicate version
    # numbers. It checks RELEASE, CONTINUOUS, and
    # DEVELOPMENT. Too much process in my opinion.
    #                                                       #
    # If the version is not listed, all versions for the    #
    # component are returned, otherwise, only the specific  #
    # version will be returned. This effectively provides   #
    # a simple test for the existence of a specific version #
    # of a component,                                       #
    #                                                       #
    # If filename is provided, the named file must exist in #
    # the component to be included in the list.             #
    #                                                       #
    # Version must be defined  in the artifact for this     #
    # function to work with Package objects                 #
    #                                                       #
    #########################################################
    def FindAllVersions(self, filename = ''):
        intermediate = []
        rv = []
        repo_map = COMPONENT_REPOS if self.artifact_type == Artifact.types.component else PACKAGE_REPOS
        repo_save = self.repo_type
        # even though we never want to commit artifacts to release,
        # we do need to be able to check for duplicate version numbers there
        self.SetRepository(ArtifactRepos.RELEASE)
        try:
            ainfo = self.FetchArtifactInfo()
            exp = ainfo["extended_path"]
            if self.version == '':
                intermediate.extend(self._parse_versions(ainfo))
            else:
                for repo_key in repo_map.keys():
                    if repo_map[repo_key] == self.repo:
                        repo = repo_key
                intermediate.append((self.version, repo, exp))
        except Exception as e:
            debug("FindAllVersions: Exception: {}".format(e))

        self.SetRepository(ArtifactRepos.CONTINUOUS)
        try:
            ainfo = self.FetchArtifactInfo()
            exp = ainfo["extended_path"]
            if self.version == '':
                intermediate.extend(self._parse_versions(ainfo))
            else:
                for repo_key in repo_map.keys():
                    if repo_map[repo_key] == self.repo:
                        repo = repo_key
                intermediate.append((self.version, repo, exp))
        except Exception as e:
            debug("FindAllVersions.1: Exception: {}".format(e))

        self.SetRepository(ArtifactRepos.DEVELOPER)
        try:
            ainfo = self.FetchArtifactInfo()
            exp = ainfo["extended_path"]
            if self.version == '':
                intermediate.extend(self._parse_versions(ainfo))
            else:
                for repo_key in repo_map.keys():
                    if repo_map[repo_key] == self.repo:
                        repo = repo_key
                intermediate.append((self.version, repo, exp))
        except Exception as e:
            debug("FindAllVersions.2: Exception: {}".format(e))

        debug("FindAllVersions.3: |{}|".format(intermediate))
        for tup in intermediate:
            vers = tup[0]
            repo = tup[1]
            exp  = tup[2]
            ainfo = None
            debug("FindAllVersions(): ver: {}, repo: {}, filename = {}".format(vers, repo, filename))
            if filename != "":
                try:
                    test_artifact = Component(self.family_name, self.artifact_name, vers) \
                        if self.artifact_type == Artifact.types.component \
                        else Package(self.family_name, self.artifact_name, vers)
                    debug("FindAllVersions(): setting test_artifact repo to: {}".format(repo))
                    test_artifact.SetRepository(repo)
                    ainfo = test_artifact.FetchArtifactInfo(filename)
                    exp = ainfo["extended_path"]
                    debug("ainfo = {}".format(ainfo))
                    rv.append((vers, repo, exp))
                except Exception as e:
                    debug("FindAllVersions.4: Exception: {}".format(e))
            else:
                rv.append((vers, repo, exp))
        debug("FindAllVersions: Setting repo to {}".format(repo_save))
        self.SetRepository(repo_save)
        debug("FindAllVersions: rv = {}".format(rv))
        return(rv)


    ###################################################
    # This function is not described
    ###################################################

    def FetchArtifactInfo(self, artifact_name = ''):
        sess = Session()
        rpt = self.regular_path_template
        info("FetchArtifactInfo(): rpt: {}".format(rpt))
        full_name = self.__build_full_artifact_name(artifact_name)
        debug("FetchArtifactInfo(): full_name = {}".format(full_name))
        local_url = self.url + 'api/storage/' + full_name
        debug("url = {}".format(local_url))
        self.__get_login()
        retry_count = self.max_retry_count
        response = None
        while retry_count > 0:
            response = sess.get(local_url, headers = self.headers)
            debug("resp = {}".format(response))
            if 200 <= response.status_code < 300 or \
               response.status_code == 403 or \
               response.status_code == 404:
                debug("resp = {}".format(response))
                retry_count = 0
            else:
                info("Waiting {} seconds before retrying Artifactory operation".format(self.retry_delay))
                sleep(self.retry_delay)
                retry_count -= 1
        sess.close()
        if not self.__TestResponse(response):
            raise ArtifactoryErrorResponseException(response)
        rmap = json.JSONDecoder().decode(str(response.text))
        debug("FetchArtifactInfo(): Adding extended_path, build_number = {}".format(self.build_number))
        if self.build_number in full_name:
            rmap['extended_path'] = True
        else:
            rmap['extended_path'] = False
        debug("FetchArtifactInfo(): resp = {}, type: {}".format(response.json(), str(response.text)))
        debug("FetchArtifactInfo(): rmap: {}".format(rmap))
        return rmap


###########################################################
# this class encapsulates the special needs for artifacts #
# that are components                                     #
###########################################################
class Component(Artifact):
    #########################################################
    # on creation both the family name, ei. axient, and the #
    # component name and version must be provided.          #
    #########################################################
    def __init__(self, family_name, package_name, version, username = getpass.getuser()):
        super().__init__(Artifact.types.component, family_name, package_name, version, username, "%F/%P/%B/%V/%A")

