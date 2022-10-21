DESCRIPTION = "ota-cleanup"
PRIORITY = "required"
LICENSE="Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

PV = "1.0.0"
PR = "r0"
SRCREV = "${PV}"

SRC_URI = " \
          file://ota-cleanup \
"

inherit update-rc.d

# on startup, should run after persistent setup, but before connectivity/cleantrack,
# so that any app checking for storage gets space utilization excluding residual
# ota (if any).
INITSCRIPT_NAME = "ota-cleanup"
INITSCRIPT_PARAMS = "defaults 56"

do_install() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/ota-cleanup ${D}${sysconfdir}/init.d
}

FILES_${PN} += "${sysconfdir}/*"
