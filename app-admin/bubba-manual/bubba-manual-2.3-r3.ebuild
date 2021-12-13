# Copyright 2015-2016 gordonb3 <gordon@bosvangennip.nl>
# Distributed under the terms of the GNU General Public License v2
# $Header$

EAPI="6"

inherit eutils

DESCRIPTION="Excito B3 manual"
HOMEPAGE="http://www.excito.com/"

if [[ ${PR} == "r0" ]] ; then
	SRC_URI="http://b3.update.excito.org/pool/main/b/${PN}/${PN}_${PV}.tar.gz"
else
	REV=${PR/r/rc}
	SRC_URI="http://b3.update.excito.org/pool/main/b/${PN}/${PN}_${PV}~${REV}.tar.gz"
fi


RESTRICT="mirror"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~arm"


S=${WORKDIR}/${PN}

src_install() {
	insinto /opt/bubba/manual
	doins -r manual/*
	dodoc debian/copyright debian/changelog
}
