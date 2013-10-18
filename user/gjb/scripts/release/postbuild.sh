#!/bin/sh
#
# $FreeBSD: scripts/postbuild.sh 295 2013-10-14 23:56:54Z root $
# $relengid$
#

conffile="$(dirname ${0})/snapshot.conf"

. ${conffile}

for rev in ${revs}; do
	for arch in ${archs}; do
		path=
		OSRELEASE=

		C="${relengdir}/../${rev}-${arch}-snap"
		if [ -e ${C}/usr/src/sys/conf/newvers.sh ]; then
			BRANCH=$(grep '^BRANCH=' ${C}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
			BRANCH=`echo ${BRANCH} | sed -e 's,",,g'`
			REVISION=$(grep '^REVISION=' ${C}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
			REVISION=`echo ${REVISION} | sed -e 's,",,g'`
			OSRELEASE="${REVISION}-${BRANCH}"
		fi

		if [ ${rev} -ne 8 ]; then
			case ${arch} in
				powerpc64)
					path="powerpc/powerpc64"
					;;
				pc98)
					path="pc98/i386"
					;;
				*)
					path="${arch}/${arch}"
					;;
			esac
		else
			path="${arch}"
		fi

		if [ "x${OSRELEASE}" != "x" ]; then
			mkdir -p ${ftpdir}/${path}/${OSRELEASE}/
			rsync -av --delete ${C}/R/ftp/* \
				${ftpdir}/${path}/${OSRELEASE}/

			## Copy ISO images to FTP snapshots directory.
			mkdir -p ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/
			cp -p ${C}/R/CHECKSUM* ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/
			cp -p ${C}/R/FreeBSD* ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/

	#		case ${arch} in
	#			amd64|i386)
	#				if [ -d ${C}/vmimage ]; then
	#					mkdir -p ${ftpdir}/VM-IMAGES/${builddate}/${OSRELEASE}/${arch}/
	#					cp -p ${C}/vmimage/FreeBSD*.xz \
	#						${ftpdir}/VM-IMAGES/${builddate}/${OSRELEASE}/${arch}/
	#					cp -p ${C}/vmimage/CHECKSUM* \
	#						${ftpdir}/VM-IMAGES/${builddate}/${OSRELEASE}/${arch}/
	#				fi
	#				;;
	#			*)
	#				;;
	#		esac
		fi
	done
done
unlink ${ftpdir}/VM-IMAGES/Latest
ln -sf ${builddate} ${ftpdir}/VM-IMAGES/Latest

