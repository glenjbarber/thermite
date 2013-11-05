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

. $(dirname $(basename ${0}))/${1}

prebuild_setup() {
	sh ${scriptdir}/getrev.sh || exit 1
	mkdir -p "${logdir}" "${srcdir}"
	svn co -q --force svn://svn.freebsd.org/base/head/release ${srcdir}
	svn revert ${srcdir}/release.sh
	patch ${srcdir}/release.sh < ${scriptdir}/release.sh.diff || exit 1

	# Remove the release.sh 'buildworld/installworld/distribution' functionality;
	# it is short-circuited in build_chroots() to run once per branch (twice, if
	# amd64 and i386 are built), instead of one buildworld per architecture.
	sed -i '' 's:^cd ${CHROOTDIR}/usr/src:# REMOVED1:' ${srcdir}/release.sh
	sed -i '' 's:^make ${CHROOT_WMAKEFLAGS} buildworld:# REMOVED2:' \
		${srcdir}/release.sh
	sed -i '' 's:^make ${CHROOT_IMAKEFLAGS} installworld DESTDIR=${CHROOTDIR}:# REMOVED3:' \
		${srcdir}/release.sh
	sed -i '' 's:^make ${CHROOT_DMAKEFLAGS} distribution DESTDIR=${CHROOTDIR}:# REMOVED4:' \
		${srcdir}/release.sh
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
		>> ${logdir}/${rev}-${arch}-${type}.log 2>&1 &

	wait
	send_logmail ${logdir}/${rev}-${arch}-${type}.log ${rev}-${arch}-${type}

	# Short circuit to skip vm image creation for non-x86 architectures.
	case ${arch} in
		amd64|i386)
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

# Build amd64/i386 "seed" chroots for all branches being built.
realbuild_chroots() {
	for _rev in ${heads} ${stables}; do
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
			if [ ${build_amd64} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${_rev}-amd64-${type}.conf" ];
				then
					continue
				fi
				mkdir -p "${chroots}/${_rev}/amd64"
				. "${scriptdir}/${_rev}-amd64-${type}.conf"
				# Source the build configuration file to get
				# the SRCBRANCH to use
				echo "=== SVN checkout ${SRCBRANCH} for amd64" > /dev/stdout
				. "${scriptdir}/${_rev}-amd64-${type}.conf"
				svn co -q ${SVNROOT}/${SRCBRANCH} \
					${chroots}/${_rev}/amd64 \
					2>&1 >> ${logdir}/${_rev}-amd64-${type}.world.log
				echo "=== Building ${chroots}/${_rev}/amd64" > /dev/stdout
				make -C ${chroots}/${_rev}/amd64 ${WORLD_FLAGS} \
					TARGET=amd64 TARGET_ARCH=amd64 \
					buildworld \
					2>&1 >> \
					${logdir}/${_rev}-amd64-${type}.world.log &
			fi
			if [ ${build_i386} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${_rev}-i386-${type}.conf" ];
				then
					continue
				fi
				mkdir -p "${chroots}/${_rev}/i386"
				. "${scriptdir}/${_rev}-i386-${type}.conf"
				# Source the build configuration file to get
				# the SRCBRANCH to use
				. "${scriptdir}/${_rev}-i386-${type}.conf"
				echo "=== SVN checkout ${SRCBRANCH} for i386" > /dev/stdout
				svn co -q ${SVNROOT}/${SRCBRANCH} \
					${chroots}/${_rev}/i386 \
					2>&1 >> ${logdir}/${_rev}-i386-${type}.world.log
				echo "=== Building ${chroots}/${_rev}/i386" > /dev/stdout
				make -C ${chroots}/${_rev}/i386 ${WORLD_FLAGS} \
					TARGET=i386 TARGET_ARCH=i386 \
					buildworld \
					2>&1 >> \
					${logdir}/${_rev}-i386-${type}.world.log &
			fi
		done
		wait
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e "${scriptdir}/${_rev}-${arch}-${type}.conf" ];
				then
					. "${scriptdir}/${_rev}-${arch}-${type}.conf"
					mkdir -p ${__WRKDIR_PREFIX}/${_rev}-${arch}-${type}
					echo "=== Installing ${chroots}/${_rev}/${arch}" > /dev/stdout
					case ${arch} in
					i386)
						make -C ${chroots}/${_rev}/i386 \
							TARGET=i386 TARGET_ARCH=i386 \
							DESTDIR=${__WRKDIR_PREFIX}/${_rev}-${arch}-${type} \
							installworld distribution \
							2>&1 >> \
							${logdir}/${_rev}-i386-${type}.world.log &
						;;
					*)
						make -C ${chroots}/${_rev}/amd64 \
							TARGET=amd64 TARGET_ARCH=amd64 \
							DESTDIR=${__WRKDIR_PREFIX}/${_rev}-${arch}-${type} \
							installworld distribution \
							2>&1 >> \
							${logdir}/${_rev}-amd64-${type}.world.log &
						;;
					esac
				fi
			done
		done
		wait
	done
}

build_chroots() {
	build_heads=0
	build_stables=0
	# set a flag if we are going to build head/ and stable/ bits (i.e.,
	# check for branches that are excluded from this build)
	if [ "x${heads}" != "x" ]; then
		build_heads=1
	fi
	if [ "x${stables}" != "x" ]; then
		build_stables=1
	fi
	if [ ${build_heads} -eq 1 ] || [ ${build_stables} -eq 1 ]; then
		realbuild_chroots
	fi
}

main() {
	prebuild_setup
	truncate_logs
	build_chroots
	wait
	for rev in ${revs}; do
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e ${scriptdir}/${rev}-${arch}-${type}.conf ]; then
					build_release
					case ${arch} in
						i386)
							/bin/sh ${scriptdir}/remake-memstick.sh \
								-c ${scriptdir}/${rev}-${arch}-${type}.conf
							;;
						*)
							;;
					esac
				else
					echo "=== Skipping build: ${rev}-${arch}-${type}"
					echo "=== Configuration file does not exist."
				fi
			done
		done
	done
}

main
