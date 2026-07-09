inherit systemd

DESCRIPTION = "Demonstration of running ieee1905-em in an isolated \
    network namespace"

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${WORKDIR}/ieee1905_create_ns.sh;beginline=2;endline=19;md5=d731450331b3bf78311e68e14f8223de"

RDEPENDS:${PN} = "ieee1905-em iproute2"

SRC_URI = "\
    file://ieee1905_create_ns.sh \
    file://ieee1905_em_agent.service \
    file://ieee1905_netns.service \
"

do_install() {
    install -d ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/ieee1905_em_agent.service ${D}${systemd_unitdir}/system/ieee1905_em_agent.service
    install -m 0644 ${WORKDIR}/ieee1905_netns.service ${D}${systemd_unitdir}/system/ieee1905_netns.service
    install -d ${D}/usr/ccsp
    install -m 0755 ${WORKDIR}/ieee1905_create_ns.sh ${D}/usr/ccsp
}


FILES:${PN} = "\
    ${systemd_unitdir}/system/ieee1905_em_agent.service \
    ${systemd_unitdir}/system/ieee1905_netns.service \
    /usr/ccsp/ieee1905_create_ns.sh \
"

SYSTEMD_SERVICE:${PN} += " \
    ieee1905_em_agent.service \
    ieee1905_netns.service \
"
