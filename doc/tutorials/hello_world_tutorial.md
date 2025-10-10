# Protonpack Telemetry Setup Tutorial

In this tutorial we'll go through all the steps to set up the hardware for telemetry capture.

# Set up hardware

## connect serial cables
Connect pack. Pay attention to polarity of cabling. 
The negative polarity is closest to the IR.
The negative polarity is closest to the wood on the ac701 proton pack.

Connect via 4dB attenuators and 100 ohm series termination to the breaky IO board for the snickerdoodle black.

## position IR dongle

## programming cable and debug board

Pay attention to cable polarity.

# provide power.

A battery eliminator is convenient for bench top work. 4.2 Volts is nice.

# Set up the software

clone this repo.

## set up ADXR

### clone repo

```
  git clone ssh://git@bitbucket.shure.com:7999/dpsm_fpga/dpsm_rx_hw_test.git
  scripts/setup_python
  source scripts/activate_python
```

### program pack





# Alternative A: set up protonpack repo (This repo)

### program pack

...


picocom -b 115200 /dev/serial/by-id/usb-STMMicroelectronics_STMicroelectronics_Virtual_COM_Port_00000000001A-if00 

user: proton
password: proton



# Alternative B: set up ac701 repo

### program ac701

You must use an 800 Mbit version of the image.

