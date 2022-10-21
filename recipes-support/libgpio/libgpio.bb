DESCRIPTION = "libgpio"
PRIORITY = "required"
LICENSE="GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"
SECTION = "libs"

PACKAGE_ARCH="${MACHINE_ARCH}"
PR = "r1"
PR_APPEND = ".${SRCREV}"

SRC_URI = " \
          file://Makefile \
          file://debug.h \
          file://libgpio.h \
          file://libgpio.c \
          file://gpio.c \
"

S = "${WORKDIR}"

do_install() {
     install -d ${D}${bindir}
     install -m 0755 ${S}/gpio ${D}${bindir}/gpio
     install -d ${D}${libdir}
     install -m 0755 ${S}/libgpio.so ${D}${libdir}/libgpio.so
}

# add SOLIBSDEV so that the .so files don't get sucked into .dev packages
FILES_SOLIBSDEV = ""
FILES_${PN} += "${bindir}/gpio ${libdir}/libgpio.so"
