FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += "\
        file://dropbear_rsa_host_key \
"

do_install_append() {
        install -d ${D}${sysconfdir}/dropbear/
	install -m 0755 ${WORKDIR}/dropbear_rsa_host_key ${D}${sysconfdir}/dropbear
}

FILES_${PN} += "${sysconfir}/dropbear/*"
