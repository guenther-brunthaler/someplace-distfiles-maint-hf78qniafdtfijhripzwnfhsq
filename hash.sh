#! /bin/sh
# Calculate a custom hash of data read from standard input. The output is
# lower-case ASCII alphanumerics and does not make use of characters which are
# visually similar ("1", "l", "9" and "g").
#
# When any arguments are given, just calculate some of the hard-coded
# constants used in the hash calculation commands.
#
# v2021.340

case $# in
	0)
		openssl sha256 -binary | dd bs=20 count=1 2> /dev/null \
		| base32 | cut -c -32 | LC_COLLATE=C tr A-Z2-7 02-8a-fh-km-z
		exit
esac

p=python; for p in $p-3 ${p}3 $p false; do
	command -v $p > /dev/null 2>&1 && break
done
sed '1,/^sed/d' < "$0" | $p -; exit

from math import log2, ceil as ceiling

# We choose the hash length so that there is a chance less than one permill of
# a hash collision if earth's population has grown to 100 billion people and
# all of them do nothing else than creating 10 new files per second for 500
# years.

people = 100e9
files_per_second = 10
years = 500

days_in_4_years = 3 * 365 + 366
days_in_100_years = days_in_4_years * (100 / 4) - 1
days_in_400_years = days_in_100_years * 4 + 1
avg_days_per_year = days_in_400_years / 400
seconds_per_year = 60 * 60 * 24 * avg_days_per_year
files = people * years * files_per_second * seconds_per_year;
p_collision_50percent = files ** 2;
first_expected_collision = 2 * p_collision_50percent;
p_collision_1permill = first_expected_collision * 1000;
bits_needed = log2(p_collision_1permill);
octets_needed = ceiling(bits_needed / 8);
base32_digits_needed = ceiling(bits_needed / log2(32));

print(
      "Leading octets needed from binary SHA2-256 hash: "
   +  str(octets_needed)
   +  "\n"
   +  "Leading base-32 digits needed from those octets: "
   +  str(base32_digits_needed)
)
