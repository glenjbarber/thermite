#!/bin/sh
#
# $FreeBSD: scripts/ftp-stage.sh 334 2013-10-17 21:04:30Z gjb $
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

case `hostname -s` in
	snap)
		relengdir="/snap/releng"
		;;
	bake | cook)
		relengdir="/releng"
		;;
	*)
		echo "relengdir not set"
		exit 1
		;;
esac

setup_stageenv() {
	path=
	C=
	isoarch=
	backpath=
	skip=0
	vmimages="qcow2 vmdk"
	REVISION=
	BRANCH=
	OSRELEASE=
	__DATE=
	__SVNREV=

	C="${relengdir}/${rev}-${arch}-${type}"

	if [ ! -d ${C} ]; then
		echo "=== Directory ${C} not found"
		return 0
	fi

	if [ ! -d ${C}/usr/src/release ]; then
		echo "=== Cannot find release directory for ${rev}-${arch}-${type}"
		echo "=== Unable to determine OSRELEASE value."
		skip=1
		return 0
	fi

	# Overrides for paths, image files, etc.
	case ${arch} in
		sparc64)
			isoarch="${arch}"
			path="${arch}/${arch}"
			backpath="${arch}"
			;;
		powerpc64)
			isoarch="powerpc-powerpc64"
			path="powerpc/powerpc64"
			;;
		pc98)
			isoarch="pc98"
			path="pc98/i386"
			;;
		*)
			isoarch="${arch}"
			path="${arch}/${arch}"
			backpath="${arch}"
			;;
	esac

	# Set the ftp subdir to releases/ or snapshots/:
	case ${type} in
		snap)
			ftpsubdir="snapshots"
			;;
		release)
			ftpsubdir="releases"
			;;
		*)
			ftpsubdir=""
			;;
	esac

	REVISION=$(make -C ${C}/usr/src/release -V REVISION)
	BRANCH=$(make -C ${C}/usr/src/release -V BRANCH)
	OSRELEASE="${REVISION}-${BRANCH}"
	__DATE="${BUILDDATE}"
	__SVNREV="r${BUILDSVNREV}"
	releaseimages="$(make -C ${C}/usr/src/release -V IMAGES)"

	if [ "X${OSRELEASE}" = "X" ]; then
		skip=1
	fi

	. "${scriptdir}/${rev}-${arch}-${type}.conf"
	if [ "X${TARGET}" = "X" ] && [ "X${TARGET_ARCH}" = "X" ]; then
		TARGET=$(uname -m)
		TARGET_ARCH=$(uname -p)
	fi
	__DISCNAME="$(make -C ${C}/usr/src/release TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH} -V OSRELEASE)"
}

stage_builds() {
	setup_stageenv
	local _ftpdir
	_ftpdir="${ftpdir}/${ftpsubdir}"
	if [ "${skip}" -eq 1 ]; then
		echo "=== Skipping ${rev}-${arch}-${type} staging"
		return 0
	fi
	if [ ! -d ${C}/R ]; then
		echo "=== Skipping ${rev}-${arch}-${type} staging"
		echo "==== ${C}/R directory does not exist"
		return 0
	fi
	echo "=== Creating ${_ftpdir}/${path}/${OSRELEASE}..."
	mkdir -p ${_ftpdir}/${path}/${OSRELEASE}/
	if [ ! -z ${backpath} ]; then
		echo "=== Creating backwards-compatible symlink:"
		echo "==== ${backpath}/${OSRELEASE} -> ${path}/${OSRELEASE}"
		ln -sf ${backpath}/${OSRELEASE} ${_ftpdir}/${backpath}/${OSRELEASE}
	fi
	echo "=== Rsync ${C}/R/ftp to ${_ftpdir}/${path}/${OSRELEASE}..."
	rsync -a --delete ${C}/R/ftp/* \
		${_ftpdir}/${path}/${OSRELEASE}/

	# Copy ISO images to FTP snapshots directory.
	echo "=== Creating ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}..."
	mkdir -p ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}/
	case ${type} in
		snap)
			(
				cd ${C}/R
				for _i in ${releaseimages}; do
					echo -n "=== Renaming ${_i} to "
					echo "${__DISCNAME}-${__DATE}-${__SVNREV}-${_i}"
					mv *-${_i} \
						${__DISCNAME}-${__DATE}-${__SVNREV}-${_i}
				done
				rm -f CHECKSUM.SHA256* CHECKSUM.MD5*
				echo "=== Generating SHA256 checksums"
				sha256 ${__DISCNAME}* > \
					${C}/R/CHECKSUM.SHA256-${__DATE}-${__SVNREV}
				echo "=== Generating MD5 checksums"
				md5 ${__DISCNAME}* > \
					${C}/R/CHECKSUM.MD5-${__DATE}-${__SVNREV}
			)
			;;
		*)
			;;
	esac
	echo "=== Copying checksums and images to ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}..."
	cp -p ${C}/R/*CHECKSUM* ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}/
	cp -p ${C}/R/${__DISCNAME}* ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}/

	echo "=== Creating ${_ftpdir}/ISO-IMAGES/${REVISION}..."
	mkdir -p ${_ftpdir}/ISO-IMAGES/${REVISION}
	echo "=== Creating symlinks for ISO-IMAGES..."
	for image in ${releaseimages}; do
		if [ -e "${C}/R/FreeBSD-${OSRELEASE}-${isoarch}-${image}" ]; then
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/FreeBSD-${OSRELEASE}-${isoarch}-${image} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/FreeBSD-${OSRELEASE}-${isoarch}-${image}
		elif [ -e "${C}/R/${__DISCNAME}-${__DATE}-${__SVNREV}-${image}" ]; then
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/${__DISCNAME}-${__DATE}-${__SVNREV}-${image} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/${__DISCNAME}-${__DATE}-${__SVNREV}-${image}
		fi
	done
	echo "=== Creating symlinks for CHECKSUM files..."
	for hash in MD5 SHA256; do
		if [ -e "${C}/R/CHECKSUM.${hash}" ]; then
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash}-${OSRELEASE}-${isoarch}
		elif [ -e "${C}/R/CHECKSUM.${hash}-${__DATE}-${__SVNREV}" ]; then
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash}-${__DATE}-${__SVNREV} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash}-${OSRELEASE}-${isoarch}-${__DATE}-${__SVNREV}
		fi
	done
	case ${BRANCH} in
		RELEASE|RC)
			echo "=== This is a RELEASE or RC."
			echo "=== Creating packages symlink for sysinstall(8)..."
			ln -sf ../../../../ports/${isoarch}/packages-${REVISION}-release \
				${_ftpdir}/${path}/${OSRELEASE}/packages
			;;
		*)
			# FALLTHROUGH
			;;
	esac
	return 0
}

stage_vmimages() {
	setup_stageenv
	if [ "${skip}" -eq 1 ] || [ ! -d ${C}/vmimage ]; then
		echo "=== Skipping ${rev}-${arch}-${type} staging"
		return 0
	fi
	FTPPATH="${ftpdir}/snapshots/VM-IMAGES/${OSRELEASE}/${arch}/${__DATE}"
	LATESTPATH="${ftpdir}/snapshots/VM-IMAGES/${OSRELEASE}/${arch}/Latest"
	mkdir -p ${FTPPATH}
	if [ -e "${C}/vmimage/${__DISCNAME}.disk" ]; then
		# Hide the raw '.disk' file by renaming to a dot-file.
		mv "${C}/vmimage/${__DISCNAME}.disk" "${C}/vmimage/.${__DISCNAME}.disk"
	fi
	for image in ${vmimages}; do
		mv ${C}/vmimage/${__DISCNAME}*.${image}.xz \
			${C}/vmimage/${__DISCNAME}-${__DATE}-${__SVNREV}.${image}.xz
	done
	# Remove old checksums.
	rm -f ${C}/vmimage/CHECKSUM.*
	(cd ${C}/vmimage &&
		sha256 ${__DISCNAME}* \
			> CHECKSUM.SHA256-${__DATE}-${__SVNREV}
		md5 ${__DISCNAME}* \
			> CHECKSUM.MD5-${__DATE}-${__SVNREV}
	)
	cp -p ${C}/vmimage/CHECKSUM* \
		${FTPPATH}

	for image in ${vmimages}; do
		cp -p ${C}/vmimage/${__DISCNAME}*.${image}.xz \
			${FTPPATH}
	done
	unlink ${LATESTPATH}
	ln -sf ${__DATE} ${LATESTPATH}
	return 0
}

dirperm_fixup() {
	cd ${ftpdir}
	echo "=== Setting correct directory permissions for ftp-master..."
	find . -type d | xargs chmod 775
	return 0
}

main() {
	for rev in ${revs}; do
		for arch in ${archs}; do
			for type in ${types}; do
				if [ -e ${scriptdir}/${rev}-${arch}-${type}.conf ]; then
					echo "== Staging Release: ${rev}-${arch}-${type}"
					stage_builds
					case ${arch} in
						i386|amd64)
							echo "== Staging VM Images: ${rev}-${arch}-${type}"
							stage_vmimages
							;;
						*)
							;;
					esac
				fi
			done
		done
	done
	dirperm_fixup
	#echo "== For snapshots, run: rsync -av --links ${ftpdir}/ /snap/ftp/snapshots"
	#echo -n "== For releases, run 'rsync -av --delete --links "
	#echo "${ftpdir}/ ftp-master.freebsd.org:/archive/tmp/releases'"
}

main
