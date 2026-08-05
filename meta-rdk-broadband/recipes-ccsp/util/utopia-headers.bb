SUMMARY = "CCSP Utopia"
HOMEPAGE = "http://github.com/belvedere-yocto/Utopia"

LICENSE = "Apache-2.0 & BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=baa21dec03307f641a150889224a157f"
SRC_URI = "${CMF_GITHUB_ROOT}/utopia;protocol=https;nobranch=1"

# Remove these and revert to settings below when utopia.bbappend SRCREV removed
SRCREV = "c1b0ffa9b4eab392737931b48e9e23368b81d9a9"
PV = "2.7.2pre"

# SRCREV = "${SRCREV:pn-utopia}"
# PV = "${PV:pn-utopia}"
# PR = "${PR:pn-utopia}"

S = "${WORKDIR}/git"

# this is a header package only, nothing to build
do_compile[noexec] = "1"
do_configure[noexec] = "1"

# also get rid of the default dependency added in bitbake.conf
# since there is no 'main' package generated (empty)
RDEPENDS_${PN}-dev = ""

do_install() {
    install -D -m 0644 ${S}/source/include/autoconf.h ${D}${includedir}/utctx/autoconf.h
    install -D -m 0644 ${S}/source/utctx/lib/utctx.h ${D}${includedir}/utctx/utctx.h
    install -D -m 0644 ${S}/source/utctx/lib/utctx_api.h ${D}${includedir}/utctx/utctx_api.h
    install -D -m 0644 ${S}/source/utctx/lib/utctx_rwlock.h ${D}${includedir}/utctx/utctx_rwlock.h
}
