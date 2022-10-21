# ts utility shell script
DESCRIPTION = "logs the time-stamp on input lines"
SECTION = "base"
PRIORITY = "required"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

PV = "1.0.0"
PR = "r0"
SRCREV = "${PV}"

SRC_URI = " \
          file://ts \
"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/ts ${D}${bindir}/ts
}
