#!/bin/sh
#
# $FreeBSD: scripts/postbuild84R.sh 149 2013-03-21 17:34:10Z gjb $
# $relengid$
#

revs="8"
archs="amd64 i386 sparc64 pc98 powerpc powerpc64"

ftpdir="/relengftp/releases"

relengdir="/releng"
debug=1

## There are 300 better ways to do this.
## There are also an infinite number of worse ways...

for rev in ${revs}; do
	for arch in ${archs}; do
		path=
		OSRELEASE=

		C="${relengdir}/${rev}-${arch}"

		if [ ${debug} ]; then
			echo "Looking in ${C} for newvers.sh"
		fi

		if [ -d ${C} ]; then
			if [ ${debug} ]; then
				echo "Found directory ${C}"
			fi
			#BRANCH=$(grep '^BRANCH=' ${C}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
			#BRANCH=`echo ${BRANCH} | sed -e 's,",,g'`
			#REVISION=$(grep '^REVISION=' ${C}/usr/src/sys/conf/newvers.sh | awk -F\= '{print $2}')
			#REVISION=`echo ${REVISION} | sed -e 's,",,g'`
			BRANCH="BETA1"
			REVISION="8.4"
			OSRELEASE="${REVISION}-${BRANCH}"

			if [ ${debug} ]; then
				echo "=== VARIABLES:"
				echo "BRANCH = ${BRANCH}"
				echo "REVISION = ${REVISION}"
				echo "OSRELEASE = ${OSRELEASE}"
				sleep 5
			fi
		fi

		if [ ${debug} ]; then
			echo "Checking if rev = '8'"
		fi

		if [ ${rev} -ne 8 ]; then
			if [ ${debug} ]; then
				echo "rev != 8"
			fi
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
			if [ ${debug} ]; then
				echo "rev == 8"
			fi
			path="${arch}"
			if [ ${debug} ]; then
				echo "path set to: ${path}"
				sleep 2
			fi
		fi

		if [ ${debug} ]; then
			echo "Checking xOSRELEASE == x"
		fi
		if [ "x${OSRELEASE}" != "x" ]; then
			if [ ${debug} ]; then
				echo "xOSRELEASE != x"
			fi
			if [ ${debug} ]; then
				echo "mkdir -p ${ftpdir}/${path}/${OSRELEASE}/"
				echo "rsync -av --delete ${C}/release/R/ftp/* ${ftpdir}/${path}/${OSRELEASE}/"

				## Copy ISO images to FTP snapshots directory.
				echo "mkdir -p ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/"
				echo "cp -p ${C}/release/R/cdrom/*CHECKSUM* ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/"
				echo "cp -p ${C}/release/R/cdrom/FreeBSD* ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/"
			else
				mkdir -p ${ftpdir}/${path}/${OSRELEASE}/
				rsync -av --delete ${C}/release/R/ftp/* \
					${ftpdir}/${path}/${OSRELEASE}/

				## Copy ISO images to FTP snapshots directory.
				mkdir -p ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/
				cp -p ${C}/release/R/cdrom/*CHECKSUM* ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/
				cp -p ${C}/release/R/cdrom/FreeBSD* ${ftpdir}/${path}/ISO-IMAGES/${REVISION}/
			fi
		fi
	done
done

