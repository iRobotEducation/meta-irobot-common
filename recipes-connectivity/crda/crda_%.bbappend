FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# add modified pub key, associated with custom pre-compiled regdb
SRC_URI += " \
	file://sforshee.key.pub.pem;subdir=${S}/pubkeys \
	"
