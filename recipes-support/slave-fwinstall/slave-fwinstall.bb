DESCRIPTION = "slave board firmware install"
PRIORITY = "required"
LICENSE="GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"
SECTION = "console/utils"

DEPENDS += "irobot-utils"
RDEPENDS_${PN} += "version"

PACKAGE_ARCH="${MACHINE_ARCH}"
PR = "r17"

SRC_URI = " \
          git://git@git.wardrobe.irobot.com:7999/br/soho-nav-downloader.git;protocol=ssh;nobranch=1; \
          file://slave_firmware_install.sh \
          file://0001-fix-u_int32_t.patch \
"
DOWNLOADER_CODE = "5cdf3d0e7388e6bd125fa6336495ae681fd4568f"
SRCREV = "${DOWNLOADER_CODE}"


S = "${WORKDIR}/git"

do_compile() {
     make
}

do_install() {
     install -d ${D}${bindir}
     install -m 0755 ${S}/downloader ${D}${bindir}/
     install -m 0755 ${WORKDIR}/slave_firmware_install.sh  ${D}${bindir}/slave_firmware_install.sh
}

INSANE_SKIP_${PN} = "ldflags"

FILES_${PN} += "${bindir}/*"
