#!/bin/sh
#
# $Id$
#

emailgoesto="gjb@FreeBSD.org marius@FreeBSD.org"
emailsentfrom="root@FreeBSD.org"

_subject="snapshot FTP sync done"
_body="Sync done.\n\n"

# 10-STABLE
while ! rsync --progress --partial --time-limit=5 -avH rsync://releng1.nyi.freebsd.org/snapshots /snap/stage/snapshots; do :; done
# 11-CURRENT
while ! rsync --progress --partial --time-limit=5 -avH rsync://releng2.nyi.freebsd.org/snapshots /snap/stage/snapshots; do :; done

find /snap/stage/snapshots/ -type d | xargs chmod 775
rsync -avH /snap/stage/snapshots/* /snap/ftp/snapshots/

printf "From: ${emailsentfrom}\nTo: ${emailgoesto}\nSubject: ${_subject}\n\n${_body}\n\n" \
	| /usr/sbin/sendmail -oi -f ${emailsentfrom} ${emailgoesto}
