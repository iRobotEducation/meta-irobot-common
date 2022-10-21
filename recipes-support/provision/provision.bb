DESCRIPTION = "system provisioning utility"
SECTION = "base"
PRIORITY = "required"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=0557f9d92cf58f2ccdd50f62f8ac0b28"

# depends on machine as we have diff dependencies for each
PACKAGE_ARCH = "${MACHINE_ARCH}"

PR = "r3"

SRC_URI = " \
	file://provision.sh \
	"

do_install() {
       	#sed -i -e 's/PRODUCT=\"generic\"/PRODUCT=\"${ROBOT}\"/' ${WORKDIR}/provision.sh
	install -d ${D}/opt/irobot/config
	install -d ${D}${bindir}
	install -m 755 ${WORKDIR}/provision.sh ${D}${bindir}/provision
}

FILES_${PN} += "${bindir}/* /opt/irobot/config"

