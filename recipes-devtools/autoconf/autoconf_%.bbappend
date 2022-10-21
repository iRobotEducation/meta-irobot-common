FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

RDEPENDS_${PN}_class-nativesdk += "\
		nativesdk-perl-module-overloading \
    		nativesdk-perl-module-symbol \
		nativesdk-perl-module-file-spec \
    		nativesdk-perl-module-file-spec-unix \
	 	"
