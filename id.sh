#! /bin/sh
# Calculate a custom data identifier of data read from standard input.
#
# The identifier consists of the data size, followed by an underscore ("_")
# and a CRC or the data. A CRC-32 as calculated by "cksum" is used as the CRC.
#
# v2021.340.3

cksum | sed 's/\(.*\) \(.*\)/\2_\1/'
