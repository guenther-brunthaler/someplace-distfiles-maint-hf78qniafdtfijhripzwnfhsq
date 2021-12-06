#! /bin/sh
# v2021.340.2
set -e
cleanup() {
	rc=$?
	test "$TD" && rm -r -- "$TD"
	test $rc = 0 || echo "\"$0\" failed!" >& 2
}
TF=
trap cleanup 0
trap 'exit $?' HUP INT QUIT TERM

case $0 in
	/*) me=$0;;
	*) me=$PWD/$0
esac
test -f "$me"
scripts=`dirname -- "$me"`
test -d "$scripts"
repo=`readlink -f -- "$scripts"`
repo=`dirname -- "$repo"`
test -d "$repo"

force=false
mode=merge+move
dry_run=false
while getopts fnml opt
do
	case $opt in
		l) mode=lookup;;
		m) mode=merge-only;;
		n) dry_run=true;;
		f) force=true;;
		*) false || exit
	esac
done
shift `expr $OPTIND - 1 || :`

"$scripts"/verify-requirements.sh

println() {
	printf '%s\n' "$*"
}

process() {
	f=$1
	test -f "$f"
	while :
	do
		case $f in
			./) f=${f#./}; continue
		esac
		break
	done
	case $f in
		../* | */../*) false || exit;;
		/*) ;;
		*) f=$PWD/$f
	esac
	println "$f"
}

TD=`mktemp -d -- "${TMPDIR:-/tmp}/${0##*/}".XXXXXXXXXX`
case $# in
	0)
		while IFS= read -r a
		do
			process "$a"
		done
		;;
	*)
		for a
		do
			process "$a"
		done
esac \
| sed 's/./\\&/g' \
| xargs readlink -f | LC_COLLATE=C sort \
> "$TD"/merge

run() {
	case $dry_run in
		true) set echo "SIMULATION: $@"
	esac
	"$@"
}

create() {
	> "$1"
}

# Append string "$1" to file "$2" (will be created if it does not yet exist).
str_append() {
	println "$1" >> "$2"
}

while IFS= read -r orig
do
	i=`"$scripts"/id.sh < "$orig"`
	h=`"$scripts"/hash.sh < "$orig"`
	h=by-hash/$h
	ht=$repo/$h
	if test ! -e "$ht"
	then
		case $mode in
			lookup)
				echo "Not yet in repository: '$orig'"
				continue
				;;
			merge-only) echo "Copying '$orig' into repository"
		esac
		run cp -p -- "$orig" "$ht"
		case $dry_run in
			false)
				if test ! -w "$ht"
				then
					 chmod +w "$ht"
				fi
		esac
	fi
	i=`basename -- "$orig"`-$i
	rt=$repo/$i
	if test -L "$rt"
	then
		t=`readlink -- "$rt"`
		test "$t" = "$h"
		case $mode in
			lookup)
				echo "'$orig' = '$rt'"
				continue
		esac
	else
		test ! -e "$rt"
		case $mode in
			lookup)
				echo "Not yet in repository: '$orig'"
				continue
		esac
		run ln -s "$h" "$rt"
	fi
	h=$h.refs
	ht=$repo/$h
	if test ! -e "$ht"
	then
		run create "$ht"
	fi
	i=$i.refs
	rt=$repo/$i
	if test -L "$rt"
	then
		t=`readlink -- "$rt"`
		test "$t" = "$h"
	else
		test ! -e "$rt"
		run ln -s "$h" "$rt"
	fi
	run str_append "$orig" "$rt"
	LC_COLLATE=POSIX run sort -o "$rt" -u "$rt"
	case $mode in
		merge+move) run ln -sf -- "${rt%.refs}" "$orig"
	esac
done < "$TD"/merge
