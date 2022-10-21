SUMMARY = "Network Time Protocol daemon startup"
LICENSE="GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = " \
           file://ntp.conf \
           file://ntpd \
"

inherit autotools update-rc.d pkgconfig

INITSCRIPT_NAME = "ntpd"
INITSCRIPT_PARAMS = "defaults"

do_compile () {
}

do_install () {
        install -d ${D}${sysconfdir}/init.d
        install -m 0755 ${WORKDIR}/ntpd ${D}${sysconfdir}/init.d/
	install -m 0644 ${WORKDIR}/ntp.conf ${D}${sysconfdir}/
}

FILES_${PN} += "${sysconfdir}/*"

