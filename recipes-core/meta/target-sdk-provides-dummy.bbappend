FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

DUMMYPROVIDES_PACKAGES += "\
    perl-module-overloading \
    perl-module-symbol \
    perl-module-file-spec \
    perl-module-file-spec-unix \
    "
