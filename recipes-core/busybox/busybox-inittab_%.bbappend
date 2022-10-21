FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://getty.sh"

do_install_append () {
        install -d ${D}${bindir}
	install -m 755 ${S}/getty.sh ${D}${bindir}
        install -d ${D}${sysconfdir}
	# change inittabs entry from getty start to the start of a script.
	# the script checks the SYSTEM_ACCESS env var to determine if getty should be started on the console.
	sed -i -e 's/^ttyS1::respawn.*$/ttyS1::respawn:\/usr\/bin\/getty.sh/' ${D}${sysconfdir}/inittab
}

FILES_${PN} = "${sysconfdir}/* ${bindir}/*"
