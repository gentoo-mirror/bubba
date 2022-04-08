# Copyright (c) 2020 gordonb3 <gordon@bosvangennip.nl>
# Distributed under the terms of the GNU General Public License v2


EAPI="7"

inherit mount-boot

DESCRIPTION="Binary kernel package for the B3 miniserver, from gentoo-sources"
HOMEPAGE="https://github.com/gordonb3/bubba-b3-kernel"

SRC_URI="${HOMEPAGE}/releases/download/${PVR}/${PF}.tar.xz -> ${PF}.tar.xz"

S=${WORKDIR}

LICENSE="GPL-2"
KEYWORDS="~arm"
SLOT="${PVR}"

RESTRICT="mirror strip test"

QA_PREBUILT='*'

src_install() {
	insinto /usr/src/linux-${PVR}-gentoo
	newins ${S}/boot/config-${PVR}-gentoo-b3 .config
	newins ${S}/boot/Module.symvers-${PVR}-gentoo-b3 Module.symvers
	newins ${S}/boot/System.map-${PVR}-gentoo-b3 System.map
	mv * "${ED}" || die
}

pkg_postinst() {
	ln -snf "${ROOT}/usr/src/linux-${PVR}-gentoo" "${ROOT}/usr/src/linux"
}

pkg_prerm() {
	einfo "replace = ${REPLACED_BY_VERSION}"
	if [[ -z "${REPLACED_BY_VERSION}" ]]; then
		mount-boot_check_status
		ebegin "Checking current running kernel version"
		_UNAME=$(uname -r)
		_UVERS=${_UNAME/-*/}

		if [[ "${_UVERS}" == "${PVR}" ]]; then
			eend 1
			# calling die() in this state appears to be ignored by emerge
			# we therefore create a backup of the kernel and modules so we
			# can restore it in the postrm phase
			MODULES=$(ls -1d ${ROOT}/lib/modules/${PVR}*)
			cp -al ${MODULES} ${ROOT}/lib/modules/_$(basename ${MODULES})
			ls -1 ${ROOT}/boot/*${PVR}-* | while read FILE; do
				cp -al ${FILE} ${ROOT}/boot/_$(basename ${FILE})
			done
			cp -a ${ROOT}/var/db/pkg/sys-kernel/${PF} /tmp/${PF}.pkgdb
			die "Cowardly refusing to uninstall the current running kernel"
		fi
		eend 0
	fi
}

pkg_postrm() {
	if [[ -z "${REPLACED_BY_VERSION}" ]]; then
		_UNAME=$(uname -r)
		_UVERS=${_UNAME/-*/}
		if [[ "${_UVERS}" == "${PVR}" ]]; then
			echo ""
			eerror "ERROR: Package manager ignored our call to die()"
			ewarn "  Restoring previous situation to salvage the situation"
			ewarn ""
			ewarn "  Should you have already installed a newer kernel, please boot into"
			ewarn "  the new kernel first before re-attempting removal of this package"
			MODULES=$(ls -1d ${ROOT}/lib/modules/_${PVR}*)
			cp -al ${MODULES} $(echo ${MODULES} | sed "s/_//")
			rm -rf ${MODULES}
			ls -1 ${ROOT}/boot/_*${PVR}-* | while read FILE; do
				mv ${FILE} $(echo ${FILE} | sed "s/_//")
			done
			sh -c "while [[ -d \"${ROOT}/var/db/pkg/sys-kernel/${PF}\" ]]; do sleep 10; done; cp -a \"/tmp/${PF}.pkgdb\" \"${ROOT}/var/db/pkg/sys-kernel/${PF}\"" &
		fi
	else
		# forcibly remove the kernel's modules
		MODULES=$(ls -1d ${ROOT}/lib/modules/${PVR}*)
		sh -c "while [[ -d \"${ROOT}/var/db/pkg/sys-kernel/${PF}\" ]]; do sleep 10; done; rm -rf \"${MODULES}\"" &

		# clean up the system source directory
		SELVERS=$(readlink "${ROOT}/usr/src/linux" | awk -F- '{print $2}')
		if [[ "${SELVERS}" == "${PVR}" ]]; then
			# do not leave a broken symlink behind
			rm -f "${ROOT}/usr/src/linux"
		fi
	fi
}

