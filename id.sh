#! /bin/sh
# Calculate a custom CRC of data read from standard input.
#
# We use the CRC-32 as calculated by "cksum" for this.
#
# v2021.340

cksum | cut -d ' ' -f 1
