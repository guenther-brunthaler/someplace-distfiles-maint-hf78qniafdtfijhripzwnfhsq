#! /bin/sh
# Ensure all required helper scripts and utilities are available.
#
# v2021.340

trap 'test $? = 0 || echo "\"$0\" failed!" >& 2' 0

case $0 in
	/*) me=$0;;
	*) me=$PWD/$0
esac
test -f "$me"
scripts=`dirname -- "$me"`
test -d "$scripts"

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

for need in hash.sh id.sh
do
	need=$scripts/$need
	test -f "$need" || {
		echo
		echo "Required helper script '$need' is missing!"
		all=false
	} >& 2
done
$all || exit
