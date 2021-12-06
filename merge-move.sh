#! /bin/sh
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
repo=`dirname -- "$me"`
repo=`readlink -f -- "$repo"`
test -d "$repo"

force=false
mode=merge+move
while getopts fc opt
do
	case $opt in
		c) mode=checksum;;
		f) force=true;;
		*) false || exit
	esac
done
shift `expr $OPTIND - 1 || :`

all=true; # An *: entry must be first for initializing $pkg.
for need in coreutils: base32 : openssl
do
	case $need in
		*:) pkg=${need%:};;
		*)
			: ${pkg:="$need"}
			command -v -- "${need}" > /dev/null 2>& 1 || {
				echo
				echo "Required utility '$need' is missing!"
				echo "On some systems it can be installed with"
				echo "\$ sudo apt-get install $pkg"
				all=false
			} >& 2
			pkg=
	esac
done
$all || exit

# Verify that base32 uses the expected encoding alphabet and that openssl
# supports the "sha256"-subcommand with the "-binary" option.
test "`
	printf %s AIOZ2367 | base32 -d | openssl sha256 -binary \
	| dd bs=5 count=1 2> /dev/null | base32
`" = JAWIXFH7

println() {
	printf '%s\n' "$*"
}

custom_b32() {
	# We choose the hash length so that there is a chance less than one
	# permill of a hash collision if earth's population has grown to 100
	# billion people and all of them do nothing else than creating 10 new
	# files per second for 500 years.
	#
	# files := 100e9 * 500 * 10 * 86400 * (365 + 1 / 4);
	# p_collision_50percent := files ** 2;
	# first_expected_collision := 2 * p_collision_50percent;
	# p_collision_1permill := first_expected_collision * 1000;
	# bits_needed := log2(p_collision_1permill);
	# octets_needed := ceiling(bits_needed / 8);
	# base32_digits_needed := ceiling(bits_needed / log2(32));
	openssl sha256 -binary | dd bs=20 count=1 2> /dev/null \
	| base32 | cut -c -32 | LC_COLLATE=C tr A-Z2-7 02-8a-fh-km-z
}

TD=`mktemp -d -- "${TMPDIR:-/tmp}/${0##*/}".XXXXXXXXXX`
case $mode in
	checksum)
		f='[[:space:]]\{1,\}'; rx='[^[:space:]]\{1,\}'
		rx="$rx$f$rx$f\\($rx\\)$f$rx$f$rx$f$rx"
		rx=$rx'[[:space:]]\(.\{1,\}\)$'
		case $# in
			0)
				cat > "$TD"/file
				echo F >& 5
				println "$TD"/file
				;;
			*)
				for a
				do
					test ! -d "$a"; test -e "$a"
					echo T >& 5
					println "$a"
				done
		esac 5> "$TD"/wrname \
		| sed 's/./\\&/g' | LC_NUMERIC=C LC_TIME=C xargs ls -og -- \
		| sed 's/'"$rx"'/\1 \2/' > "$TD"/sz_fn
		while IFS=' ' read -r z f
		do
			read wrn <& 5
			h=`custom_b32 < "$f"`
			case $wrn in
				T) echo "$h-$z $f";;
				F) echo "$h-$z";;
				*) false || exit
			esac
		done < "$TD"/sz_fn 5< "$TD"/wrname
		exit
esac
exit

find "$repo" -name 'lost+found' -prune -o -name '*.refs' -print \
| while IFS= read -r f
do
	LC_TIME=C ls -og -- "${f%.*}"
done | cut -d ' ' -f 3,7- \
| sed 's/^\([0-9]\{1,\}\) \(.\{1,\}-\)\([0-9]\{1,\}\)$/\3 \1 \2\3/' \
| LC_COLLATE=C sort > "$TD"/avail

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
if test -s "$TD"/warn && test $force = false
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
sed 's/./\\&/g' "$TD"/cand | xargs cksum | LC_COLLATE=C sort > "$TD"/merge
rm -- "$TD"/cand

exit
t=$(readlink -- "$f"); case $t in /home/mnt/distfiles/*) echo "$f" >>
"$t".refs; esac; done
