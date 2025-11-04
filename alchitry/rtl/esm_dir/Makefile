TARGETS = asm \
	motor_rev.hex \
	rs232io_32bit_dump.hex

all: $(TARGETS)

asm: asm.c
	gcc asm.c -o asm

main.hex: main.psm
	./asm main.psm

rs232io_32bit_dump.hex: rs232io_32bit_dump.psm
	./asm rs232io_32bit_dump.psm

#rs232io_32bit.hex: rs232io_32bit.psm
#	./asm rs232io_32bit.psm


clean:
	rm -f asm main.hex rs232io_32bit_dump.hex
