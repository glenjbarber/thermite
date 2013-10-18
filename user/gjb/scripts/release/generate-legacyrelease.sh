#!/bin/sh
#
# $FreeBSD$
# $relengid$
#

# The directory within which the release will be built.
CHROOTDIR="/scratch"

# The default svn checkout server, and svn branches for src/, doc/, and
# ports/.
SVNROOT="svn://svn.freebsd.org"
SRCBRANCH="base/head"
DOCBRANCH="doc/head"
PORTBRANCH="ports/head"
# The default src/, doc/, and ports/ revisions.
SRCREVISION="-r HEAD"
DOCREVISION="-r HEAD"
PORTREVISION="-r HEAD"
# The default make.conf and src.conf to use.  Set to /dev/null
# by default to avoid polluting the chroot(8) environment with
# non-default settings.
MAKE_CONF="/dev/null"
SRC_CONF="/dev/null"
# The number of make(1) jobs, defaults to the number of CPUs available.
MAKEJOBS="20"
MAKE_FLAGS="-s -j${MAKEJOBS}"

usage()
{
	echo "Usage: $0 [-c release.conf]"
	exit 1
}

while getopts c: opt; do
	case $opt in
	c)
		RELEASECONF="${OPTARG}"
		if [ ! -e "${RELEASECONF}" ]; then
			echo "Configuration file ${RELEASECONF} does not exist."
			exit 1
		fi
		. ${RELEASECONF}
		;;
	\?)
		usage
		;;
	esac
done
shift $(($OPTIND - 1))

if [ ! ${CHROOTDIR} ]; then
	echo "Please set CHROOTDIR."
	exit 1
fi

ARCH_FLAGS="TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH}"

if [ $(id -u) -ne 0 ]; then
	echo "Needs to be run as root."
	exit 1
fi

set -e # Everything must succeed

MAKE_FLAGS="${MAKE_FLAGS}"

mkdir -p ${CHROOTDIR}/usr/src

svn co ${SVNROOT}/${SRCBRANCH} ${CHROOTDIR}/usr/src ${SRCREVISION}
svn co ${SVNROOT}/${DOCBRANCH} ${CHROOTDIR}/usr/doc ${DOCREVISION}
svn co ${SVNROOT}/${PORTBRANCH} ${CHROOTDIR}/usr/ports ${PORTREVISION}

cd ${CHROOTDIR}/usr/src
make $MAKE_FLAGS buildworld
make installworld distribution DESTDIR=${CHROOTDIR}
mount -t devfs devfs ${CHROOTDIR}/dev
trap "umount ${CHROOTDIR}/dev" EXIT # Clean up devfs mount on exit

# Most commands below are run in chroot, so fake getosreldate(3) right now
OSVERSION=$(grep '#define __FreeBSD_version' ${CHROOTDIR}/usr/include/sys/param.h | awk '{print $3}')
export OSVERSION
BRANCH=$(grep '^BRANCH=' ${CHROOTDIR}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
BRANCH=`echo ${BRANCH} | sed -e 's,",,g'`
REVISION=$(grep '^REVISION=' ${CHROOTDIR}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
REVISION=`echo ${REVISION} | sed -e 's,",,g'`
OSRELEASE="${REVISION}-${BRANCH}"

cp /etc/resolv.conf ${CHROOTDIR}/etc/resolv.conf

LEGACY_FLAGS="MAKE_ISOS=yes CHROOTDIR=/release BUILDNAME=${OSRELEASE}"
LEGACY_FLAGS="${LEGACY_FLAGS} NODOC=yes EXTSRCDIR=/usr/src EXTPORTSDIR=/usr/ports"
LEGACY_FLAGS="${LEGACY_FLAGS} WORLD_FLAGS=-j${MAKEJOBS} KERNEL_FLAGS=-j${MAKEJOBS}"
LEGACY_FLAGS="${LEGACY_FLAGS} NODOC=yes"

chroot ${CHROOTDIR} make -C /usr/src $MAKE_FLAGS buildworld
chroot ${CHROOTDIR} make -C /usr/src/release ${ARCH_FLAGS} ${LEGACY_FLAGS} release

if [ "x${OSVERSION}" == "x" ]; then
	OSRELEASE=`chroot ${CHROOTDIR} uname -r`
fi

_DATE=`cat /snap/releng/scripts/builddate`
_SVNREV=`svn info ${CHROOTDIR}/usr/src | grep ^Revision | awk '{print $2}'`
: ${RELSTRING=`chroot ${CHROOTDIR} uname -s`-${OSRELEASE}-${TARGET_ARCH}-${_DATE}-r${_SVNREV}}

mkdir -p ${CHROOTDIR}/R
cd ${CHROOTDIR}/release/R/cdrom

for i in bootonly disc1 disc2 dvd1 livefs; do
	mv *$i.iso ${CHROOTDIR}/R/$RELSTRING-$i.iso
done
cd ${CHROOTDIR}/release/R
mv ftp ${CHROOTDIR}/R/ftp

cd ${CHROOTDIR}/R
sha256 $RELSTRING-* > CHECKSUM.SHA256-${_DATE}
md5 $RELSTRING-* > CHECKSUM.MD5-${_DATE}

