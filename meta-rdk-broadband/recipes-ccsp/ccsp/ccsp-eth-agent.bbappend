require ccsp_common_genericarm.inc
CFLAGS_aarch64_append = " -Werror=format-truncation=1 -g"
CFLAGS:remove = "-D_PLATFORM_RASPBERRYPI_"

FILESEXTRAPATHS_prepend := "${THISDIR}/ccsp-eth-agent:"

SRC_URI:remove = "${CMF_GITHUB_ROOT}/ethernet-agent;protocol=https;nobranch=1"
SRC_URI = "git://github.com/rdkcentral/ethernet-agent.git;protocol=https;branch=develop"
SRCREV_pn-ccsp-eth-agent = "e350f19aa5c0802c35ec520d9e1484b0033fc250"

SRC_URI_append = "\
    file://0001-genericarm-increase-maximum-number-of-Ethernet-interfaces.patch \
    "

