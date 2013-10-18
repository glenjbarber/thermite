#!/bin/sh
#
# $FreeBSD: scripts/getrev.sh 290 2013-10-14 19:48:43Z gjb $
# $relengid$
#

cwd="$(dirname $(realpath ${0}))"
builddate="$(date +%Y%m%d)"
echo ${builddate} > ${cwd}/builddate

if [ -e ${cwd}/svnrev.txt ]; then
	mv ${cwd}/svnrev.txt \
		${cwd}/svnrev.txt.prev
fi

svn info svn://svn.freebsd.org/base/head \
	| grep ^Revision | awk '{print $2}' > ${cwd}/svnrev.txt
