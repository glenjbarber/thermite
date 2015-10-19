#!/bin/sh
#
# $FreeBSD$
#

runcmd() {
	eval "$@"
}

loop_revs() {
	for rev in ${revs}; do
		eval runcmd "$@"
	done
	unset rev
}

loop_archs() {
	for arch in ${archs}; do
		eval runcmd "$@"
	done
	unset arch
}

loop_kernels() {
	for kernel in ${kernels}; do
		eval runcmd "$@"
	done
	unset kernel
}

loop_types() {
	for type in ${types}; do
		eval runcmd "$@"
	done
	unset type
}

runall() {
	eval loop_revs loop_archs loop_kernels loop_types "$@"
}

ftp_stage() {
	local conf
	conf="${__BUILDCONFDIR}/${rev}-${arch}-${kernel}-${type}.conf"
	[ ! -e "${conf}" ] && return 0
	unset BOARDNAME
	. "${conf}"
	[ -z "${CHROOTDIR}" ] && return 0

	case ${arch} in
	amd64|i386|powerpc|sparc64)
		MAKE_FLAGS="TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH}"
		;;
	powerpc64)
		MAKE_FLAGS="TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH} KERNCONF=${KERNEL}"
		;;
	armv6)
		MAKE_FLAGS="TARGET=arm TARGET_ARCH=armv6 KERNCONF=${KERNEL} EMBEDDEDBUILD=1"
		;;
	aarch64)
		MAKE_FLAGS="TARGET=arm64 TARGET_ARCH=aarch64"
		;;
	*)
		return 0
		;;
	esac

	case ${arch} in
	amd64|i386|aarch64)
		MAKE_FLAGS="${MAKE_FLAGS} WITH_VMIMAGES=1 WITH_COMPRESSED_VMIMAGES=1"
		;;
	*)
		;;
	esac

	#cp -p Makefile.mirrors ${CHROOTDIR}/usr/src/release/Makefile.mirrors
	chroot ${CHROOTDIR} make ${MAKE_FLAGS} -C /usr/src/release -f Makefile.mirrors ftp-stage
	return 0
}

mk_fake_imgs() {
	local conf
	conf="${__BUILDCONFDIR}/${rev}-${arch}-${kernel}-${type}.conf"
	[ ! -e "${conf}" ] && return 0
	. "${conf}"
	[ -z "${CHROOTDIR}" ] && return 0

	if [ -d "${CHROOTDIR}/R" ]; then
		rm -rf "${CHROOTDIR}/R"
	fi

	mkdir -p "${CHROOTDIR}/R"

	pfx="FreeBSD-11.0-CURRENT"
	images="bootonly.iso disc1.iso memstick.img mini-memstick.img"

	case ${arch} in
	amd64|i386|powerpc)
		pfx="${pfx}-${arch}"
		;;
	powerpc64)
		pfx="${pfx}-powerpc-${arch}"
		;;
	sparc64)
		pfx="${pfx}-${arch}"
		images="bootonly.iso disc1.iso"
		;;
	armv6)
		sufx="${KERNEL}"
		images="img.xz"
		pfx="${pfx}-arm-${arch}-${sufx}"
		;;
	aarch64)
		images="memstick.img"
		pfx="${pfx}-arm64-aarch64"
		;;
	*)
		return 0
		;;
	esac

	case ${arch} in
	armv6)
		for image in ${images}; do
			echo 1 > "${CHROOTDIR}/R/${pfx}.${image}"
		done
		;;
	*)
		for image in ${images}; do
			echo 1 > "${CHROOTDIR}/R/${pfx}-${image}"
			xz -T0 -k "${CHROOTDIR}/R/${pfx}-${image}"
		done
		;;
	esac

	case ${arch} in
	amd64|i386)
		mkdir -p "${CHROOTDIR}/R/vmimages"
		for vmimage in qcow2 raw vmdk vhd; do
			echo 1 > "${CHROOTDIR}/R/vmimages/FreeBSD-11.0-CURRENT-${arch}.${vmimage}"
			xz -T0 -k "${CHROOTDIR}/R/vmimages/FreeBSD-11.0-CURRENT-${arch}.${vmimage}"
		done
		for csum in SHA512 SHA256; do
			echo 1 > "${CHROOTDIR}/R/vmimages/CHECKSUM.${csum}"
		done
		;;
	aarch64)
		mkdir -p "${CHROOTDIR}/R/vmimages"
		for vmimage in qcow2 raw vmdk vhd; do
			echo 1 > "${CHROOTDIR}/R/vmimages/FreeBSD-11.0-CURRENT-arm64-${arch}.${vmimage}"
			xz -T0 -k "${CHROOTDIR}/R/vmimages/FreeBSD-11.0-CURRENT-arm64-${arch}.${vmimage}"
		done
		for csum in SHA512 SHA256; do
			echo 1 > "${CHROOTDIR}/R/vmimages/CHECKSUM.${csum}"
		done
		;;
	*)
		;;
	esac
	for csum in SHA512 SHA256; do
		echo 1 > "${CHROOTDIR}/R/CHECKSUM.${csum}"
	done

	return 0
}

main() {
	releasesrc="head"
	export __BUILDCONFDIR="$(dirname $(realpath ${0}))"
	[ ! -z "${1}" ] && . "${1}"

	runall mk_fake_imgs
	runall ftp_stage
}

main "$@"

