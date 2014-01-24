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
	out="${1}"
	printf "INFO:\t${out}\n" >/dev/stdout
	unset out
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
	echo "=== Building release: ${rev}-${arch}-${type}" > /dev/stdout
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
	echo "=== Building vm image: ${rev}-${arch}-${type}" > /dev/stdout
	printenv > ${logdir}/${rev}-${arch}-${type}.vm.log
	env -i /bin/sh ${scriptdir}/mk-vmimage.sh -c ${scriptdir}/${rev}-${arch}-${type}.conf \
		>> ${logdir}/${rev}-${arch}-${type}.vm.log 2>&1

	send_logmail ${logdir}/${rev}-${arch}-${type}.vm.log ${rev}-${arch}-${type}
}

# Install amd64/i386 "seed" chroots for all branches being built.
install_chroots() {
	for _rev in ${heads} ${stables}; do
		if [ ${_rev} -le 8 ]; then
			echo -n "==== Skipping ${_rev}; these scripts do not "
			echo "support stable/8 or earlier." >/dev/stdout
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
					echo "=== Installing ${chroots}/${_rev}/${arch}" > /dev/stdout
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
			echo -n "==== Skipping ${_rev}; these scripts do not "
			echo "support stable/8 or earlier." >/dev/stdout
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
				echo "=== SVN checkout ${SRCBRANCH} for amd64" > /dev/stdout
				svn co -q ${SVNROOT}/${SRCBRANCH} \
					${chroots}/${_rev}/amd64 \
					2>&1 >> ${logdir}/${_rev}-amd64-${type}.world.log
				echo "=== Building ${chroots}/${_rev}/amd64 make(1)" > \
					/dev/stdout
				env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/amd64 \
					make -C ${chroots}/${_rev}/amd64 ${WORLD_FLAGS} \
					TARGET=amd64 TARGET_ARCH=amd64 \
					${__makecmd} \
					2>&1 >> \
					${logdir}/${_rev}-amd64-${type}.world.log
				echo "=== Building ${chroots}/${_rev}/amd64 world" > \
					/dev/stdout
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
				echo "=== SVN checkout ${SRCBRANCH} for i386" > /dev/stdout
				svn co -q ${SVNROOT}/${SRCBRANCH} \
					${chroots}/${_rev}/i386 \
					2>&1 >> ${logdir}/${_rev}-i386-${type}.world.log
				echo "=== Building ${chroots}/${_rev}/i386 make(1)" > /dev/stdout
				env MAKEOBJDIRPREFIX=${chroots}/${_rev}-obj/i386 \
					make -C ${chroots}/${_rev}/i386 ${WORLD_FLAGS} \
					TARGET=i386 TARGET_ARCH=i386 \
					${__makecmd} \
					2>&1 >> \
					${logdir}/${_rev}-i386-${type}.world.log
				echo "=== Building ${chroots}/${_rev}/i386 world" > /dev/stdout
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
					echo "=== Skipping build: ${rev}-${arch}-${type}"
					echo "=== Configuration file does not exist."
				fi
			done
		done
	done
}

main
