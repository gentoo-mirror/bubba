# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

EAPI="5"

inherit eutils

DESCRIPTION="Excito B2 manual"
HOMEPAGE="http://www.excito.com/"

if [[ ${PR} == "r0" ]] ; then
	SRC_URI="http://update.excito.org/pool/main/b/${PN}/${PN}_${PV}.tar.xz"
else
	REV=${PR/r/rc}
	SRC_URI="http://update.excito.org/pool/main/b/${PN}/${PN}_${PV}~${REV}.tar.xz"
fi


RESTRICT="mirror"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~ppc"


src_install() {
	insinto /opt/bubba/manual
	doins -r manual/*
	dodoc debian/copyright debian/changelog
}
