# Design notes

Stuff that may be speculative, todo, etc.

https://forums.raspberrypi.com/viewtopic.php?t=363027
https://www.youtube.com/watch?v=sbrCiN6HGrI

1455 series enclosures

https://en.wikipedia.org/wiki/Eurocard_(printed_circuit_board)

https://en.wikipedia.org/wiki/Raspberry_Pi

Real Time Clock.
pi 5 includes RTC.

compute module 5

https://www.raspberrypi.com/products/compute-module-5/?variant=cm5-104032

https://en.wikipedia.org/wiki/Precision_Time_Protocol

does compute module 5 have RTC?
yes?
https://bret.dk/raspberry-pi-compute-module-5-review-cooler-faster-better/



https://www.raspberrypi.com/documentation/computers/raspberry-pi.html


todo: test with pc first.
test with raspberry pi5
complete with compute module 5.

Can it

We don't need GPS, only NTP that's synced to the same time.

todo: add CRC to link protocol.
todo: add crc checking and display to software. Possibly just an error counter.


Green link light. Indicates link is up and no data errors. Goes red for 3 seconds if there is any error.
Blue link light. Displays blue if some threshold is reached. BER/SNR/power/etc.
todo: how to define?

todo: write definition of what current telemetry system does.

todo: can the compute module automatically convert pcapng to hdf5.

should it be done in C++ for speed?
should it be optimized using a profiler?
should it be done as a stream?
should it be broken into chunks as a pcapng?
as an hdf5?


todo: 

Internal to the #Axient #Digital #PSM Receiver (ADXR) that #Shure just shipped there is, unsurprisingly, a programming header 
that exposes #serial, #JTAG, etc. It is in violation of (Murphy's)[https://en.wikipedia.org/wiki/Edward_A._Murphy_Jr.] law. 
This stupid cable has the same connector at both ends, but is electrically asymmetrical. It has no key feature and has
no obvious polarity marking on the board or on the cable.

We are now starting to design the next generation product. I have added to my list that I will not allow this mistake to 
propogate to the new design.

#electronics


