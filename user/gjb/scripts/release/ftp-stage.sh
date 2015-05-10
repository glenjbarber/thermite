#!/bin/sh
#
# $FreeBSD$
#

usage() {
	echo "$(basename ${0}) -c /path/to/configuration/file"
	exit 1
}

setup_stageenv() {
	export FTP_STAGING=1
	path=
	C=
	isoarch=
	backpath=
	skip=0
	WITH_DVD=
	REVISION=
	BRANCH=
	OSRELEASE=
	BOARDNAME=
	__DATE=
	__SVNREV=

	C="${relengdir}/${rev}-${arch}-${kernel}-${type}"

	if [ ! -d ${C} ]; then
		echo "=== Directory ${C} not found"
		return 0
	fi

	if [ ! -d ${C}/usr/src/release ]; then
		echo "=== Cannot find release directory for ${rev}-${arch}-${kernel}-${type}"
		echo "=== Unable to determine OSRELEASE value."
		skip=1
		return 0
	fi

	# Overrides for paths, image files, etc.
	case ${arch} in
		armv6)
			isoarch="arm-armv6"
			path="arm/armv6"
			;;
		aarch64)
			isoarch="arm64-aarch64"
			path="arm64/aarch64"
			;;
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

	REVISION=$(make -C ${C}/usr/src/release -V REVISION)
	BRANCH=$(make -C ${C}/usr/src/release -V BRANCH)
	VMIMAGES="$(make -C ${C}/usr/src/release -V VMFORMATS)"
	OSRELEASE="${REVISION}-${BRANCH}"
	__DATE="${BUILDDATE}"
	__SVNREV="r${BUILDSVNREV}"

	if [ "X${OSRELEASE}" = "X" ]; then
		skip=1
	fi

	. "${scriptdir}/${rev}-${arch}-${kernel}-${type}.conf"
	case ${arch} in
		armv6)
			case ${rev} in
				11)
					TARGET="${EMBEDDED_TARGET}"
					TARGET_ARCH="${EMBEDDED_TARGET_ARCH}"
					;;
				*)
					TARGET="${XDEV_ARCH}"
					TARGET_ARCH="${XDEV_ARCH}"
					;;
			esac
			;;
		*)
			releaseimages="$(make -C ${C}/usr/src/release WITH_DVD=${WITH_DVD} -V IMAGES)"
			if [ "X${TARGET}" = "X" ] && [ "X${TARGET_ARCH}" = "X" ]; then
				TARGET=$(uname -m)
				TARGET_ARCH=$(uname -p)
			fi
			;;
	esac
	case ${kernel} in
		VT)
			releaseimages="${releaseimages} uefi-memstick.img"
			;;
		*)
			;;
	esac
	case ${rev} in
		10)
			releaseimages="${releaseimages} uefi-memstick.img"
			;;
		*)
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
			ftpsubdir="snapshots"
			;;
	esac

	__DISCNAME="$(make -C ${C}/usr/src/release TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH} -V OSRELEASE)"
}

stage_isos() {
	if [ "X${arch}" != "Xarmv6" ]; then
		case ${kernel} in
			GENERIC*)
				echo "=== Rsync ${C}/R/ftp to ${_ftpdir}/${path}/${OSRELEASE}..."
				rsync -a --delete ${C}/R/ftp/* \
					${_ftpdir}/${path}/${OSRELEASE}/
				;;
			*)
				;;
		esac
	fi

	# FreeBSD-11.0-CURRENT-amd64
	oldname="${__DISCNAME}"
	newname="${oldname}"
	case ${kernel} in
		GENERIC*)
			;;
		*)
			# FreeBSD-11.0-CURRENT-amd64-VT
			newname="${newname}-${kernel}"
			;;
	esac
	case ${type} in
		snap)
			# FreeBSD-11.0-CURRENT-20140127-r261200
			snapsuffix="-${__DATE}-${__SVNREV}"
			newname="${oldname}${snapsuffix}"
			;;
		*)
			;;
	esac

	# If the resulting image name has changed (non-GENERIC kernel, or this
	# is a snapshot build, rename the ISOs, and regenerate the hashes.
	if [ "X${newname}${snapsuffix}" != "X${oldname}" ]; then
		cd ${C}/R
		if [ "X${arch}" != "Xarmv6" ]; then
			for _i in ${releaseimages}; do
				echo -n "=== Renaming ${oldname}-${_i} to "
				echo "${newname}-${_i}"
				mv ${oldname}-${_i} \
					${newname}-${_i}
				echo -n "=== Renaming ${oldname}-${_i}.xz to "
				echo "${newname}-${_i}.xz"
				mv ${oldname}-${_i}.xz \
					${newname}-${_i}.xz
			done
		else
			case ${type} in
				snap)
					case ${rev} in
						11)
							_ext="xz"
							;;
						*)
							_ext="bz2"
							;;
					esac
					if [ ! -z "${BOARDNAME}" ]; then
						oldname="${__DISCNAME}-${KERNEL}"
						newname="${__DISCNAME}-${BOARDNAME}${snapsuffix}"
					else
						oldname="${oldname}-${kernel}"
					fi
					echo -n "=== Renaming ${oldname}.img.${_ext} to "
					echo "${newname}.img.${_ext}"
					mv ${oldname}.img.${_ext} \
						${newname}.img.${_ext}
					;;
				*)
					# No need to rename 'release' type images.
					;;
			esac
		fi
	fi

	if [ "X${newname}" != "X${oldname}" ]; then
		cd ${C}/R
		rm -f CHECKSUM.SHA256* CHECKSUM.MD5*
		# CHECKSUM.SHA256-11.0-CURRENT-amd64-VT-20140127-r261200
		echo "=== Regenerating SHA256 checksums"
		sha256 FreeBSD* > \
			${C}/R/CHECKSUM.SHA256-${_sumsuffix}
		# CHECKSUM.MD5-11.0-CURRENT-amd64-VT-20140127-r261200
		echo "=== Regenerating MD5 checksums"
		md5 FreeBSD* > \
			${C}/R/CHECKSUM.MD5-${_sumsuffix}
		cd ${scriptdir}
	else
		for h in SHA256 MD5; do
			echo "=== Renaming ${h} checksums"
			mv ${C}/R/CHECKSUM.${h} \
				${C}/R/CHECKSUM.${h}-${_sumsuffix}
		done
	fi

	# Copy ISO images to FTP snapshots directory.
	echo "=== Copying checksums and images to ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}..."
	cp -p ${C}/R/*CHECKSUM* ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}/
	cp -p ${C}/R/${__DISCNAME}* ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}/
	unset newname oldname
}

create_dirs() {
	if [ "X${arch}" != "Xarmv6" ]; then
		echo "=== Creating ${_ftpdir}/${path}/${OSRELEASE}..."
		mkdir -p ${_ftpdir}/${path}/${OSRELEASE}/
	fi
	echo "=== Creating ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}..."
	mkdir -p ${_ftpdir}/${path}/ISO-IMAGES/${REVISION}/
	echo "=== Creating ${_ftpdir}/ISO-IMAGES/${REVISION}..."
	mkdir -p ${_ftpdir}/ISO-IMAGES/${REVISION}
}

create_dir_symlinks() {
	if [ ! -z ${backpath} ] && [ ! -L ${_ftpdir}/${backpath}/${OSRELEASE} ]; then
		echo "=== Creating backwards-compatible symlink:"
		echo "==== ${backpath}/${OSRELEASE} -> ${path}/${OSRELEASE}"
		ln -sf ${backpath}/${OSRELEASE} ${_ftpdir}/${backpath}/${OSRELEASE}
	fi
}

create_iso_symlinks() {
	case ${arch} in
		armv6)
			return 0
			;;
		*)
			# continue
			;;
	esac
	echo "=== Creating symlinks for ISO-IMAGES..."
	for image in ${releaseimages}; do
		# FreeBSD-11.0-CURRENT-amd64-bootonly.iso
		# FreeBSD-11.0-CURRENT-amd64-20140127-r261200-bootonly.iso
		# FreeBSD-11.0-CURRENT-amd64-VT-20140127-r261200-bootonly.iso
		if [ -e "${C}/R/${_discname}-${image}" ]; then
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/${_discname}-${image} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/${_discname}-${image}
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/${_discname}-${image}.xz \
				${_ftpdir}/ISO-IMAGES/${REVISION}/${_discname}-${image}.xz
		fi
	done
	echo "=== Creating symlinks for CHECKSUM files..."
	for hash in MD5 SHA256; do
		# CHECKSUM.SHA256
		if [ -e "${C}/R/CHECKSUM.${hash}" ]; then
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash}-${_sumsuffix}
		elif [ -e "${C}/R/CHECKSUM.${hash}-${_sumsuffix}" ]; then
			# CHECKSUM.SHA256-11.0-CURRENT-amd64-20140127-r261200
			# CHECKSUM.SHA256-11.0-CURRENT-amd64-VT-20140127-r261200
			ln -sf ../../${path}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash}-${_sumsuffix} \
				${_ftpdir}/ISO-IMAGES/${REVISION}/CHECKSUM.${hash}-${_sumsuffix}
		fi
	done
}

stage_builds() {
	setup_stageenv
	local _ftpdir
	local _discname
	local _sumsuffix
	local _snapsuffix
	_ftpdir="${ftpdir}/${ftpsubdir}"
	_discname="${__DISCNAME}"
	_sumsuffix="${OSRELEASE}-${isoarch}"
	_snapsuffix="${__DATE}-${__SVNREV}"
	if [ "${skip}" -eq 1 ]; then
		echo "=== Skipping ${rev}-${arch}-${kernel}-${type} staging"
		return 0
	fi
	if [ ! -d ${C}/R ]; then
		echo "=== Skipping ${rev}-${arch}-${kernel}-${type} staging"
		echo "==== ${C}/R directory does not exist"
		return 0
	fi
	case ${kernel} in
		GENERIC*)
			;;
		*)
			_discname="${_discname}-${kernel}"
			_sumsuffix="${_sumsuffix}-${kernel}"
			;;
	esac
	case ${type} in
		snap)
			_discname="${_discname}-${_snapsuffix}"
			_sumsuffix="${_sumsuffix}-${_snapsuffix}"
			;;
		*)
			;;
	esac

	create_dirs
	stage_isos
	create_dir_symlinks
	create_iso_symlinks

	return 0
}

stage_vmimages() {
	setup_stageenv
	if [ "${skip}" -eq 1 ] || [ ! -d ${C}/R/vmimages ]; then
		echo "=== Skipping ${rev}-${arch}-${kernel}-${type} staging"
		return 0
	fi
	VMIMAGESPATH="${C}/R/vmimages"
	FTPPATH="${ftpdir}/${ftpsubdir}/VM-IMAGES/${OSRELEASE}/${arch}/${__DATE}"
	LATESTPATH="${ftpdir}/${ftpsubdir}/VM-IMAGES/${OSRELEASE}/${arch}/Latest"
	mkdir -p ${FTPPATH}
	oldname="${__DISCNAME}"
	newname="${oldname}"
	shasuffix=
	case ${type} in
		snap)
		case ${kernel} in
			GENERIC*)
				;;
			*)
				newname="${newname}-${kernel}"
				shasuffix="${kernel}-"
				;;
		esac
		newname="${newname}-${__DATE}-${__SVNREV}"
		shasuffix="${shasuffix}${__DATE}-${__SVNREV}"
		for image in ${VMIMAGES}; do
			mv ${VMIMAGESPATH}/${__DISCNAME}*.${image}.xz \
				${VMIMAGESPATH}/${newname}.${image}.xz
		done
		# Remove old checksums.
		rm -f ${VMIMAGESPATH}/CHECKSUM.*
		(cd ${VMIMAGESPATH} &&
			sha256 ${__DISCNAME}* \
				> CHECKSUM.SHA256-${shasuffix}
			md5 ${__DISCNAME}* \
				> CHECKSUM.MD5-${shasuffix}
		)
			;;
		*)
			;;
	esac
	cp -p ${VMIMAGESPATH}/CHECKSUM* \
		${FTPPATH}

	for image in ${VMIMAGES}; do
		cp -p ${VMIMAGESPATH}/${__DISCNAME}*.${image}.xz \
			${FTPPATH}
	done
	if [ -L ${LATESTPATH} ]; then
		unlink ${LATESTPATH}
	fi
	mkdir -p ${LATESTPATH}
	(cd ${LATESTPATH}
	for image in ${VMIMAGES}; do
		if [ -L ${oldname}.${image}.xz ]; then
			unlink ${oldname}.${image}.xz
		fi
		ln -s ../${__DATE}/${newname}.${image}.xz \
			${oldname}.${image}.xz
	done
	for hash in MD5 SHA256; do
		if [ -L CHECKSUM.${hash} ]; then
			unlink CHECKSUM.${hash}
		fi
		ln -s ../${__DATE}/CHECKSUM.${hash}-${shasuffix} \
			CHECKSUM.${hash}
	done)
	unset newname oldname shasuffix VMIMAGESPATH
	return 0
}

dirperm_fixup() {
	cd ${ftpdir}
	echo "=== Setting correct directory permissions for ftp-master..."
	find . -type d | xargs chmod 775
	return 0
}

main() {
	export __BUILDCONFDIR="$(dirname $(realpath ${0}))"
	FTPCONF=

	while getopts "c:" opt; do
		case ${opt} in
			c)
				FTPCONF="${OPTARG}"
				;;
			*)
				;;
		esac
	done

	if [ -z "${FTPCONF}" ]; then
		echo "Build configuration file is required."
		usage
	fi

	FTPCONF="$(realpath ${FTPCONF})"

	if [ ! -f "${FTPCONF}" ]; then
		echo "Build configuration is not a regular file."
		exit 1
	fi

	. "${FTPCONF}"

	if [ -z "${relengdir}" ]; then
		echo "'relengdir' must be set in the build configuration."
		exit 1
	fi

	for rev in ${revs}; do
		for arch in ${archs}; do
			for kernel in ${kernels}; do
			for type in ${types}; do
				if [ -e ${scriptdir}/${rev}-${arch}-${kernel}-${type}.conf ]; then
					echo "== Staging Release: ${rev}-${arch}-${kernel}-${type}"
					stage_builds
					case ${arch} in
						i386|amd64|aarch64)
							echo "== Staging VM Images: ${rev}-${arch}-${kernel}-${type}"
							stage_vmimages
							;;
						*)
							;;
					esac
				fi
			done
			done
		done
	done
	dirperm_fixup
	#echo "== For snapshots, run: rsync -av --links ${ftpdir}/ /snap/ftp/snapshots"
	#echo -n "== For releases, run 'rsync -av --delete --links "
	#echo "${ftpdir}/ ftp-master.freebsd.org:/archive/tmp/releases'"
}

main "$@"
