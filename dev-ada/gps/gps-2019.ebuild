# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
PYTHON_COMPAT=( python2_7 )
ADA_COMPAT=( gnat_201{8,9} )
inherit ada python-single-r1 autotools desktop llvm multilib

MYP=${PN}-gpl-${PV}-src

commitId="8606676b6b4fb245faad5e91127b15c2e61174e9"
alsId="286f2d6bb14ccd4583034b26fd923e1b80cf522c"

DESCRIPTION="The GNAT Programming Studio"
HOMEPAGE="http://libre.adacore.com/tools/gps/"
SRC_URI="https://github.com/AdaCore/${PN}/archive/${commitId}.tar.gz
	-> ${MYP}.tar.gz
	http://mirrors.cdn.adacore.com/art/5cdf8f4e31e87a8f1d42509f
	-> libadalang-tools-2019-20190517-195C4-src.tar.gz
	https://github.com/AdaCore/ada_language_server/archive/${alsId}.tar.gz
	-> ada_language_server-2019-src.tar.gz
	http://mirrors.cdn.adacore.com/art/5b0819dfc7a447df26c27a61 ->
		gtk+-3.14.15-src.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="${PYTHON_DEPS}
	dev-ada/gnatcoll-db[${ADA_USEDEP},db2ada,gnatinspect,xref]
	dev-ada/gnatcoll-bindings[${ADA_USEDEP},python]
	~dev-ada/gtkada-2019[${ADA_USEDEP}]
	~dev-ada/libadalang-2019[${ADA_USEDEP}]
	dev-libs/gobject-introspection
	dev-libs/libffi
	sys-devel/llvm:7
	sys-devel/clang:=
	x11-themes/adwaita-icon-theme
	x11-themes/hicolor-icon-theme
	dev-python/pep8[${PYTHON_USEDEP}]
	dev-python/jedi[${PYTHON_USEDEP}]"

DEPEND="${RDEPEND}"

REQUIRED_USE="${PYTHON_REQUIRED_USE}
	${ADA_REQUIRED_USE}"

RESTRICT="test"

S="${WORKDIR}"/${PN}-${commitId}

PATCHES=( "${FILESDIR}"/${P}-gentoo.patch )

pkg_setup() {
	LLVM_MAX_SLOT=7
	llvm_pkg_setup
	python-single-r1_pkg_setup
	ada_pkg_setup
}

src_prepare() {
	default
	sed -i \
		-e "s:@GNATMAKE@:${GNATMAKE}:g" \
		-e "s:@GNAT@:${GNAT}:g" \
		-e "s:@GNATLS@:${GNATLS}:g" \
		share/support/core/toolchains.py \
		share/support/core/projects.py \
		|| die
	mv "${WORKDIR}"/libadalang-tools-2019-20190517-195C4-src laltools
	mv "${WORKDIR}"/ada_language_server-${alsId} ada_language_server
	echo "#!/bin/bash" > gps.sh
	echo "export LD_LIBRARY_PATH=/usr/$(get_libdir)/gps" >> gps.sh
	echo 'exec /usr/bin/gps_exe "$@"' >> gps.sh
	cd ../gtk+-3.14.15-src
	sed -i \
		-e "/^libadd/s:=.*$:= \\\:" \
		-e "/^deps/s:=.*$:= \\\:" \
		../gtk+-3.14.15-src/gtk/Makefile.in
}

src_configure() {
	econf \
		--with-clang=$(llvm-config --libdir)
	cd ../gtk+-3.14.15-src
	econf --disable-cups
}

src_compile() {
	emake -C gps GPRBUILD_FLAGS="-v ${MAKEOPTS} \
		-XGPR_BUILD=relocatable" \
		Build=Production
	gprbuild -v -p -Pcli/cli.gpr ${MAKEOPTS} -XLIBRARY_TYPE=relocatable \
		-XGPR_BUILD=relocatable -cargs:Ada ${ADAFLAGS} || die
	cd ../gtk+-3.14.15-src
	emake -C gtk/inspector
	emake -C gtk gtk.gresource.xml gtkdbusgenerated.c gtkdbusgenerated.h
	emake -C gtk libgtk-3.la
}

src_install() {
	default
	make_desktop_entry "${PN}" "GPS" "${EPREFIX}/usr/share/gps/icons/hicolor/32x32/apps/gps_32.png" "Development;IDE;"
	mv "${D}"/usr/bin/gps{,_exe}
	newbin gps.sh gps
	cd ../gtk+-3.14.15-src
	emake -C gtk DESTDIR="${D}" install-libLTLIBRARIES
	rm "${D}"/usr/$(get_libdir)/libgtk-3.{la,so,so.0} || die
	dosym ../libgtk-3.so.0.1400.15 /usr/$(get_libdir)/gps/libgtk-3.so.0
}
