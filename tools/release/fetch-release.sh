#!/bin/sh
#
# $Id$
#

emailgoesto="gjb@FreeBSD.org marius@FreeBSD.org"
emailsentfrom="root@FreeBSD.org"

_subject="release FTP sync done"
_body="Sync done.\n\n"
_body="${_body}RELEASE builds do not automatically sync to ftp-master.\n\n"
_body="${_body}Contact clusteradm@ for now.\n\n"

while ! rsync --progress --partial --time-limit=5 -avH --delete rsync://releng1.nyi.freebsd.org/releases /snap/stage/releases; do :; done
find /snap/stage/releases/ -type d | xargs chmod 775

printf "From: ${emailsentfrom}\nTo: ${emailgoesto}\nSubject: ${_subject}\n\n${_body}\n\n" \
	| /usr/sbin/sendmail -oi -f ${emailsentfrom} ${emailgoesto}
