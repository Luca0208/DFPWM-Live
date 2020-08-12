#!/bin/sh
# Usage:. ./stream_fm.sh <WSPort> <Frequency>

rtl_fm -f $2 -M wbfm -s 200000 -r 48000 - | sox -traw -r48k -es -b16 -c1 -V1 - -traw -e signed-integer -b 8 -c 1 -r 96000 - | ./aucmp | wscat -b -l $1
