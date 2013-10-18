#!/bin/sh
#
# $FreeBSD: scripts/postbuild-checksums.sh 208 2013-07-14 20:22:49Z root $
# $relengid$
#

conffile="$(dirname ${0})/snapshot.conf"

. ${conffile}

cd ${chrootdir}

checksumfile="/home/gjb/checksums.txt"
changelog="/home/gjb/changelog"
currev="r$(cat ${relengdir}/svnrev.txt)"
prevrev="r$(cat ${relengdir}/svnrev.txt.prev)"

if [ -f "${checksumfile}" ]; then
	rm -f ${checksumfile}
fi

for d in `find . -maxdepth 1 -type d -name \*-snap | sort`; do
	echo "o " >> ${checksumfile}
	echo "" >> ${checksumfile}
	for sum in SHA256 MD5; do
		cat ${d}/R/CHECKSUM.${sum}-${builddate} >> ${checksumfile}
	done
	echo "" >> ${checksumfile}
done

for d in `find . -maxdepth 1 -type d -name \*-snap | sort`; do
	echo "o " >> ${checksumfile}.vm
	echo "" >> ${checksumfile}.vm
	for sum in SHA256 MD5; do
		cat ${d}/vmimage/CHECKSUM.${sum}-${builddate} >> ${checksumfile}.vm
	done
	echo "" >> ${checksumfile}.vm
done

svn log --incremental -${prevrev}:${currev} ${srcbase}/head \
	> ${changelog}-head-${prevrev}-${currev}.txt
for stable in ${stables}; do
	svn log --incremental -${prevrev}:${currev} ${srcbase}/stable/${stable} \
		> ${changelog}-stable-${stable}-${prevrev}-${currev}.txt
done

