#!/bin/sh
#
# $FreeBSD: scripts/releasebuild.sh 341 2013-10-17 21:34:00Z gjb $
# $relengid$
#

quick_usage() {
	echo "$(basename ${0}) /path/to/configuration/file"
	exit 1
}

if [ "$#" -ne 1 ]; then
	quick_usage
fi

. $(realpath ${1})

info() {
	out="${@}"
	printf "INFO:\t${out}\n" >/dev/stdout
	unset out
}

verbose() {
	if [ -z ${debug} ] || [ ${debug} -eq 0 ]; then
		return 0
	fi
	out="${@}"
	printf "DEBUG:\t${out}\n" >/dev/stdout
	unset out
}

runcmd() {
	verbose "${rev} ${arch} ${type}"
	eval "$@"
}

loop_revs() {
	verbose "loop_revs() start"
	for rev in ${revs}; do
		verbose "loop_revs() arguments: $@"
		eval runcmd "$@"
	done
	unset rev
	verbose "loop_revs() stop"
}

loop_archs() {
	verbose "loop_archs() start"
	for arch in ${archs}; do
		verbose "loop_archs() arguments: $@"
		eval runcmd "$@"
	done
	unset arch
	verbose "loop_archs() stop"
}

loop_types() {
	verbose "loop_types() start"
	for type in ${types}; do
		verbose "loop_types() arguments: $@"
		eval runcmd "$@"
	done
	unset type
	verbose "loop_types() stop"
}

runall() {
	verbose "runall() start"
	verbose "runall() arguments: $@"
	eval loop_revs loop_archs loop_types "$@"
	verbose "runall() stop"
}

check_use_zfs() {
	if [ -z ${use_zfs} ]; then
		return 1
	fi
	return 0
}

source_config() {
	local configfile
	configfile="${scriptdir}/${rev}-${arch}-${type}.conf"
	if [ ! -e "${configfile}" ]; then
		return 1
	fi
	. "${configfile}"
	return 0
}

zfs_mount_tree() {
	source_config || return 0
	_tree=${1}
	[ -z ${_tree} ] && return 0
	seed_src=
	case ${_tree} in
		src)
			seed_src=1
			;;
		doc)
			[ ! -z ${NODOC} ] && return 0
			;;
		ports)
			[ ! -z ${NOPORTS} ] && return 0
			;;
		*)
			info "Unknown source tree type: ${_tree}"
			return 0
			;;
	esac
	_clone="${zfs_parent}/${rev}-${_tree}-${type}"
	_mount="/${zfs_mount}/${rev}-${arch}-${type}"
	_target="${zfs_parent}/${rev}-${arch}-${type}-${_tree}"
	info "Cloning ${_clone}@clone to ${_target}"
	zfs clone -p -o mountpoint=${_mount}/usr/${_tree} \
		${_clone}@clone ${_target}
	if [ ! -z ${seed_src} ]; then
		# Only create chroot seeds for x86.
		if [ "${arch}" = "amd64" ] || [ "${arch}" = "i386" ]; then
			_seedmount=${chroots}/${rev}/${arch}/${type}
			_seedtarget="${zfs_parent}/${rev}-${arch}-${type}-chroot"
			zfs clone -p -o mountpoint=${_seedmount} \
				${_clone}@clone ${_seedtarget}
		fi
	fi
	unset _clone _mount _target _tree _seedmount _seedtarget
}

zfs_create_tree() {
	source_config || return 0
	_tree=${1}
	[ -z ${_tree} ] && return 0
	[ ! -z $(eval echo \${zfs_${_tree}_seed_${rev}_${type}}) ] && return 0
	case ${_tree} in
		src)
			_svnsrc="${SVNROOT}/${SRCBRANCH}"
			;;
		doc)
			[ ! -z ${NODOC} ] && return 0
			_svnsrc="${SVNROOT}/${DOCBRANCH}"
			;;
		ports)
			[ ! -z ${NOPORTS} ] && return 0
			_svnsrc="${SVNROOT}/${PORTBRANCH}"
			;;
		*)
			info "Unknown source tree type: ${_tree}"
			return 0
			;;
	esac
	_clone="${zfs_parent}/${rev}-${_tree}-${type}"
	_mount="/${zfs_mount}/${rev}-${_tree}-${type}"
	info "Creating ${_clone}"
	zfs create -o atime=off -o mountpoint=${_mount} ${_clone}
	info "Source checkout ${_svnsrc} to ${_mount}"
	svn co -q ${_svnsrc} ${_mount}
	info "Creating ZFS snapshot ${_clone}@clone"
	zfs snapshot ${_clone}@clone
	eval zfs_${_tree}_seed_${rev}_${type}=1
	unset _clone _mount _tree _svnsrc
}

zfs_bootstrap() {
	[ -z ${use_zfs} ] && return 0
	runall zfs_create_tree src
	runall zfs_create_tree ports
	runall zfs_create_tree doc
	runall zfs_mount_tree src
	runall zfs_mount_tree ports
	runall zfs_mount_tree doc
	zfs_bootstrap_done=1
}

prebuild_setup() {
	mkdir -p "${logdir}" "${srcdir}"
	svn co -q --force svn://svn.freebsd.org/base/head/release ${srcdir}
	svn revert ${srcdir}/release.sh
	patch ${srcdir}/release.sh < ${scriptdir}/release.sh.diff || exit 1
}

# Clear all log files.
truncate_logs() {
	for log in '.log' '.vm.log' '.world.log'; do
		echo > ${logdir}/${rev}-${arch}-${type}${log}
	done
}

# Email log output when a stage has completed
send_logmail() {
	local _logfile
	local _build
	_logfile="${1}"
	_build="${2}"
	tail -n 10 "${_logfile}" | \
		mail -s "${_build} done" ${emailgoesto}
	return 0
}

# Run the release builds.
build_release() {
	[ ! -e ${scriptdir}/${rev}-${arch}-${type}.conf ] && return 0
	info "Building release: ${rev}-${arch}-${type}"
	printenv > ${logdir}/${rev}-${arch}-${type}.log
	env -i /bin/sh ${srcdir}/release.sh -c ${scriptdir}/${rev}-${arch}-${type}.conf \
		>> ${logdir}/${rev}-${arch}-${type}.log 2>&1

	send_logmail ${logdir}/${rev}-${arch}-${type}.log ${rev}-${arch}-${type}

	# Short circuit to skip vm image creation for non-x86 architectures.
	# Also recreate the memstick.img for i386 while here.
	case ${arch} in
		amd64)
			;;
		i386)
			/bin/sh ${scriptdir}/remake-memstick.sh \
				-c ${scriptdir}/${rev}-${arch}-${type}.conf >> \
				${logdir}/${rev}-${arch}-${type}.log
			;;
		*)
			return 0
			;;
	esac
	info "Building vm image: ${rev}-${arch}-${type}"
	printenv > ${logdir}/${rev}-${arch}-${type}.vm.log
	env -i /bin/sh ${scriptdir}/mk-vmimage.sh -c ${scriptdir}/${rev}-${arch}-${type}.conf \
		>> ${logdir}/${rev}-${arch}-${type}.vm.log 2>&1

	send_logmail ${logdir}/${rev}-${arch}-${type}.vm.log ${rev}-${arch}-${type}
}

check_x86() {
	case ${arch} in
		amd64|i386)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

# Install amd64/i386 "seed" chroots for all branches being built.
install_chroots() {
	source_config || return 0
	if [ ${rev} -le 8 ]; then
		info "This script does not support rev=${rev}"
		return 0
	fi
	case ${arch} in
		i386)
			_chrootarch="i386"
			;;
		*)
			_chrootarch="amd64"
			;;
	esac
	info "Creating ${__WRKDIR_PREFIX}/${rev}-${arch}-${type}"
	mkdir -p "${__WRKDIR_PREFIX}/${rev}-${arch}-${type}"
	info "Installing ${__WRKDIR_PREFIX}/${rev}-${arch}-${type}"
	env MAKEOBJDIRPREFIX=${chroots}/${rev}-obj/${_chrootarch}/${type} \
		make -C ${chroots}/${rev}/${_chrootarch}/${type} \
		TARGET=${_chrootarch} TARGET_ARCH=${_chrootarch} \
		DESTDIR=${__WRKDIR_PREFIX}/${rev}-${arch}-${type} \
		installworld distribution 2>&1 >> \
		${logdir}/${rev}-${arch}-${type}.world.log
}

# Build amd64/i386 "seed" chroots for all branches being built.
build_chroots() {
	source_config || return 0
	if [ ${rev} -le 8 ]; then
		info "This script does not support rev=${rev}"
		return 0
	fi
	# Only build for amd64 and i386.
	check_x86 || return 0
	if [ ${rev} -lt 10 ]; then
		__makecmd="make"
	else
		__makecmd="bmake"
	fi
	case ${arch} in
		i386)
			_chrootarch="i386"
			;;
		amd64)
			_chrootarch="amd64"
			;;
		*)
			# Just to be safe.
			return 0
			;;
	esac
	mkdir -p "${chroots}/${rev}/${_chrootarch}/${type}"
	# Source the build configuration file to get
	# the SRCBRANCH to use
	if [ -z ${zfs_bootstrap_done} ]; then
		# Skip svn checkout, the trees are there.
		info "SVN checkout ${SRCBRANCH} for ${_chrootarch} ${type}"
		svn co -q ${SVNROOT}/${SRCBRANCH} \
			${chroots}/${rev}/${_chrootarch}/${type} \
			2>&1 >> ${logdir}/${rev}-${_chrootarch}-${type}.world.log
	fi
	info "Building ${chroots}/${rev}/${_chrootarch}/${type} make(1)"
	env MAKEOBJDIRPREFIX=${chroots}/${rev}-obj/${_chrootarch}/${type} \
		make -C ${chroots}/${rev}/${_chrootarch}/${type} ${WORLD_FLAGS} \
		TARGET=${_chrootarch} TARGET_ARCH=${_chrootarch} \
		${__makecmd} 2>&1 >> \
		${logdir}/${rev}-${_chrootarch}-${type}.world.log
	info "Building ${chroots}/${rev}/${_chrootarch}/${type} world"
	env MAKEOBJDIRPREFIX=${chroots}/${rev}-obj/${_chrootarch}/${type} \
		make -C ${chroots}/${rev}/${_chrootarch}/${type} ${WORLD_FLAGS} \
		TARGET=${_chrootarch} TARGET_ARCH=${_chrootarch} \
		buildworld 2>&1 >> \
		${logdir}/${rev}-${_chrootarch}-${type}.world.log
}

main() {
	zfs_bootstrap_done=
	zfs_bootstrap
	prebuild_setup
	runall truncate_logs
	runall build_chroots
	runall install_chroots
	runall build_release
}

main
