#################################################################################
##
## bash.py
##  To run bash commands from python and stop on error
##  Useful when you know the bash command but are working in python.
##  Eventually commands that can be run natively in python can be replaced
##  But some things are better in bash
##
##  Nicholas Dietz
## 
#################################################################################
import os
import subprocess
import shlex

import logging
# give this module its own logger, tied to its namespace.
# This will inherit the output location of the module that calls this
log = logging.getLogger(__name__) 

# https://stackoverflow.com/questions/4256107/running-bash-commands-in-python/51950538
def bash(cmd, log_level="debug"):
    # https://stackoverflow.com/questions/3503719/emulating-bash-source-in-python
    log.info(f'Runinng bash command: {cmd}')
    if "'" in cmd:
        log.warning("warning: apostrophe's might cause trouble")
    bashCommand = f"env bash -c '{cmd}'"
    bashCommand = shlex.split(bashCommand)
    #bashCommand = "cwm --rdf test.rdf --ntriples > test.nt"
    log.info(bashCommand)
    # pipe stderr to stdout so we don't miss error messages
    process = subprocess.Popen(bashCommand, stderr=subprocess.STDOUT, stdout=subprocess.PIPE, universal_newlines=True)

    # https://stackoverflow.com/questions/4417546/constantly-print-subprocess-output-while-process-is-running
    output = ''
    for stdout_line in iter(process.stdout.readline, ""):
        log.info(stdout_line)

        log_msg = "    "+stdout_line.strip()
        if(log_level.lower() == "info"):
            log.info(log_msg)
        else: # default use debug
            log.debug(log_msg)

        output = output + stdout_line
    process.stdout.close()
    return_code = process.wait()
    if return_code:
        #raise subprocess.CalledProcessError(return_code, cmd)
        raise ValueError(f"Bash command failed {cmd}: {output}")
    return output

def bash_quiet(cmd, log_level="debug"):
    # https://stackoverflow.com/questions/3503719/emulating-bash-source-in-python
    bashCommand = f"env bash -c '{cmd}'"
    bashCommand = shlex.split(bashCommand)
    #bashCommand = "cwm --rdf test.rdf --ntriples > test.nt"
    # pipe stderr to stdout so we don't miss error messages
    process = subprocess.Popen(bashCommand, stderr=subprocess.STDOUT, stdout=subprocess.PIPE, universal_newlines=True)

    # https://stackoverflow.com/questions/4417546/constantly-print-subprocess-output-while-process-is-running
    output = ''
    for stdout_line in iter(process.stdout.readline, ""):
        log_msg = "    "+stdout_line.strip()
        if(log_level.lower() == "info"):
            log.info(log_msg)
        else: # default use debug
            log.debug(log_msg)

        output = output + stdout_line
    process.stdout.close()
    return_code = process.wait()
    if return_code:
        #raise subprocess.CalledProcessError(return_code, cmd)
    #    print(output)
        raise ValueError(f"Bash command failed {cmd}: {output}")
    return output


# https://stackoverflow.com/questions/4256107/running-bash-commands-in-python/51950538
def bash_disown(cmd):
    # run command and let it go on running after python exits
    # https://stackoverflow.com/questions/3503719/emulating-bash-source-in-python
    # https://stackoverflow.com/questions/6011235/run-a-program-from-python-and-have-it-continue-to-run-after-the-script-is-kille
    print('ok')
    print(f'Runinng bash command: {cmd}')
    bashCommand = f"env bash -c 'nohup {cmd}'"
    bashCommand = shlex.split(bashCommand)

    #setpgrp used to let xdg-open not kill the pdf viewer
    process = subprocess.Popen(bashCommand, stderr=subprocess.PIPE, stdout=subprocess.PIPE,
                               universal_newlines=True, preexec_fn=os.setpgrp)
    print('done with bash')


# https://stackoverflow.com/questions/4256107/running-bash-commands-in-python/51950538
def bash_return_str(cmd):
    # this was a duplicate function
    return bash(cmd)

# https://stackoverflow.com/questions/4256107/running-bash-commands-in-python/51950538
def bash_old(cmd):
    # https://stackoverflow.com/questions/3503719/emulating-bash-source-in-python
    print('ok')
    print(f'Runinng bash command: {cmd}')
    bashCommand = f"env bash -c '{cmd}'"
    bashCommand = shlex.split(bashCommand)
    #bashCommand = "cwm --rdf test.rdf --ntriples > test.nt"    
    process = subprocess.Popen(bashCommand, stderr=subprocess.PIPE, stdout=subprocess.PIPE, universal_newlines=True)

    # https://stackoverflow.com/questions/4417546/constantly-print-subprocess-output-while-process-is-running
    for stdout_line in iter(process.stdout.readline, ""):
        print(stdout_line, end="")
    process.stdout.close()
    return_code = process.wait()
    if return_code:
        #raise subprocess.CalledProcessError(return_code, cmd)
    #    print(output)
        raise ValueError("Bash command failed")


if __name__ == '__main__':
    bash("ls -alrt")

