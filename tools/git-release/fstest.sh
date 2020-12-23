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

source_config() {
	local configfile
	configfile="${scriptdir}/${rev}-${arch}-${kernel}-${type}.conf"
	if [ ! -e "${configfile}" ]; then
	        return 1
	fi
	. "${configfile}"
	return 0
}

mk_dataset() {
	source_config || return 0
	case ${arch} in
		i386)
			_chrootarch="i386"
			;;
		*)
			_chrootarch="amd64"
		;;
	esac
	[ ! -z $(eval echo \${zfs_${_chrootarch}_seed_${rev}_${type}}) ] \
		&& return 0
	_clone="${zfs_parent}/${rev}-${_chrootarch}-worldseed-${type}"
	_mount="/${zfs_mount}/${rev}-${arch}-worldseed-${type}"
	_build="${rev}-${arch}-${kernel}-${type}"
	_dest="${__WRKDIR_PREFIX}/${_build}"
	[ "${debug}" ] && \
		echo "Creating fake ZFS dataset clone \"${_clone}\""
	echo zfs create -o mountpoint="${_mount}" "${_clone}"
	echo zfs snapshot ${_clone}@clone

	[ "${debug}" ] && \
		echo "Cloning ${_chrootarch} world to ${zfs_parent}/${_build}"
	echo zfs clone -p -o atime=off -o mountpoint=${_dest} \
		${_clone}@clone ${zfs_parent}/${_build}
	unset _clone _mount _build _dest
	
	return 0
}

usage() {
	echo "$(realpath $(basename ${0})) -c config"
	echo "$(realpath $(basename ${0})) -c config -d"
	echo "    (debug mode)"
	exit 1
}

main() {
	export __BUILDCONFDIR="$(dirname $(realpath ${0}))"
	while getopts "c:d" opt; do
		case ${opt} in
			c)
				CONF="${OPTARG}"
				[ ! -e ${CONF} ] && usage
				. $(realpath ${CONF})
				;;
			d)
				debug=1
				;;
			\?)
				usage
				;;
		esac
	done
	[ -z "${CONF}" ] && usage

	[ ! -d "${srcdir}/release" ] && \
		git clone -b main ${GITROOT}/${GITSRC} ${srcdir}

	runall mk_dataset

	return 0
}

main "${@}"
