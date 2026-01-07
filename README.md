# Proton Pack Telemetry Capture System

## About

The Proton Pack is a portable telemetry system designed to capture and display real time visualizations and record data for analysis from embedded FPGA systems.

# System Architecture

The system is composed of hardware and software components and a protocol for sending telemetry data from a DUT over a serial link.

The software is split between two components: live, real-time visualization software and post processing software.

## Telemetry Struture

https://bitbucket.shure.com/projects/DPSM_FPGA/repos/telemetry/browse/doc/portable_telemetry.ctd

## Block Diagram

![System Block Diagram](doc/System_Block_Diagram.drawio.svg)

![UI](doc/Proton_Pack_UI.drawio.svg)

## Proton Pack Hardware

Proton Pack hardware is described under the [hardware/REDAME.md](hardware/README.md) file.

## Live Visualization Software

This software will read in a recorded telemetry stream and produce live visualizations with low latency to aid in
providing rapid feedback during walk testing.

## Capture Scripting

Time synchronization.
Pairing (telemetry pack to a portable)

## Post processing software

The post processing software takes the captured telemetry and prepares it for analysis in python and for rapid visualization of a given time period of the capture. It converts the format to hdf5 and is in charge of aligning all of the data from multiple DUT's capturing simultaneous telemetry.


# FPGA Build

# Proton Pack Telemetry Capture System

## Alchitry Pt Design

Build from https://fpga.jenkins-ecs.shure.com/job/DEVELOPMENT/job/TELEMETRY/job/protonpack/

Setup:

```
git clone --filter=tree:0 --no-checkout --quiet ssh://git@bitbucket.shure.com:7999/dpsm_fpga/protonpack.git
cd protonpack
git checkout --no-progress $branch

cd alchitry
source ./build_fpga $branch
```

## Program

See [hardware/REDAME.md](hardware/README.md) for instructions on connecting the board/cables/power/etc.

```
scripts/get_artifactory https://artifactory.shure.com/All_Shure_Components/ATLAS/protonpack/0.0.0.71/
scripts/program_flash_artifactory

```


## Test

run 
```
FT600/test_it
```


# Simulation

```
./run_sim
```

Should report all PASSED

## Check Sim Results

```
gtkwave tests/sim_build/tests.test_pc_loopback/test_main/wave1.fst 

```

# It works on my machine

run 

```scripts/test_install.sh

# Design Notes

design notes are left out of this document to avoid [clutter](doc/design_notes.md)


# Copyright

Copyright (c) 2025, Shure Incorporated

Nicholas Dietz (dietzn@shure.com)

Proton Pack software is licensed according to the [LICENSE](./LICENSE) file.
