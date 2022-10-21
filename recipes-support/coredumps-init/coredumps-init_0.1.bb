DESCRIPTION = "Init Kernel coredumps to save them atomically into data storage"
SECTION = "base"
PRIORITY = "required"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

PR = "r3"

SRC_URI = " \
    file://coredumps-init.sh \
	file://coredumps-cleanup.sh \
    file://coredump-proxy.sh \
"

inherit update-rc.d
# should be run after any firmware-links or irobot-persistent
# services, but before connectivity and cleantrack
INITSCRIPT_PARAMS = "defaults 90"
INITSCRIPT_NAME = "coredumps.init"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/coredump-proxy.sh ${D}${bindir}

	install -d ${D}${INIT_D_DIR}
    install -m 0755 ${WORKDIR}/coredumps-init.sh ${D}${INIT_D_DIR}/coredumps.init
	
	# copy coredumps-cleanup.sh to /usr/bin which run by cron job
    install -m 0755 ${WORKDIR}/coredumps-cleanup.sh -D ${D}${bindir}
}
