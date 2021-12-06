#! /bin/sh
# Verify that the replacement symlinks are still valid and optionally update
# outdated symlinks (typically if the symlink targets use an outdated mount
# point).
#
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

mode=check
while getopts u opt
do
	case $opt in
		u) mode=update;;
		*) false || exit
	esac
done
shift `expr $OPTIND - 1 || :`

"$scripts"/verify-requirements.sh

println() {
	printf '%s\n' "$*"
}

TD=`mktemp -d -- "${TMPDIR:-/tmp}/${0##*/}".XXXXXXXXXX`

find -H "$repo" \
	\( -path "$repo/lost+found" -o -path "$repo/*/*" \) -prune \
	-o -name '*.refs' -print \
| while IFS= read -r refs
do
	test -f "$refs"
	target=${refs%.*}
	test -f "$target"
	while IFS= read -r ref
	do
		if test -L "$ref"
		then
			rt=`readlink -- "$ref"`
			test "$rt" = "$target" && continue
			case $mode in
				update)
					echo "Updating ref '$ref'"
					ln -sf -- "$target" "$ref"
					;;
				*)
					echo "ref '$ref': needs to be updated!"
			esac
		elif test -f "$ref"
		then
			echo "ref '$ref': symlink has been replaced by file!"
		else
			echo "ref '$ref': is neither a symlink nor a file!"
		fi
	done < "$refs" >& 2
done
