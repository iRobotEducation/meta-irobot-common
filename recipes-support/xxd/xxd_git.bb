SUMMARY = "xxd from the vim package"
DESCRIPTION = "hex dump tool"
LICENSE="GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

PV = "0.0.0+git${SRCPV}"
SRC_URI = "git://github.com/vim/vim.git"
SRCREV = "74b738d414b2895b3365e26ae3b7792eb82ccf47"

S = "${WORKDIR}/git/src/xxd"

inherit autotools

do_compile() {
    cd ${S}
    oe_runmake xxd;
}

do_install() {
    install -d ${D}${bindir}
    install -m 775 ${S}/xxd -D ${D}${bindir}/xxd
}

FILES_${PN} += "${bindir}/xxd"
