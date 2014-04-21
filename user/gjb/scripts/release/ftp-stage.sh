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

. $(realpath ${1})

case `hostname -s` in
	snap)
		relengdir="/snap/releng"
		;;
	bake | grind)
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
	vmimages="qcow2 vmdk vhd"
	WITH_DVD=
	REVISION=
	BRANCH=
	OSRELEASE=
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
			ftpsubdir="snapshots"
			;;
	esac

	REVISION=$(make -C ${C}/usr/src/release -V REVISION)
	BRANCH=$(make -C ${C}/usr/src/release -V BRANCH)
	OSRELEASE="${REVISION}-${BRANCH}"
	__DATE="${BUILDDATE}"
	__SVNREV="r${BUILDSVNREV}"

	if [ "X${OSRELEASE}" = "X" ]; then
		skip=1
	fi

	. "${scriptdir}/${rev}-${arch}-${kernel}-${type}.conf"
	case ${arch} in
		armv6)
			TARGET="${XDEV}"
			TARGET_ARCH="${XDEV_ARCH}"
			;;
		*)
			releaseimages="$(make -C ${C}/usr/src/release WITH_DVD=${WITH_DVD} -V IMAGES)"
			if [ "X${TARGET}" = "X" ] && [ "X${TARGET_ARCH}" = "X" ]; then
				TARGET=$(uname -m)
				TARGET_ARCH=$(uname -p)
			fi
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
			newname="${newname}-${__DATE}-${__SVNREV}"
			;;
		*)
			;;
	esac

	# If the resulting image name has changed (non-GENERIC kernel, or this
	# is a snapshot build, rename the ISOs, and regenerate the hashes.
	if [ "X${newname}" != "X${oldname}" ]; then
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
			oldname="${oldname}-${kernel}"
			echo -n "=== Renameing ${oldname}.img.bz2 to "
			echo "${newname}.img.bz2"
			mv ${oldname}.img.bz2 ${newname}.img.bz2
		fi
		rm -f CHECKSUM.SHA256* CHECKSUM.MD5*
		# CHECKSUM.SHA256-11.0-CURRENT-amd64-VT-20140127-r261200
		echo "=== Regenerating SHA256 checksums"
		sha256 ${__DISCNAME}* > \
			${C}/R/CHECKSUM.SHA256-${_sumsuffix}
		# CHECKSUM.MD5-11.0-CURRENT-amd64-VT-20140127-r261200
		echo "=== Regenerating MD5 checksums"
		md5 ${__DISCNAME}* > \
			${C}/R/CHECKSUM.MD5-${_sumsuffix}
		cd ${scriptdir}
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
	if [ "${skip}" -eq 1 ] || [ ! -d ${C}/vmimage ]; then
		echo "=== Skipping ${rev}-${arch}-${kernel}-${type} staging"
		return 0
	fi
	FTPPATH="${ftpdir}/snapshots/VM-IMAGES/${OSRELEASE}/${arch}/${__DATE}"
	LATESTPATH="${ftpdir}/snapshots/VM-IMAGES/${OSRELEASE}/${arch}/Latest"
	mkdir -p ${FTPPATH}
	if [ -e "${C}/vmimage/${__DISCNAME}.disk" ]; then
		# Hide the raw '.disk' file by renaming to a dot-file.
		mv "${C}/vmimage/${__DISCNAME}.disk" "${C}/vmimage/.${__DISCNAME}.disk"
	fi
	oldname="${__DISCNAME}"
	newname="${oldname}"
	shasuffix=
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
	for image in ${vmimages}; do
		mv ${C}/vmimage/${__DISCNAME}*.${image}.xz \
			${C}/vmimage/${newname}.${image}.xz
	done
	# Remove old checksums.
	rm -f ${C}/vmimage/CHECKSUM.*
	(cd ${C}/vmimage &&
		sha256 ${__DISCNAME}* \
			> CHECKSUM.SHA256-${shasuffix}
		md5 ${__DISCNAME}* \
			> CHECKSUM.MD5-${shasuffix}
	)
	cp -p ${C}/vmimage/CHECKSUM* \
		${FTPPATH}

	for image in ${vmimages}; do
		cp -p ${C}/vmimage/${__DISCNAME}*.${image}.xz \
			${FTPPATH}
	done
	unlink ${LATESTPATH}
	ln -sf ${__DATE} ${LATESTPATH}
	unset newname oldname shasuffix
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
			for kernel in ${kernels}; do
			for type in ${types}; do
				if [ -e ${scriptdir}/${rev}-${arch}-${kernel}-${type}.conf ]; then
					echo "== Staging Release: ${rev}-${arch}-${kernel}-${type}"
					stage_builds
					case ${arch} in
						i386|amd64)
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

main
