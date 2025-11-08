#!/usr/bin/python3
__author__ = "Palanivel Somasundaram <somasundaram_palani@shure.com>"
__status__ = "PRODUCTION"
__version__ = "1.0.3"

###############################################################################
# This file has been created to collate functions that are common across the  #
# Common ToolChain.                                                           #
###############################################################################
import logging
import sys
from enum import IntEnum

MODULE_NAME = "CMN"
CTC_LOGFRMT = logging.Formatter("%(asctime)s %(name)s %(message)s", datefmt='%H:%M:%S')

###############################################################################
# Logging levels are based on their severity level( where debug being the     #
# lowest and critical being the highest.                                      #
# Logging messages which are less severe than level will be ignored.          #
# logging messages which have severity level or higher will be printed        #
###############################################################################

levels = {
    'critical': logging.CRITICAL,
    'error': logging.ERROR,
    'warning': logging.WARNING,
    'info': logging.INFO,
    'debug': logging.DEBUG
}

###############################################################################
# Logger Handlers for use with the CTC Application                            #
###############################################################################
ctc_DebugLogger = None
ctc_InfoLogger = None
ctc_WarningLogger = None
ctc_ErrorLogger = None
ctc_CriticalLogger = None
ctc_DefaultLogger = None


###############################################################################
# Module Names can be 2 letter or 3 letters. In Order to keep the logs aligned#
# while indicating which module the debug is originating from, the Module name#
# is justified to 3 chars, with an underscore prefix for 2 letter module names#
###############################################################################
def format_module_name(ctc_loggerName):
    mod_name = 'CTC'
    if ctc_loggerName:
        mod_name = ctc_loggerName
        if len(mod_name) >= 3:
            mod_name = mod_name[:3]
        elif len(mod_name) < 3:
            mod_name = mod_name.rjust(3, '_')
    mod_name = mod_name + ':'
    return mod_name


###############################################################################
# get_console_handler - Used to set a common log format                       #
# The function can be be modified later if support is desire for file-based   #
# logs. Currently the function sets up a StreamHandler to console (stdout)    #
###############################################################################
def get_console_handler():
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(CTC_LOGFRMT)
    return console_handler


###############################################################################
# init_loggers - initializes the loggers for use with the Common ToolChain    #
# Logger Handlers for use with the CTC Application
###############################################################################
def init_loggers():
    global ctc_DebugLogger, ctc_InfoLogger, ctc_ErrorLogger, ctc_DefaultLogger, \
        ctc_WarningLogger, ctc_CriticalLogger

    ctc_DebugLogger = logging.getLogger('CTCd')
    ctc_DebugLogger.setLevel(logging.DEBUG)
    ctc_DebugLogger.addHandler(get_console_handler())
    ctc_DebugLogger.propagate = False

    ctc_InfoLogger = logging.getLogger('CTCi')
    ctc_InfoLogger.setLevel(logging.INFO)
    ctc_InfoLogger.addHandler(get_console_handler())
    ctc_InfoLogger.propagate = False

    ctc_ErrorLogger = logging.getLogger('CTCe')
    ctc_ErrorLogger.setLevel(logging.ERROR)
    ctc_ErrorLogger.addHandler(get_console_handler())
    ctc_ErrorLogger.propagate = False

    ctc_WarningLogger = logging.getLogger('CTCw')
    ctc_WarningLogger.setLevel(logging.WARNING)
    ctc_WarningLogger.addHandler(get_console_handler())
    ctc_WarningLogger.propagate = False

    ctc_CriticalLogger = logging.getLogger('CTCc')
    ctc_CriticalLogger.setLevel(logging.CRITICAL)
    ctc_CriticalLogger.addHandler(get_console_handler())
    ctc_CriticalLogger.propagate = False

    # Setup the Default Logger
    ctc_DefaultLogger = ctc_InfoLogger
    ctc_DefaultLogger.info('CMN: ******************************************************************')
    ctc_DefaultLogger.debug('CMN: Logger Handles setup complete')
    return ErrorCodes.SUCCESS


###############################################################################
# ctc_loggerLevel argument supports 4 levels in legacy mode 3 = Verbose       #
# 0 = Errors only, 1 = Warning, 2 = Info, and 3 = Debug                       #
# It supports all standard logger levels in LogLevel Mode, See the LogLevel   #
# enumeration for the levels supported.                                       #
###############################################################################
def get_logger(ctc_loggerName, ctc_loggerLevel):
    # Are the Logger Handlers initialized
    if not ctc_DebugLogger:
        init_loggers()

    mod_name = format_module_name(ctc_loggerName)

    ctc_DefaultLogger.error("CMN: Initializing Logger for module : " + ctc_loggerName)
    # We use requested to figure out which level is being requested for
    if ctc_loggerLevel >= LogLevel.DEBUG:
        if ctc_loggerLevel == LogLevel.DEBUG:
            ctc_DefaultLogger.error("CMN: Using DEBUG Level")
            return ctc_DebugLogger.getChild(mod_name)
        elif ctc_loggerLevel == LogLevel.INFO:
            ctc_DefaultLogger.error("CMN: Using INFO Level")
            return ctc_InfoLogger.getChild(mod_name)
        elif ctc_loggerLevel == LogLevel.WARNING:
            ctc_DefaultLogger.error("CMN: Using WARNING Level")
            return ctc_WarningLogger.getChild(mod_name)
        elif ctc_loggerLevel == LogLevel.ERROR:
            ctc_DefaultLogger.error("CMN: Using ERROR Level")
            return ctc_ErrorLogger.getChild(mod_name)
        elif ctc_loggerLevel == LogLevel.CRITICAL:
            ctc_DefaultLogger.error("CMN: Using CRITICAL Level")
            return ctc_ErrorLogger.getChild(mod_name)
        else:
            return ctc_DefaultLogger.getChild(mod_name)
    elif ctc_loggerLevel <= DebugLevel.DEBUG:
        if ctc_loggerLevel == DebugLevel.DEBUG:
            ctc_DefaultLogger.error("CMN: Using DEBUG Level")
            return ctc_DebugLogger.getChild(mod_name)
        elif ctc_loggerLevel == DebugLevel.INFO:
            ctc_DefaultLogger.error("CMN: Using INFO Level")
            return ctc_InfoLogger.getChild(mod_name)
        elif ctc_loggerLevel == DebugLevel.ERROR:
            ctc_DefaultLogger.error("CMN: Using ERROR Level")
            return ctc_ErrorLogger.getChild(mod_name)
    else:
        ctc_DefaultLogger.error("CMN: Invalid Logging Level requested. Using Default (INFO)")
        return ctc_DefaultLogger.getChild(mod_name)


###############################################################################
# Error Codes used for returning Compiler Errors                              #
# This may be customized for different compilers. The error-codes are also    #
# shared by FinalizeTags Modules                                              #
###############################################################################
class ErrorCodes(IntEnum):
    SUCCESS = 0
    FAILURE = 1
    NO_CONFIG = 2
    NO_BUILD_TOOL = 3
    NO_BUILD_VERSION = 4
    NO_VERSION_FILE = 5
    NO_WORKSPACE = 6
    NO_TOOL_PATH = 7
    SUB_PROCESS_ERR = 8
    MISSING_TAG = 9
    # Error Codes for ReleaseNotes Module
    NO_ARGUMENTS = 10
    NO_PROJECT_NAME = 11
    NO_BUILD_NUMBER = 12
    NO_REPOSITORY = 13
    INVALID_PYVER = 14
    MISSING_CREDENTIALS = 15
    INVALID_PARAMS = 16


###############################################################################
# Generic define for the Module enable/disable                                #
###############################################################################
class ModState(IntEnum):
    DISABLED = 0
    ENABLED = 1


###############################################################################
# DebugLevel defined for setting the debug level                              #
###############################################################################
class LogLevel(IntEnum):
    CRITICAL = 50
    FATAL = CRITICAL
    ERROR = 40
    WARNING = 30
    WARN = WARNING
    INFO = 20
    DEBUG = 10
    NOTSET = 0


###############################################################################
# DebugLevel defined for setting the debug level                              #
###############################################################################
class DebugLevel(IntEnum):
    ERROR = 1
    INFO = 2
    DEBUG = 3

###############################################################################
# VersionNumber defined for setting indexes in software version string        #
# major.minor.build.patch                                                     #
###############################################################################
class VersionNumber(IntEnum):
    SW_MAJOR = 0
    SW_MINOR = 1
    SW_PATCH = 2
    SW_BUILD = 3
    SW_MAXLEN = 4


###############################################################################
# Check that correction version of python is being used to run these scripts  #
# newer method of using print(f') not used as the script will fail in older   #
# versions                                                                    #
###############################################################################
class CheckPyVersion(object):
    def __init__(self):
        cmn_logger = get_logger(MODULE_NAME, DebugLevel.INFO)
        version = ".".join(map(str, sys.version_info[:3]))
        if sys.version_info < (3, 4, 0):
            cmn_logger.error('Python 3.4 or greater required for Common ToolChain, system ')
            cmn_logger.error('using ' + str(version))
            sys.exit(ErrorCodes.INVALID_PYVER)
        else:
            cmn_logger.info('Using Python Version           : ' + str(version))
            cmn_logger.info('******************************************************************')
