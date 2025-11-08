#!/usr/bin/python3

from buildenv import BuildEnv, chomp
import qc.shell.jenkins.customization_lists
import getpass
import glob
from jira import JIRA
import os
import re
import sys

JIRA_URL    = "http://jira.shure.com/"
#JIRA_URL    = "http://vm-jira.shure.com:8080/"
#JIRA_URL    = "http://pcnicroftj02.shure.com:8080/"
QCALM       = "http://...."
VERSION_RE = re.compile(".*?([0-9]+[-._][0-9]+[-._][0-9]+[-._][0-9]+)", re.I)
RN_VERS_RE = re.compile("^([0-9]+[-._][0-9]+[-._][0-9]+[-._][0-9]+)$", re.I)
JIRA_ISSUE_RE   = re.compile('([A-Z]+-.*?)\s+-\s+.*')

Username = ''
Password = ''

def GetCredentials():
    try:
        cred = os.environ["CREDENTIALS"]
        username, password = cred.split(":", 1)

    except Exception as e:
        try:
            username = os.environ["UN"]
            password = os.environ["PW"]

        except Exception as e:
            try:
                username = input("Username: ")
                password = getpass.getpass("Password: ")
            except KeyboardInterrupt as e:
                sys.exit(0)
    return username, password


class Unbuffered(object):
   def __init__(self, stream):
       self.stream = stream
   def write(self, data):
       self.stream.write(data)
       self.stream.flush()
   def __getattr__(self, attr):
       return getattr(self.stream, attr)



def GetJiraIssues(rel_notes, version):
    line_cnt = 0
    in_version = False
    check_version = False
    rn_version = ''
    rv = []

    if len(rel_notes) > 0:
        with open(rel_notes, 'r', encoding="UTF-8") as fd:
            for line in fd:
                line = chomp(line)
                print("** |{}|".format(line))
                if in_version == False:
                    match = RN_VERS_RE.search(line)
                    if match:
                        rn_version = match.group(1)
                        print("Have version: {}".format(rn_version))
                        if version == rn_version:
                            in_version = True
                else:
                    if line.startswith("==========="):
                        line_cnt += 1
                        if line_cnt == 2:
                            break

                    match = JIRA_ISSUE_RE.search(line)
                    if match:
                        issue_list = []
                        issues = match.group(1)
                        print("found issues: {}".format(issues))
                        if ',' in issues:
                            issue_list = issues.split(',')
                        elif ' ' in issues:
                            issue_list = issues.split(' ')
                        else:
                            issue_list.append(issues)
                        (prefix, num) = issue_list[0].split('-')
                        for issue in issue_list:
                            if prefix not in issue:
                                issue = prefix + "-" + issue
                            print("issue = {}".format(issue))
                            rv.append(issue)
        for issue in sorted(rv):
            print("issue {}".format(issue))
    return(sorted(rv))

if __name__ == "__main__":
    sys.stdout = Unbuffered(sys.stdout)
    credentials     = ''
    rel_notes       = ''
    config_fn       = ''
    build_version   = ''
    jira_project    = ''
    qc_project      = ''
    qc_domain       = ''

    Username, Password = GetCredentials()
    if "CONFIG" in os.environ:
        config_fn       = os.environ["CONFIG"]
    if "BUILD_VERSION" in os.environ:
        build_version   = os.environ["BUILD_VERSION"]

    ########################################################
    # Start by seeing if they defined a config file on the #
    # command line, if so, read it before processing the   #
    # command line arguments.                              #
    ########################################################
    for arg in sys.argv[1:]:
        if len(arg.split('=')) > 1:
            (cmd, val) = arg.split('=', 2)
            if len(val) > 0:
                if "credentials" in cmd:
                    credentials = val
                elif "release-notes" in cmd:
                    rel_notes = val
                elif "config" in cmd:
                    config_fn = val
    
    ################################################
    # Get the variables defined in the config file #
    ################################################
    if len(config_fn) > 0:
        buildenv = BuildEnv(config_fn)
        env = buildenv.BuildMap()
        if "JIRA_PROJECT" in env:
            jira_project = env["JIRA_PROJECT"]
        if "QC_PROJECT" in env:
            qc_project = env["QC_PROJECT"]
        if "QC_DOMAIN" in env:
            qc_domain = env["QC_DOMAIN"]

    #######################################################
    # Now process the command line arguments, possibly    #
    # overriding the variables defined in the config file #
    #######################################################
    for arg in sys.argv[1:]:
        if len(arg.split('=')) > 1:
            (cmd, val) = arg.split('=', 2)
            if len(val) > 0:
                if "credentials" in cmd:
                    credentials = val
                elif "config" in cmd:
                    config_fn = val
                elif "release-notes" in cmd:
                    rel_notes = val
                elif "build_version" in cmd:
                    build_version = val
                elif "jira_project" in cmd:
                    jira_project = val
                elif "qc_project" in cmd:
                    qc_project = val
                elif "qc_domain" in cmd:
                    qc_domain = val
                else:
                    usage()
            else:
                usage()
        else:
            usage()

    if len(config_fn) == 0 or len(build_version) == 0:
        print("\nThe config filename or build version is missing!\n")
        usage()
    match = VERSION_RE.search(build_version)
    if match:
        version = match.group(1)
        version.replace('_', '.')
    else: 
        print("\nBuild version has incorrect format, Must be <major>_<minor>_<patch>_<build>!\n")
        sys.exit(1)
    qcv = version.split('.')
    qc_version = qcv[0] + '.' + qcv[1] + '.' + qcv[2]
    qc_node = qc_project + "_sys." + qc_version + ".x\\" + version

    env= BuildEnv(config_fn)
    jira_issues = GetJiraIssues(rel_notes, version)

    options = {
        'server': JIRA_URL
    }
    jira = JIRA(options, basic_auth = (Username, Password))
    
    try:
        print("Adding version: {}".format(version))
        jira.create_version(version, jira_project)

    except Exception as e:
        print("Exception: {}".format(e))

    for issue_num in jira_issues:
        is_ready = False
        vers_list = []
        issue = jira.issue(issue_num) # fields='status,fix version/s')
        status = issue.fields.status
        transitions = jira.transitions(issue_num, '5') # Get
        print("issue: {}".format(issue_num))
        print("status: {}".format(status))
        print("fixversion: {}".format(issue.fields.fixVersions))
        vers_list.append({'name': version})
        for fv in issue.fields.fixVersions:
            print("fv name = {}".format(fv.name))
            vers_list.append({'name': fv.name})
        print("status = |{}|".format(status))
        if str(status) == "Resolved" or str(status) == "Closed":
            print("Resolving issue: {}".format(issue_num))
            issue.update(fields={'fixVersions': vers_list})
        print("\n")
#    python -m qc.shell.jenkins.customization_lists --qc_project Olympus --qc_domain Sandbox --node_path "Olympus_sys.4.0.x\4.0.3" --list_id Versions
    print("qc_domain: {}, qc_project: {}, qc_node: {}".format(qc_domain, qc_project, qc_node))
#    python -m qc.shell.jenkins.customization_lists --qc_project Olympus --qc_domain Sandbox --node_path "Olympus_sys.4.0.x\4.0.3" --list_id Versions
    qc.shell.jenkins.customization_lists.add_list_element(qc_domain, qc_project, "Versions", qc_node)


#       issue.update(status = 'Resolved')
#create_version
#project_versions
#add_user
#add_user_to_group

