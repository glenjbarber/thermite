#!/bin/sh
#
# $FreeBSD: scripts/fix-head-names.sh 221 2013-08-11 15:56:09Z root $
# $relengid$
#

conffile="$(dirname ${0})/snapshot.conf"

. ${conffile}

get_osversion () {
	# Most commands below are run in chroot, so fake getosreldate(3) right now
	OSVERSION=$(grep '#define __FreeBSD_version' ${CHROOTDIR}/usr/src/sys/sys/param.h | awk '{print $3}')
	BRANCH=$(grep '^BRANCH=' ${CHROOTDIR}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
	BRANCH=$(echo ${BRANCH} | sed -e 's,",,g')
	REVISION=$(grep '^REVISION=' ${CHROOTDIR}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
	REVISION=$(echo ${REVISION} | sed -e 's,",,g')
	OSRELEASE="${REVISION}-${BRANCH}"
}

rename_iso () {
	RELSTRING="FreeBSD-${OSRELEASE}-${arch}-${builddate}-${svnrev}"
	echo "*** Looking for ${relengdir}/${rev}-${arch}-${type}/R"
	if [ -d "${chrootdir}/${rev}-${arch}-${type}/R" ]; then
		echo "*** Found ${chrootdir}/${rev}-${arch}-${type}/R"
		cd ${chrootdir}/${rev}-${arch}-${type}/R
		echo "*** Renaming images..."
		for i in memstick.img disc1.iso bootonly.iso; do
			mv FreeBSD*-$i \
				${RELSTRING}-$i
		done
		echo "*** Removing old checksum files."
		rm CHECKSUM*
		echo "*** Regenerating checksums."
		sha256 ${RELSTRING}-* \
			> CHECKSUM.SHA256-${builddate}
		md5 ${RELSTRING}-* \
			> CHECKSUM.MD5-${builddate}
		echo "*** Done."
		return 0
	else
		echo "*** Not found: ${relengdir}/${rev}-${arch}-${type}/R"
		return 0
	fi
}

for arch in ${archs}; do
	for rev in ${revs}; do
		for type in ${types}; do
			if [ -e "${relengdir}/${rev}-${arch}-${type}.conf" ]; then
				. ${relengdir}/${rev}-${arch}-${type}.conf
				get_osversion
				rename_iso
			fi
		done
	done
done

exit 0

#HEAD="10.0-CURRENT"
#STABLE9="9.1-STABLE"


for arch in amd64 i386 powerpc powerpc64; do
	echo "*** Looking for ${relengdir}/10-${arch}-snap/R"
	if [ -d "${relengdir}/10-${arch}-snap/R" ]; then
		echo "*** Found ${relengdir}/10-${arch}-snap/R"
		cd ${relengdir}/10-${arch}-snap/R
		echo "*** Renaming images..."
		for i in memstick.img disc1.iso bootonly.iso; do
			mv FreeBSD*-$i \
				FreeBSD-${HEAD}-${arch}-${builddate}-${rev}-$i
		done
		echo "*** Removing old checksum files."
		rm CHECKSUM*
		echo "*** Regenerating checksums."
		sha256 FreeBSD-${HEAD}-${arch}-${builddate}-${rev}-* \
			> CHECKSUM.SHA256-${builddate}
		md5 FreeBSD-${HEAD}-${arch}-${builddate}-${rev}-* \
			> CHECKSUM.MD5-${builddate}
		echo "*** Done."
	else
		echo "*** Not found: ${relengdir}/10-${arch}-snap/R"
	fi
done

for arch in amd64 i386 powerpc powerpc64; do
	echo "*** Looking for ${relengdir}/9-${arch}-snap/R"
	if [ -d "${relengdir}/9-${arch}-snap/R" ]; then
		echo "*** Found ${relengdir}/9-${arch}-snap/R"
		cd ${relengdir}/9-${arch}-snap/R
		echo "*** Renaming images..."
		for i in memstick.img disc1.iso bootonly.iso; do
			mv FreeBSD*-$i \
				FreeBSD-${STABLE9}-${arch}-${builddate}-${rev}-$i
		done
		echo "*** Removing old checksum files."
		rm CHECKSUM*
		echo "*** Regenerating checksums."
		sha256 FreeBSD-${STABLE9}-${arch}-${builddate}-${rev}-* \
			> CHECKSUM.SHA256-${builddate}
		md5 FreeBSD-${STABLE9}-${arch}-${builddate}-${rev}-* \
			> CHECKSUM.MD5-${builddate}
		echo "*** Done."
	else
		echo "*** Not found: ${relengdir}/9-${arch}-snap/R"
	fi
done

exit 0

