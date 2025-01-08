# Proton Pack Hardware

Copyright (c) 2025, Shure Incorporated

Proton Pack Hardware is licensed under the CERN-OHL-P-2.0 license found in the LICENSE file.

# Hardware

The hardware consists of a capture system that records a data stream provided from a device under test (DUT) via a pair of coaxial cables.

# DUT hardware.

The signal from the DUT is sent from a standard FPGA GPIO pin to avoid requiring a transceiver. A transceiver would also work.
The signalling is HSTL-II to provide a fast signal rate of 1GBps or higher.

No termination is needed on the DUT. The transmission pair lines are wired simply to a pair of coax connectors.

On the receiving device the termination should be AC coupled into an MGT transceiver that is internally terminated.

It could also be directly connected as on the AC701 board.

# Reference

## Cabling
https://www.ti.com/lit/an/slyt163/slyt163.pdf?ts=1736333230589

## HSTL signaling
https://en.wikipedia.org/wiki/High-speed_transceiver_logic

## AC701 Schematic
https://www.xilinx.com/support/documents/boards_and_kits/artix-7/ac701-schematic-xtp218-rev1-0.pdf

## MGT Termination
https://adaptivesupport.amd.com/s/article/75774?language=en_US
https://0x04.net/~mwk/xidocs/ug/ug476_7Series_Transceivers.pdf

## The Proton Pack Is Not A Toy
https://www.youtube.com/@TheProtonPackIsNotAToy