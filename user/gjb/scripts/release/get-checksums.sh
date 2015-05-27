#!/bin/sh
#
# $FreeBSD$
#

usage() {
	echo "$(basename ${0}) -c /path/to/configuration/file"
	exit 1
}

get_vm_checksum() {
	local _s="${r}-${a}-${k}-${t}"
	sumfiles="SHA256 MD5"
	if [ -e ${scriptdir}/${_s}.conf ]; then
		. ${scriptdir}/${_s}.conf
	else
		return 0
	fi
	if [ ! -e "${CHROOTDIR}/R/ftp-stage/VM-IMAGES" ]; then
		return 0
	fi
	__REVISION=$(make -C ${CHROOTDIR}/usr/src/release -V REVISION)
	__BRANCH=$(make -C ${CHROOTDIR}/usr/src/release -V BRANCH)
	for _f in ${sumfiles}; do
		case ${_f} in
			SHA256)
				echo "o ${__REVISION}-${__BRANCH} ${a}:"
				;;
			*)
				;;
		esac
		cat ${CHROOTDIR}/R/ftp-stage/VM-IMAGES/${__REVISION}/${__BRANCH}/${TARGET_ARCH}/CHECKSUM.${_f}* | \
			sed -e 's/^/        /'
		echo
	done
	echo
	return 0
}


get_iso_checksum() {
	local _s="${r}-${a}-${k}-${t}"
	sumfiles="SHA256 MD5"
	if [ -e ${scriptdir}/${_s}.conf ]; then
		. ${scriptdir}/${_s}.conf
	else
		return 0
	fi
	if [ ! -e ${CHROOTDIR}/R/ ]; then
		return 0
	fi
	__REVISION=$(make -C ${CHROOTDIR}/usr/src/release -V REVISION)
	__BRANCH=$(make -C ${CHROOTDIR}/usr/src/release -V BRANCH)
	if [ ! -z "${EMBEDDEDBUILD}" ]; then
		TARGET="${EMBEDDED_TARGET}"
		TARGET_ARCH="${EMBEDDED_TARGET_ARCH}"
	fi
	for _f in ${sumfiles}; do
		case ${_f} in
			SHA256)
				echo "o ${__REVISION}-${__BRANCH} ${a} ${k}:"
				;;
			*)
				;;
		esac
		cat ${CHROOTDIR}/R/ftp-stage/${TARGET}/${TARGET_ARCH}/CHECKSUM.${_f}* | \
			sed -e 's/^/        /'
		echo
	done
	unset EMBEDDEDBUILD
	echo
	return 0
}

main() {
	export __BUILDCONFDIR="$(dirname $(realpath ${0}))"
	CSCONF=

	while getopts "c:" opt; do
		case ${opt} in
			c)
				CSCONF="${OPTARG}"
				;;
			*)
				;;
		esac
	done

	if [ -z "${CSCONF}" ]; then
		echo "Build configuration file is required."
		usage
	fi

	CSCONF="$(realpath ${CSCONF})"

	if [ ! -f "${CSCONF}" ]; then
		echo "Build configuration is not a regular file."
		exit 1
	fi

	. "${CSCONF}"

	echo "== ISO CHECKSUMS =="
	echo
	for r in ${revs}; do
		for a in ${archs}; do
			for k in ${kernels}; do
			for t in ${types}; do
				get_iso_checksum
			done
			done
		done
	done
	echo "== VM IMAGE CHECKSUMS =="
	echo
	for r in ${revs}; do
		for a in ${archs}; do
			for k in ${kernels}; do
			for t in ${types}; do
				case ${a} in
					amd64|i386|aarch64)
						get_vm_checksum
						;;
					*)
					;;
				esac
			done
			done
		done
	done
}

main "$@"
