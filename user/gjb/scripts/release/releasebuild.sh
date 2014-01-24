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

zfs_ports_seed() {
	source_config || return 0
	# zfs create -o atime=off ${zfs_parent}/${rev}-ports-${type}
	# svn co -q ${SVNROOT}/${PORTBRANCH} ${zfs_mount}/${rev}-ports-${type}
	# zfs snapshot ${zfs_parent}/${rev}-ports-${type}@clone
	# zfs clone -p -o mountpoint=${zfs_mount}/${rev}-${arch}-${type}/usr/ports \
		# ${zfs_parent}/${rev}-ports-${type}@clone \
		# ${zfs_parent}/${rev}-${arch}-${type}-ports
}

zfs_doc_seed() {
	source_config || return 0
	# zfs create -o atime=off ${zfs_parent}/${rev}-doc-${type}
	# svn co -q ${SVNROOT}/${DOCBRANCH} ${zfs_mount}/${rev}-doc-${type}
	# zfs snapshot ${zfs_parent}/${rev}-doc-${type}@clone
	# zfs clone -p -o mountpoint=${zfs_mount}/${rev}-${arch}-${type}/usr/doc \
		# ${zfs_parent}/${rev}-doc-${type}@clone \
		# ${zfs_parent}/${rev}-${arch}-${type}-doc
}

zfs_src_seed() {
	source_config || return 0
	# zfs create -o atime=off ${zfs_parent}/${rev}-src-${type}
	# svn co -q ${SVNROOT}/${SRCBRANCH} ${zfs_mount}/${rev}-src-${type}
	# zfs snapshot ${zfs_parent}/${rev}-src-${type}@clone
	# zfs clone -p -o mountpoint=${zfs_mount}/${rev}-${arch}-${type}/usr/src \
		# ${zfs_parent}/${rev}-src-${type}@clone \
		# ${zfs_parent}/${rev}-${arch}-${type}-src
}

prebuild_setup() {
	mkdir -p "${logdir}" "${srcdir}"
	svn co -q --force svn://svn.freebsd.org/base/head/release ${srcdir}
	svn revert ${srcdir}/release.sh
	patch ${srcdir}/release.sh < ${scriptdir}/release.sh.diff || exit 1
}

# Clear all log files.
truncate_logs() {
	for rev in ${revs}; do
		for arch in ${archs}; do
			for type in ${types}; do
				for log in '.log' '.vm.log' '.world.log'; do
					echo > ${logdir}/${rev}-${arch}-${type}${log}
				done
			done
		done
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

# Install amd64/i386 "seed" chroots for all branches being built.
install_chroots() {
	for _rev in ${heads} ${stables}; do
		if [ ${_rev} -le 8 ]; then
			info "Skipping ${_rev}; these scripts do not support stable/8 or earlier."
			break
		fi
		build_amd64=0
		build_i386=0
		for arch in ${archs}; do
			case ${arch} in
				i386)
					build_i386=1
					;;
				*)
					build_amd64=1
					;;
			esac
		done
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e "${scriptdir}/${_rev}-${arch}-${type}.conf" ];
				then
					. "${scriptdir}/${_rev}-${arch}-${type}.conf"
					mkdir -p ${__WRKDIR_PREFIX}/${_rev}-${arch}-${type}
					info "Installing ${chroots}/${_rev}/${arch}"
					case ${arch} in
					i386)
						_arch=i386
						;;
					*)
						_arch=amd64
						;;
					esac
					env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/${_arch} \
						make -C ${chroots}/${_rev}/${_arch} \
						TARGET=${_arch} TARGET_ARCH=${_arch} \
						DESTDIR=${__WRKDIR_PREFIX}/${_rev}-${arch}-${type} \
						installworld distribution \
						2>&1 >> \
						${logdir}/${_rev}-${_arch}-${type}.world.log
				fi
			done
		done
	done
}

# Build amd64/i386 "seed" chroots for all branches being built.
build_chroots() {
	for _rev in ${heads} ${stables}; do
		if [ ${_rev} -le 8 ]; then
			info "Skipping ${_rev}; these scripts do not support stable/8 or earlier."
			break
		fi
		build_amd64=0
		build_i386=0
		for arch in ${archs}; do
			case ${arch} in
				i386)
					build_i386=1
					;;
				*)
					build_amd64=1
					;;
			esac
		done
		for type in ${types}; do
			if [ ${_rev} -lt 10 ]; then
				__makecmd="make"
			else
				__makecmd="bmake"
			fi
			if [ ${build_amd64} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${_rev}-amd64-${type}.conf" ];
				then
					continue
				fi
				mkdir -p "${chroots}/${_rev}/amd64"
				# Source the build configuration file to get
				# the SRCBRANCH to use
				. "${scriptdir}/${_rev}-amd64-${type}.conf"
				info "SVN checkout ${SRCBRANCH} for amd64"
				svn co -q ${SVNROOT}/${SRCBRANCH} \
					${chroots}/${_rev}/amd64 \
					2>&1 >> ${logdir}/${_rev}-amd64-${type}.world.log
				info "Building ${chroots}/${_rev}/amd64 make(1)"
				env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/amd64 \
					make -C ${chroots}/${_rev}/amd64 ${WORLD_FLAGS} \
					TARGET=amd64 TARGET_ARCH=amd64 \
					${__makecmd} \
					2>&1 >> \
					${logdir}/${_rev}-amd64-${type}.world.log
				info "Building ${chroots}/${_rev}/amd64 world"
				env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/amd64 \
					make -C ${chroots}/${_rev}/amd64 ${WORLD_FLAGS} \
					TARGET=amd64 TARGET_ARCH=amd64 \
					buildworld \
					2>&1 >> \
					${logdir}/${_rev}-amd64-${type}.world.log
			fi
			if [ ${build_i386} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${_rev}-i386-${type}.conf" ];
				then
					continue
				fi
				mkdir -p "${chroots}/${_rev}/i386"
				# Source the build configuration file to get
				# the SRCBRANCH to use
				. "${scriptdir}/${_rev}-i386-${type}.conf"
				info "SVN checkout ${SRCBRANCH} for i386"
				svn co -q ${SVNROOT}/${SRCBRANCH} \
					${chroots}/${_rev}/i386 \
					2>&1 >> ${logdir}/${_rev}-i386-${type}.world.log
				info "Building ${chroots}/${_rev}/i386 make(1)"
				env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/i386 \
					make -C ${chroots}/${_rev}/i386 ${WORLD_FLAGS} \
					TARGET=i386 TARGET_ARCH=i386 \
					${__makecmd} \
					2>&1 >> \
					${logdir}/${_rev}-i386-${type}.world.log
				info "Building ${chroots}/${_rev}/i386 world"
				env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/i386 \
					make -C ${chroots}/${_rev}/i386 ${WORLD_FLAGS} \
					TARGET=i386 TARGET_ARCH=i386 \
					buildworld \
					2>&1 >> \
					${logdir}/${_rev}-i386-${type}.world.log
			fi
		done
	done
}

main() {
	prebuild_setup
	truncate_logs
	build_chroots
	install_chroots
	for rev in ${revs}; do
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e ${scriptdir}/${rev}-${arch}-${type}.conf ]; then
					build_release
				else
					info "Skipping build: ${rev}-${arch}-${type}, missing configuration file."
				fi
			done
		done
	done
}

main
