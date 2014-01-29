#!/bin/sh
#
# $relengid$
#

quick_usage() {
	echo "$(basename ${0}) /path/to/configuration/file"
	exit 1
}

if [ "$#" -ne 1 ]; then
	quick_usage
fi

. $(dirname $(basename ${0}))/${1}

get_vm_checksum() {
	local _s="${r}-${a}-${k}-${t}"
	sumfiles="SHA256 MD5"
	if [ -e ${scriptdir}/${_s}.conf ]; then
		. ${scriptdir}/${_s}.conf
	else
		return 0
	fi
	if [ ! -e ${CHROOTDIR}/vmimage/ ]; then
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
		cat ${CHROOTDIR}/vmimage/CHECKSUM.${_f}* | \
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
	for _f in ${sumfiles}; do
		case ${_f} in
			SHA256)
				echo "o ${__REVISION}-${__BRANCH} ${a} ${k}:"
				;;
			*)
				;;
		esac
		cat ${CHROOTDIR}/R/CHECKSUM.${_f}* | \
			sed -e 's/^/        /'
		echo
	done
	echo
	return 0
}

main() {
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
					amd64|i386)
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

main

