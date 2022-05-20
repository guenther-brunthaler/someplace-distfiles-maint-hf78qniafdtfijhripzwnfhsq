#! /bin/sh
# v2021.340
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

mode=report
dry_run=false
while getopts rn opt
do
	case $opt in
		r) mode=remove;;
		n) dry_run=true;;
		*) false || exit
	esac
done
shift `expr $OPTIND - 1 || :`

"$scripts"/verify-requirements.sh

println() {
	printf '%s\n' "$*"
}


TD=`mktemp -d -- "${TMPDIR:-/tmp}/${0##*/}".XXXXXXXXXX`

case $mode in
	remove)
		case $# in
			0) cat;;
			*)
				for a
				do
					println "$a"
				done
		esac \
		| while IFS= read -r p
		do
			case $p in
				/*) ;;
				*) p=$repo/$p
			esac
			f=${p##*/}
			test "$p" = "$repo/$f"
			test -L "$p"
		done
		;;
	detect)
		find -H "$repo" \
			\( \
				-path "$repo/lost+found" -o -path "$repo/*/*" \
			\) -prune \
			-print \
		| while IFS= read -r f
		do
			test -L "$f" \
			&& test -e "$f" \
			&& "${f%.refs}" != "$f"
			println "$f"
		done
		;;
	*) false || exit
esac
exit

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
