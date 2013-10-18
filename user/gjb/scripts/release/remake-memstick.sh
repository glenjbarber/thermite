#!/bin/sh
#
# $FreeBSD: scripts/remake-memstick.sh 323 2013-10-17 18:56:44Z gjb $
# $relengid$
#

PATH="/bin:/sbin:/usr/bin:/usr/sbin"
export PATH

usage () {
	echo "$(basename ${0}) -c /path/to/release.conf"
	exit 1
}

while getopts c: opt; do
	case ${opt} in
		c)
			MEMSTICK_CONFIG="${OPTARG}"
			if [ ! -e "${MEMSTICK_CONFIG}" ]; then
				echo -n "ERROR: Configuration file ${MEMSTICK_CONFIG}"
				echo " does not exist."
				exit 1
			fi
			. ${MEMSTICK_CONFIG}
			;;
		\?)
			usage
			;;
	esac
done

# Force use of configuration file
if [ "X${MEMSTICK_CONFIG}" = "X" ]; then
	usage
fi

MEMSTICK_ARCH=$(echo ${__CONFIG_NAME} | cut -f 2 -d -)

case ${MEMSTICK_ARCH} in
	# For now, only create amd64 and i386 vm images.
	i386)
		# i386 needs memstick rebuilt; other architectures do not.
		;;
	*)
		exit 0
		;;
esac

MEMSTICK_IMAGE_NAME=$(make -C ${CHROOTDIR}/usr/src/release -V REVISION -V BRANCH | tr '\n' '-')
MEMSTICK_IMAGE_NAME="$(uname -s)-${MEMSTICK_IMAGE_NAME}${MEMSTICK_ARCH}"
MEMSTICK_IMAGE_NAME="${MEMSTICK_IMAGE_NAME}-memstick.img"

cd ${CHROOTDIR}/R && (
rm -f FreeBSD*memstick.img || exit 1
rm -f CHECKSUM.* || exit 1
/bin/sh ${CHROOTDIR}/usr/src/release/${MEMSTICK_ARCH}/make-memstick.sh \
	${CHROOTDIR}/usr/obj/usr/src/release/release \
	${CHROOTDIR}/R/${MEMSTICK_IMAGE_NAME}
)

cd ${CHROOTDIR}/R
sha256 FreeBSD* > CHECKSUM.SHA256
md5 FreeBSD* > CHECKSUM.MD5
exit 0
