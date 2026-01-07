# Add Telemetry Tutorial

In this tutorial we'll go through all the steps to add telemetry RTL to a new portable design that requires a serial link based telemetry output.

We'll go through how to add it, how to simulate it, and how to test on hardware.

As an example we will use ADXR.

# set up ADXR repo

``` 
git clone ssh://git@bitbucket.shure.com:7999/dpsm_fpga/dpsm_rx.git
cd dpsm_rx
```

## Add telemetry dispatcher rtl

## add magic comments to the code 

## wire stuff together

## add scripting steps to the build_fpga process to generate the .csv file

## add scripting steps to the run_sim process to generate the .csv file


# simulate

## build the image, and deploy csv to artifactory

## create a matching ac701 image from the csv

### point to the artifactory csv

### build ac701 image


# test

## connect cables

## load telemetry support software on proton-pack pc

dpsm_rx_hw_test

## load ac701 image

## load ADXR image

## test telemetry following instructions

capture
vis