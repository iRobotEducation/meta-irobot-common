FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
        file://fragment.cfg;subdir=busybox-1.30.1 \
        file://udhcpd.conf \
        file://mdev.conf \
        file://cron.root \
        file://simple.script \
        file://syslog.conf \
        "

DEPENDS_append = " update-rc.d-native"

INITSCRIPT_PACKAGES += "${PN}-cron"
INITSCRIPT_NAME_${PN}-cron = "busybox-cron"

do_install_append () {
        install -d ${D}${sysconfdir}/cron/crontabs/
        install -m 0644 ${WORKDIR}/udhcpd.conf ${D}${sysconfdir}
		install -m 0644 ${WORKDIR}/udhcpd.conf ${D}${sysconfdir}/udhcpd.conf.default
        install -m 0644 ${WORKDIR}/mdev.conf ${D}${sysconfdir}
        install -m 0644 ${WORKDIR}/cron.root ${D}${sysconfdir}/cron/crontabs/root
        install -m 0644 ${WORKDIR}/syslog.conf ${D}${sysconfdir}
	update-rc.d -r ${D} busybox-cron start 38 S .
}

FILES_${PN}-cron = "${sysconfdir}/*"
