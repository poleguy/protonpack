#!/usr/bin/env python

import sys

from setuptools import setup

if __name__ == "__main__":
    version = ''
    argi = 1
    for arg in sys.argv[1:]:
        if len(arg.split('=')) > 1:
            (cmd, val) = arg.split('=', 2)
            if len(val) > 0:
                if "version" in cmd.lower():
                    version = val
                    del sys.argv[argi]
        argi += 1

    if len(version) == 0:
        print("Version must be specified!")
        sys.exit(1)

    setup(name            = 'shure_artifacts',
        version           = version,
        description       = 'Shure Artifactory Module',
        author            = 'Joe Croft',
        author_email      = 'croft_joe@shure.com',
        url               = '',
        install_requires  = ["requests"],
        package_dir       = {'Artifactory' : '.'},
        packages          = ['Artifactory'],
        py_modules        = ['Artifacts']
        )

