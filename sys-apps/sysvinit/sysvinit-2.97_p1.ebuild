# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

MY_P=${P/_*/}
S="${WORKDIR}/${MY_P}"

inherit toolchain-funcs flag-o-matic

DESCRIPTION="/sbin/init - parent of all processes"
HOMEPAGE="https://savannah.nongnu.org/projects/sysvinit"
SRC_URI="mirror://nongnu/${PN}/${MY_P}.tar.xz"

LICENSE="GPL-2"
SLOT="0"
[[ "${PV}" == *beta* ]] || \
KEYWORDS="~arm"
IUSE="selinux ibm static kernel_FreeBSD +feroceon"

CDEPEND="
	selinux? (
		>=sys-libs/libselinux-1.28
	)"
DEPEND="${CDEPEND}
	virtual/os-headers"
RDEPEND="${CDEPEND}
	selinux? ( sec-policy/selinux-shutdown )
	!<sys-apps/openrc-0.13
"

#S="${WORKDIR}/${P/_*}"

PATCHES=(
	"${FILESDIR}/${PN}-2.86-kexec.patch" #80220
	"${FILESDIR}/${PN}-2.94_beta-shutdown-single.patch" #158615
	"${FILESDIR}/${PN}-2.95_beta-shutdown-h.patch" #449354
)

pkg_pretend() {
	if use feroceon ; then
		ebegin "checking for Excito B3"
		grep -q "Feroceon 88FR131" /proc/cpuinfo 2>/dev/null || no_bubba
		eend 0
	else
		ebegin "skipping sanity check because it was forcibly disabled by USE flag -feroceon"
		eend 1 ""
	fi
}

no_bubba() { 
	eend 1 ""
	ewarn ""
	ewarn "    ##################################################################"
	ewarn "    #                                                                #"
	ewarn "    # WARNING!                                                       #"
	ewarn "    #                                                                #"
	ewarn "    # This does not appear to be a suitable system for this package. #"
	ewarn "    # This version of sysvinit specifically targets the Excito B3    #"
	ewarn "    # platform and will not behave correctly on other systems.       #"
	ewarn "    #                                                                #"
	ewarn "    # If you still insist on installing this package, then disable   #"
	ewarn "    # USE flag \"feroceon\" in package.use                             #"
	ewarn "    #                                                                #"
	ewarn "    ##################################################################"
	ewarn ""
	die "Excito B3 platform check failed"
}

src_prepare() {
	default

	sed -i \
		-e '/^CPPFLAGS =$/d' \
		-e '/^override CFLAGS +=/s/ -fstack-protector-strong//' \
		src/Makefile || die

	# last/lastb/mesg/mountpoint/sulogin/utmpdump/wall have moved to util-linux
	sed -i -r \
		-e '/^(USR)?S?BIN/s:\<(last|lastb|mesg|mountpoint|sulogin|utmpdump|wall)\>::g' \
		-e '/^MAN[18]/s:\<(last|lastb|mesg|mountpoint|sulogin|utmpdump|wall)[.][18]\>::g' \
		src/Makefile || die

	# pidof has moved to >=procps-3.3.9
	sed -i -r \
		-e '/\/bin\/pidof/d' \
		-e '/^MAN8/s:\<pidof.8\>::g' \
		src/Makefile || die

	# logsave is already in e2fsprogs
	sed -i -r \
		-e '/^(USR)?S?BIN/s:\<logsave\>::g' \
		-e '/^MAN8/s:\<logsave.8\>::g' \
		src/Makefile || die

	# Mung inittab for specific architectures
	cd "${WORKDIR}" || die
	cp "${FILESDIR}"/inittab-2.95 inittab || die "cp inittab"
	local insert=()
	use ppc && insert=( '#psc0:12345:respawn:/sbin/agetty 115200 ttyPSC0 linux' )
	use arm && insert=( '#f0:12345:respawn:/sbin/agetty 9600 ttyFB0 vt100' )
	use arm64 && insert=( 'f0:12345:respawn:/sbin/agetty 9600 ttyAMA0 vt100' )
	use hppa && insert=( 'b0:12345:respawn:/sbin/agetty 9600 ttyB0 vt100' )
	use s390 && insert=( 's0:12345:respawn:/sbin/agetty 38400 console dumb' )
	if use ibm ; then
		insert+=(
			'#hvc0:2345:respawn:/sbin/agetty -L 9600 hvc0'
			'#hvsi:2345:respawn:/sbin/agetty -L 19200 hvsi0'
		)
	fi
	(use arm || use mips || use sparc) && sed -i '/ttyS0/s:#::' inittab
	if use kernel_FreeBSD ; then
		sed -i \
			-e 's/linux/cons25/g' \
			-e 's/ttyS0/cuaa0/g' \
			-e 's/ttyS1/cuaa1/g' \
			inittab #121786
	fi
	if use x86 || use amd64 ; then
		sed -i \
			-e '/ttyS[01]/s:9600:115200:' \
			inittab
	fi
	if [[ ${#insert[@]} -gt 0 ]] ; then
		printf '%s\n' '' '# Architecture specific features' "${insert[@]}" >> inittab
	fi

	# Excito B3 specific entries

	# we only need the serial console on headless system
	sed -i "s/^\(c[0-9]:\)/#\1/" inittab
	sed -i "s/^#*\(s0:.*\-L\)  *[0-9]*  *\(.*\)$/\1 115200 \2/" inittab

	if use feroceon ; then
		cd "${S}"
		eapply "${FILESDIR}"/${MY_P}-write-magic.patch
	fi
}

src_compile() {
	tc-export CC
	append-lfs-flags
	export DISTRO= #381311
	export VERSION="${PV}"
	use static && append-ldflags -static
	emake -C src $(usex selinux 'WITH_SELINUX=yes' '')
}

src_install() {
	emake -C src install ROOT="${D}"
	dodoc README doc/*

	insinto /etc
	doins "${WORKDIR}"/inittab

	# dead symlink
	rm "${ED}"/usr/bin/lastb || die

	newinitd "${FILESDIR}"/bootlogd.initd bootlogd
	into /
	dosbin "${FILESDIR}"/halt.sh

	keepdir /etc/inittab.d

	find "${ED}" -type d -empty -delete || die
}

pkg_postinst() {
	# Reload init to fix unmounting problems of / on next reboot.
	# This is really needed, as without the new version of init cause init
	# not to quit properly on reboot, and causes a fsck of / on next reboot.
	if [[ ${ROOT} == / ]] ; then
		if [[ -e /dev/initctl ]] && [[ ! -e /run/initctl ]] ; then
			ln -s /dev/initctl /run/initctl \
				|| ewarn "Failed to set /run/initctl symlink!"
		fi
		# Do not return an error if this fails
		/sbin/telinit U &>/dev/null
	fi

	elog "The last/lastb/mesg/mountpoint/sulogin/utmpdump/wall tools have been moved to"
	elog "sys-apps/util-linux. The pidof tool has been moved to sys-process/procps."

	# Required for new bootlogd service
	if [[ ! -e "${EROOT}/var/log/boot" ]] ; then
		touch "${EROOT}/var/log/boot"
	fi
}
