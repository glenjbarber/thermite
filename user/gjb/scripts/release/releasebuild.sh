#!/bin/sh
#
# $FreeBSD: scripts/releasebuild.sh 341 2013-10-17 21:34:00Z gjb $
# $relengid$
#

emailgoesto="gjb@FreeBSD.org"
scriptdir="$(dirname $(realpath ${0}))"
srcdir="${scriptdir}/../release"
logdir="${scriptdir}/../logs"
chroots="${scriptdir}/../chroots"

heads="11"
stables="10 9"

revs="${heads} ${stables}"
archs="amd64 i386 ia64 powerpc powerpc64 sparc64"
types="snap release"

prebuild_setup() {
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

# Run the release builds.
build_release() {
	echo "=== Building release: ${rev}-${arch}-${type}" > /dev/stdout
	printenv > ${logdir}/${rev}-${arch}-${type}.log
	env -i /bin/sh ${srcdir}/release.sh -c ${scriptdir}/${rev}-${arch}-${type}.conf \
		>> ${logdir}/${rev}-${arch}-${type}.log 2>&1

	tail -n 10 ${logdir}/${rev}-${arch}-${type}.log | \
		mail -s "${rev}-${arch}-${type} done" ${emailgoesto}

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

	tail -n 10 ${logdir}/${rev}-${arch}-${type}.vm.log | \
		mail -s "${rev}-${arch}-${type} vm done" ${emailgoesto}
}

# Build amd64/i386 "seed" chroots for head/.
build_head_chroots() {
	for head in ${heads}; do
		build_head_amd64=0
		build_head_i386=0
		for arch in ${archs}; do
			case ${arch} in
				i386)
					build_head_i386=1
					;;
				*)
					build_head_amd64=1
					;;
			esac
		done
		for type in ${types}; do
			if [ ${build_head_amd64} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${head}-amd64-${type}.conf" ];
				then
					continue
				fi
				mkdir -p "${chroots}/${head}/amd64"
				. "${scriptdir}/${head}-amd64-${type}.conf"
				echo "== Checking out src tree..." \
					2>&1 >> ${logdir}/${head}-amd64-${type}.world.log
				echo "=== SVN checkout base/head for amd64" > /dev/stdout
				svn co -q ${SVNROOT}/base/head@${__SVNREV} \
					${chroots}/${head}/amd64 \
					2>&1 >> ${logdir}/${head}-amd64-${type}.world.log
				echo "=== Building ${chroots}/${head}/amd64" > /dev/stdout
				make -C ${chroots}/${head}/amd64 ${WORLD_FLAGS} \
					TARGET=amd64 TARGET_ARCH=amd64 \
					buildworld \
					2>&1 >> ${logdir}/${head}-amd64-${type}.world.log
			fi
			if [ ${build_head_i386} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${head}-i386-${type}.conf" ];
				then
					continue
				fi
				mkdir -p "${chroots}/${head}/i386"
				. "${scriptdir}/${head}-i386-${type}.conf"
				echo "== Checking out src tree..." \
					2>&1 >> ${logdir}/${head}-i386-${type}.world.log
				echo "=== SVN checkout base/head for i386" > /dev/stdout
				svn co -q ${SVNROOT}/base/head@${__SVNREV} \
					${chroots}/${head}/i386 \
					2>&1 >> ${logdir}/${head}-i386-${type}.world.log
				echo "=== Building ${chroots}/${head}/i386" > /dev/stdout
				make -C ${chroots}/${head}/i386 ${WORLD_FLAGS} \
					TARGET=i386 TARGET_ARCH=i386 \
					buildworld \
					2>&1 >> ${logdir}/${head}-i386-${type}.world.log
			fi
		done
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e "${scriptdir}/${head}-${arch}-${type}.conf" ];
				then
					. "${scriptdir}/${head}-${arch}-${type}.conf"
					mkdir -p ${__WRKDIR_PREFIX}/${head}-${arch}-${type}
					echo "=== Installing ${chroots}/${head}/${arch}" > /dev/stdout
					case ${arch} in
					i386)
						make -C ${chroots}/${head}/i386 \
							TARGET=i386 TARGET_ARCH=i386 \
							DESTDIR=${__WRKDIR_PREFIX}/${head}-${arch}-${type} \
							installworld distribution \
							2>&1 >> ${logdir}/${head}-i386-${type}.world.log
						;;
					*)
						make -C ${chroots}/${head}/amd64 \
							TARGET=amd64 TARGET_ARCH=amd64 \
							DESTDIR=${__WRKDIR_PREFIX}/${head}-${arch}-${type} \
							installworld distribution \
							2>&1 >> ${logdir}/${head}-amd64-${type}.world.log
						;;
					esac
				fi
			done
		done
	done
}

# Build amd64/i386 "seed" chroots for stable/.
build_stable_chroots() {
	if [ "${rev}" -eq 8 ]; then
		echo "== Skipping stable/${rev} builds."
		echo "=== These build scripts do not support stable/${rev}"
		return 0
	fi
	for stable in ${stables}; do
		build_stable_amd64=0
		build_stable_i386=0
		for arch in ${archs}; do
			case ${arch} in
				i386)
					build_stable_i386=1
					;;
				*)
					build_stable_amd64=1
					;;
			esac
		done
		for type in ${types}; do
			if [ ${build_stable_amd64} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${stable}-amd64-${type}.conf" ]; 
				then
					continue
				fi
				mkdir -p "${chroots}/${stable}/amd64"
				. "${scriptdir}/${stable}-amd64-${type}.conf"
				echo "== Checking out src tree..." >/dev/stdout
				svn co -q ${SVNROOT}/base/stable/${stable}@${__SVNREV} \
					${chroots}/${stable}/amd64 \
					2>&1 >> ${logdir}/${stable}-amd64-${type}.world.log
				echo "== Building ${chroots}/${stable}/amd64" >/dev/stdout
				make -C ${chroots}/${stable}/amd64 ${WORLD_FLAGS} \
					TARGET=amd64 TARGET_ARCH=amd64 \
					buildworld \
					2>&1 >> ${logdir}/${stable}-amd64-${type}.world.log
			fi
			if [ ${build_stable_i386} -eq 1 ]; then
				if [ ! -e "${scriptdir}/${stable}-i386-${type}.conf" ]; 
				then
					continue
				fi
				mkdir -p "${chroots}/${stable}/i386"
				. "${scriptdir}/${stable}-i386-${type}.conf"
				echo "== Checking out src tree..." >/dev/stdout
				svn co -q ${SVNROOT}/base/stable/${stable}@${__SVNREV} \
					${chroots}/${stable}/i386 \
					2>&1 >> ${logdir}/${stable}-i386-${type}.world.log
				echo "== Building ${chroots}/${stable}/i386" >/dev/stdout
				make -C ${chroots}/${stable}/i386 ${WORLD_FLAGS} \
					TARGET=i386 TARGET_ARCH=i386 \
					buildworld \
					2>&1 >> ${logdir}/${stable}-i386-${type}.world.log
			fi
		done
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e "${scriptdir}/${stable}-${arch}-${type}.conf" ];
				then
					. "${scriptdir}/${stable}-${arch}-${type}.conf"
					mkdir -p ${__WRKDIR_PREFIX}/${stable}-${arch}-${type}
					echo "== Installing ${chroots}/${stable}/${arch}" >/dev/stdout
					case ${arch} in
					i386)
						make -C ${chroots}/${stable}/i386 \
							TARGET=i386 TARGET_ARCH=i386 \
							DESTDIR=${__WRKDIR_PREFIX}/${stable}-${arch}-${type} \
							installworld distribution \
							2>&1 >> ${logdir}/${stable}-i386-${type}.world.log
						;;
					*)
						make -C ${chroots}/${stable}/amd64 \
							TARGET=amd64 TARGET_ARCH=amd64 \
							DESTDIR=${__WRKDIR_PREFIX}/${stable}-${arch}-${type} \
							installworld distribution \
							2>&1 >> ${logdir}/${stable}-amd64-${type}.world.log
						;;
					esac
				fi
			done
		done
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
	if [ ${build_heads} -eq 1 ]; then
		build_head_chroots
	fi
	if [ ${build_stables} -eq 1 ]; then
		build_stable_chroots
	fi
}

main() {
	prebuild_setup
	truncate_logs
	build_chroots
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
