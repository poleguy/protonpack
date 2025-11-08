print("conftest.py top")
import os, sys

## get the path to this file to use as a reference to other paths
path_to_this_dir = os.path.dirname(os.path.abspath(__file__))

## insert these paths s.t. modules can easily be found and imported
sys.path.insert(0, os.path.join(path_to_this_dir, '..','modules'))  #access for example PythonSim.rtl

root_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)),"..")

def pytest_addoption(parser):
    parser.addoption("--gui", action="store_true", default=False)
    parser.addoption("--no_compile", action="store_true", default=False)
    parser.addoption("--waves", action="store_true", default=False)

def pytest_generate_tests(metafunc):
    # This is called for every test. Only get/set command line arguments
    # if the argument is specified in the list of test "fixturenames".
    #option_value = metafunc.config.option.name
    #if 'name' in metafunc.fixturenames and option_value is not None:
    #    metafunc.parametrize("name", [option_value])
    gui_value = metafunc.config.option.gui
    if 'gui' in metafunc.fixturenames and gui_value is not None:
        metafunc.parametrize("gui", [gui_value])

    no_compile_value = metafunc.config.option.no_compile
    if 'no_compile' in metafunc.fixturenames and no_compile_value is not None:
        metafunc.parametrize("no_compile", [no_compile_value])

    waves_value = metafunc.config.option.waves
    if 'waves' in metafunc.fixturenames and waves_value is not None:
        metafunc.parametrize("waves", [waves_value])
