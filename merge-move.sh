#! /bin/sh
# v2021.340.1
minsize=10k
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
while getopts rfnml opt
do
	case $opt in
		r) mode=remove;;
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
	find "$f" -size -"$minsize" >& 5
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
esac > "$TD"/cand 5> "$TD"/warn
if
	case $mode in lookup | remove) false;; *) true; esac \
	&& test -s "$TD"/warn && test $force = false
then
	t=`mktemp small-files-XXXXXX.txt`
	sort < "$TD"/warn | tee "$t"
	echo
	echo "The above list of files seem to be too small to be likely"
	echo "candidates for repository archives. Run again with -f in"
	echo "order to suppress this check after verifying the files are"
	echo "actually appropriate for inclusion. The above file list has"
	echo "also been saved as file '$t' for your convenience."
	false || exit
fi >& 2
sed 's/./\\&/g' "$TD"/cand \
	| xargs readlink -f | LC_COLLATE=C sort \
> "$TD"/merge
rm -- "$TD"/cand

run() {
	case $dry_run in
		true) set echo "SIMULATION: $@"
	esac
	"$@"
}

run_always() {
	case $dry_run in
		true) echo "SIMULATION: $@"
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

# Save string "$1" to file "$2" (will be created if it does not yet exist).
str_save() {
	println "$1" > "$2"
}

# Remove the single line in file "$1" from file "$2" which must be sorted.
remove_match() {
	LC_COLLATE=POSIX run comm -23 -- "$2" "$1" > "$TD"/reduced
	cat < "$TD"/reduced > "$2"
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
		case $mode in
			remove) ;;
			*)
				run cp -p -- "$orig" "$ht"
				case $dry_run in
					false)
						if test ! -w "$ht"
						then
							 chmod +w "$ht"
						fi
				esac
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
			remove) ;;
			lookup)
				echo "Not yet in repository: '$orig'"
				continue
				;;
			*) run ln -s "$h" "$rt"
		esac
	fi
	h=$h.refs
	ht=$repo/$h
	if test ! -e "$ht"
	then
		case $mode in
			remove) ;;
			*) run create "$ht"
		esac
	fi
	i=$i.refs
	rt=$repo/$i
	if test -L "$rt"
	then
		t=`readlink -- "$rt"`
		test "$t" = "$h"
	else
		test ! -e "$rt"
		case $mode in
			remove) ;;
			*) run ln -s "$h" "$rt"
		esac
	fi
	case $mode in
		remove)
			oes=`wc -l < "$rt"`
			run_always str_save "$orig" "$TD"/ref
			LC_COLLATE=POSIX comm -12 -- "$rt" "$TD"/ref \
				> "$TD"/match
			if test -s "$TD"/match
			then
				run remove_match "$TD"/ref "$rt"
				case $oes in
					1)
						run rm -- "${ht%.*}"
						run rm -- "$ht"
						run rm -- "${rt%.*}"
						run rm -- "$rt"
				esac
			fi
			run rm -- "$orig"
			;;
		*)
			run str_append "$orig" "$rt"
			LC_COLLATE=POSIX run sort -o "$rt" -u "$rt"
	esac
	case $mode in
		merge-only | lookup | remove) ;;
		*) run ln -sf -- "${rt%.refs}" "$orig"
	esac
done < "$TD"/merge
