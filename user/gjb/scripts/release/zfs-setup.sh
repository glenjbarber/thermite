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

if [ ${use_zfs} -eq 0 ]; then
	echo "== use_zfs is set to '0'; skipping." >/dev/stdout
	exit 0
fi

pfx="==="

zfs_teardown() {
	for r in ${revs}; do
		for a in ${archs}; do
			for t in ${types}; do
				s="${r}-${a}-${t}"
				if [ -e ${scriptdir}/${s}.conf ];
				then
					zfs list ${zfs_parent}/${s} >/dev/null 2>&1
					rc=$?
					if [ ${rc} -eq 0 ]; then
						echo -n "${pfx} Destroying " \
							>/dev/stdout
						echo " ${zfs_parent}/${s}" \
							>/dev/stdout
						zfs destroy ${zfs_parent}/${s}
					fi
				fi
			done
		done
	done
	return 0
}

zfs_setup() {
	for r in ${revs}; do
		for a in ${archs}; do
			for t in ${types}; do
				s="${r}-${a}-${t}"
				if [ -e ${scriptdir}/${s}.conf ];
				then
					echo "${pfx} Creating ${zfs_parent}/${s}" \
						>/dev/stdout
					zfs create -o atime=off ${zfs_parent}/${s}
				fi
			done
		done
	done
	return 0
}

zfs_teardown
zfs_setup
exit 0

