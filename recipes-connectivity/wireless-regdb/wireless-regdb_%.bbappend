FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# add custom pre-compiled regdb:
# remove channel 14 support (not needed, don't want to support it or test it)
SRC_URI += " \
	file://regulatory.bin;subdir=${S} \
	file://regulatory.bin.5;subdir=${S} \
	file://regulatory.db;subdir=${S} \
	file://regulatory.db.p7s;subdir=${S} \
	file://regulatory.db.5;subdir=${S} \
	file://db.txt;subdir=${S} \
	file://sha1sum.txt;subdir=${S} \
	file://sforshee.x509.pem;subdir=${S} \
	file://sforshee.key.pub.pem;subdir=${S} \
	"
