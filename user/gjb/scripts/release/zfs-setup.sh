#!/bin/sh
#
# $relengid$
#

quick_usage() {
	echo "$(basename ${0}) /path/to/configuration/file"
	exit 1
}

while getopts "d" arg; do
	case ${arg} in
		d)
			delete_only=1
			;;
		*)
			delete_only=
			;;
	esac
done
shift $(( ${OPTIND} - 1 ))

if [ "$#" -lt 1 ]; then
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
			for k in ${kernels}; do
			for t in ${types}; do
				s="${r}-${a}-${k}-${t}"
				c="${r}-${a}-${t}"
				if [ -e ${scriptdir}/${s}.conf ];
				then
					zfs list ${zfs_parent}/${s}-src >/dev/null 2>&1
					rc=$?
					if [ ${rc} -eq 0 ]; then
						echo -n "${pfx} Destroying " \
							>/dev/stdout
						echo " ${zfs_parent}/${s}-src" \
							>/dev/stdout
						zfs destroy ${zfs_parent}/${s}-src
					fi
					zfs list ${zfs_parent}/${s}-ports >/dev/null 2>&1
					rc=$?
					if [ ${rc} -eq 0 ]; then
						echo -n "${pfx} Destroying " \
							>/dev/stdout
						echo " ${zfs_parent}/${s}-ports" \
							>/dev/stdout
						zfs destroy ${zfs_parent}/${s}-ports
					fi
					zfs list ${zfs_parent}/${s}-doc >/dev/null 2>&1
					rc=$?
					if [ ${rc} -eq 0 ]; then
						echo -n "${pfx} Destroying " \
							>/dev/stdout
						echo " ${zfs_parent}/${s}-doc" \
							>/dev/stdout
						zfs destroy ${zfs_parent}/${s}-doc
					fi
					zfs list ${zfs_parent}/${c}-chroot >/dev/null 2>&1
					rc=$?
					if [ ${rc} -eq 0 ]; then
						echo -n "${pfx} Destroying " \
							>/dev/stdout
						echo " ${zfs_parent}/${c}-chroot" \
							>/dev/stdout
						zfs destroy ${zfs_parent}/${c}-chroot
					fi
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
	done

	for r in ${revs}; do
		for t in ${types}; do
			for i in src doc ports; do
				zfs list ${zfs_parent}/${r}-${i}-${t}@clone >/dev/null 2>&1
				rc=$?
				if [ ${rc} -eq 0 ]; then
					echo -n "${pfx} Destroying " \
						>/dev/stdout
					echo " ${zfs_parent}/${r}-${i}-${t}@clone" \
						>/dev/stdout
					zfs destroy ${zfs_parent}/${r}-${i}-${t}@clone
				fi
				zfs list ${zfs_parent}/${r}-${i}-${t} >/dev/null 2>&1
				rc=$?
				if [ ${rc} -eq 0 ]; then
					echo -n "${pfx} Destroying " \
						>/dev/stdout
					echo " ${zfs_parent}/${r}-${i}-${t}" \
						>/dev/stdout
					zfs destroy ${zfs_parent}/${r}-${i}-${t}
				fi
			done
		done
	done
	return 0
}

zfs_setup() {
	[ ! -z ${delete_only} ] && return 0
	for r in ${revs}; do
		for a in ${archs}; do
			for k in ${kernels}; do
			for t in ${types}; do
				s="${r}-${a}-${k}-${t}"
				if [ -e ${scriptdir}/${s}.conf ];
				then
					echo "${pfx} Creating ${zfs_parent}/${s}" \
						>/dev/stdout
					zfs create -o atime=off ${zfs_parent}/${s}
				fi
			done
			done
		done
	done
	return 0
}

zfs_teardown
zfs_setup
exit 0

