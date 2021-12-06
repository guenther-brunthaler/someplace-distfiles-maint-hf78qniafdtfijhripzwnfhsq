#! /bin/sh
# Calculate a custom data identifier of data read from standard input.
#
# The identifier consists of the data size, followed by a dash ("-") and a CRC
# or the data. A CRC-32 as calculated by "cksum" is used as the CRC.
#
# v2021.340.1

cksum | sed 's/\(.*\) \(.*\)/\2-\1/'
