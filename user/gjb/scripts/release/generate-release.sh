#!/bin/sh
#
# $FreeBSD: head/release/generate-release.sh 240967 2012-09-26 18:04:16Z gjb $
# $relengid$
#

conffile="$(dirname ${0})/snapshot.conf"

. ${conffile}

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
MAKE_FLAGS="-s -j20"
KERNEL="GENERIC"

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

# The aggregated build-time flags based upon variables defined within
# this file, unless overridden by release.conf.  In most cases, these
# will not need to be changed.
CONF_FILES="__MAKE_CONF=${MAKE_CONF} SRCCONF=${SRC_CONF}"
ARCH_FLAGS="TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH}"
CHROOT_WMAKEFLAGS="${MAKE_FLAGS} ${CONF_FILES}"
CHROOT_IMAKEFLAGS="${CONF_FILES}"
CHROOT_DMAKEFLAGS="${CONF_FILES}"
RELEASE_WMAKEFLAGS="${MAKE_FLAGS} ${ARCH_FLAGS} ${CONF_FILES}"
RELEASE_KMAKEFLAGS="${MAKE_FLAGS} KERNCONF=${KERNEL} ${ARCH_FLAGS} ${CONF_FILES}"
RELEASE_RMAKEFLAGS="${ARCH_FLAGS} KERNCONF=${KERNEL} ${CONF_FILES}"

if [ ! ${CHROOTDIR} ]; then
	echo "Please set CHROOTDIR."
	exit 1
fi

if [ $(id -u) -ne 0 ]; then
	echo "Needs to be run as root."
	exit 1
fi

set -e # Everything must succeed

mkdir -p ${CHROOTDIR}/usr/src

svn co ${SVNROOT}/${SRCBRANCH} ${CHROOTDIR}/usr/src $SRCREVISION
svn co ${SVNROOT}/${DOCBRANCH} ${CHROOTDIR}/usr/doc $DOCREVISION
svn co ${SVNROOT}/${PORTBRANCH} ${CHROOTDIR}/usr/ports $PORTREVISION

cd ${CHROOTDIR}/usr/src
## Skip this, we've already installed a 'master' world build to save time.
#make ${CHROOT_WMAKEFLAGS} buildworld
#make ${CHROOT_IMAKEFLAGS} installworld DESTDIR=${CHROOTDIR}
#make ${CHROOT_DMAKEFLAGS} distribution DESTDIR=${CHROOTDIR}
mount -t devfs devfs ${CHROOTDIR}/dev
trap "umount ${CHROOTDIR}/dev" EXIT # Clean up devfs mount on exit

# Most commands below are run in chroot, so fake getosreldate(3) right now
OSVERSION=$(grep '#define __FreeBSD_version' ${CHROOTDIR}/usr/src/sys/sys/param.h | awk '{print $3}')
export OSVERSION
BRANCH=$(grep '^BRANCH=' ${CHROOTDIR}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
BRANCH=`echo ${BRANCH} | sed -e 's,",,g'`
REVISION=$(grep '^REVISION=' ${CHROOTDIR}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
REVISION=`echo ${REVISION} | sed -e 's,",,g'`
OSRELEASE="${REVISION}-${BRANCH}"

build_ports() 
{
	## Trick the ports 'run-autotools-fixup' target to do the right thing.
	OSVERSION=`sysctl -n kern.osreldate`
	if [ "x${TARGET}" == "xsparc64" ]; then
		chroot ${CHROOTDIR} make -C /usr/ports/sysutils/cdrtools \
			BATCH=yes WITHOUT_CDDA2MP3=yes WITHOUT_CDDA2OGG=yes \
			NOPORTDOCS=yes WITHOUT_RSCSI=yes \
			OSVERSION=${OSVERSION} install
	fi
}

cp /etc/resolv.conf ${CHROOTDIR}/etc/resolv.conf
# Install sysutils/cdrtools if target arch is sparc64.
#build_ports "${CHROOTDIR}"

chroot ${CHROOTDIR} make -C /usr/src ${RELEASE_WMAKEFLAGS} buildworld
chroot ${CHROOTDIR} make -C /usr/src ${RELEASE_KMAKEFLAGS} buildkernel
chroot ${CHROOTDIR} make -C /usr/src/release ${RELEASE_RMAKEFLAGS} NODOC=yes release
chroot ${CHROOTDIR} make -C /usr/src/release ${RELEASE_RMAKEFLAGS} NODOC=yes install DESTDIR=/R

if [ "x${OSVERSION}" == "x" ]; then
	OSRELEASE=`chroot ${CHROOTDIR} uname -r`
fi

_DATE=`cat /snap/releng/scripts/builddate`
_SVNREV="r`cat /snap/releng/scripts/svnrev.txt`"
: ${RELSTRING=`chroot ${CHROOTDIR} uname -s`-${OSRELEASE}-${TARGET_ARCH}-${_DATE}-${_SVNREV}}

cd ${CHROOTDIR}/R

case ${TARGET_ARCH} in
	i386)
		img=`ls ./*memstick.img`
		rm -f ./${img}
		${CHROOTDIR}/usr/src/release/${TARGET_ARCH}/make-memstick.sh \
			${CHROOTDIR}/usr/obj/usr/src/release/release \
			./${img}
		;;
	*)
		# fallthrough
		;;
esac

for i in release.iso bootonly.iso memstick.img; do
	if [ -e $i ] || [ "x${OSVERSION}" = "x10.0" ]; then
		mv *$i $RELSTRING-$i
	fi
done
sha256 FreeBSD-* > CHECKSUM.SHA256-${_DATE}
md5 FreeBSD-* > CHECKSUM.MD5-${_DATE}

case ${TARGET_ARCH} in
	i386|amd64)
		# FALLTHROUGH
		;;
	*)
		exit 0
		;;
esac

mkdir -p ${CHROOTDIR}/vmimage ${CHROOTDIR}/vmimage/mnt
touch ${CHROOTDIR}/vmimage/${RELSTRING}.disk
truncate -s 10G ${CHROOTDIR}/vmimage/${RELSTRING}.disk
mdconfig -a -t vnode -f ${CHROOTDIR}/vmimage/${RELSTRING}.disk
gpart create -s gpt /dev/md0
gpart add -t freebsd-boot -s 512k -l bootfs /dev/md0
gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 /dev/md0
gpart add -t freebsd-swap -s 1G -l swapfs /dev/md0
gpart add -t freebsd-ufs -l rootfs /dev/md0
newfs /dev/md0p3
mount /dev/md0p3 ${CHROOTDIR}/vmimage/mnt
set +e
chroot ${CHROOTDIR} make -s -C /usr/src DESTDIR=/vmimage/mnt installworld installkernel distribution
echo "# Custom /etc/fstab for FreeBSD VM images" > ${CHROOTDIR}/vmimage/mnt/etc/fstab
echo "/dev/gpt/rootfs / ufs rw 2 2" >> ${CHROOTDIR}/vmimage/mnt/etc/fstab
echo "/dev/gpt/swapfs none swap sw 0 0" >> ${CHROOTDIR}/vmimage/mnt/etc/fstab
while ! umount /dev/md0p3; do
	sleep 1
done
mdconfig -d -u 0
set -e
diskformats="vmdk qcow2"
for f in ${diskformats}; do
	qemu-img convert -O ${f} ${CHROOTDIR}/vmimage/${RELSTRING}.disk \
		${CHROOTDIR}/vmimage/${RELSTRING}.${f}
	xz ${CHROOTDIR}/vmimage/${RELSTRING}.${f}
done
cd ${CHROOTDIR}/vmimage
sha256 FreeBSD*.xz > CHECKSUM.SHA256-${_DATE}
md5 FreeBSD*.xz > CHECKSUM.MD5-${_DATE}

