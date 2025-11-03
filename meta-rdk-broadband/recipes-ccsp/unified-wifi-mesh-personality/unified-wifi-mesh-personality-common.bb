inherit systemd
DESCRIPTION = "Common runtime dependencies for unified-wifi-mesh for both controller and extender"
LICENSE = "CLOSED"

SRC_URI = " \
	file://InterfaceMap_em.json \
	file://em_agent.service \
"

do_install() {
	install -d ${D}${systemd_unitdir}/system
	install -D -m 0644 ${WORKDIR}/em_agent.service ${D}${systemd_unitdir}/system/em_agent.service

	install -d ${D}/usr/ccsp/EasyMesh/nvram
	install -m 0644 ${WORKDIR}/InterfaceMap_em.json ${D}/usr/ccsp/EasyMesh/nvram/InterfaceMap.json
}

FILES_${PN} = "\
	/usr/ccsp/EasyMesh/nvram/InterfaceMap.json \
	${systemd_unitdir}/system/em_agent.service \
"

SYSTEMD_SERVICE_${PN} = "em_agent.service"
