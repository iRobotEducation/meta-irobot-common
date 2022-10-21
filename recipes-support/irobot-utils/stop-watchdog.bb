DESCRIPTION = "Stop the hardware watchdog reset at boot"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

SRC_URI = " \
          file://stop-watchdog \
"

inherit update-rc.d

INITSCRIPT_NAME = "stop-watchdog"
INITSCRIPT_PARAMS = "start 90 2 3 4 5 ."

do_install() {
	install -d ${D}${sysconfdir}/init.d
	install -m 0755 ${WORKDIR}/stop-watchdog ${D}${sysconfdir}/init.d
}

FILES_${PN} += "${sysconfdir}/*"
