INC=libgpio.h debug.h
LIB=libgpio
CROSS_COMPILE ?= arm-linux-gnueabihf-
CC ?= $(CROSS_COMPILE)gcc
AR ?= $(CROSS_COMPILE)ar
LD ?= $(CROSS_COMPILE)ld
STRIP ?= $(CROSS_COMPILE)strip

all: ${LIB}.a ${LIB}.so gpio
debug: ${LIB}.a ${LIB}.so

debug:	DEBUG="-DDEBUG"

CFLAGS=$(DEBUG) -g

gpio : ${LIB}.a gpio.c
	${CC} gpio.c $(CFLAGS) -L. -lgpio -I. -o $@

${LIB}.c : ${INC}

${LIB}.so : ${LIB}.c
	$(CC) $(CFLAGS) -fPIC -shared $< -I. -o $@

${LIB}.o : ${LIB}.c
	$(CC) $(CFLAGS) -c -o $@ $<

${LIB}.a : ${LIB}.o
	$(AR) rcs $@ $<

clean:
	rm -rf ${LIB}.a ${LIB}.so gpio ${LIB}.o
