#!/bin/sh
# Usage: ./stream_mp3local.sh <WSPort> <PathToMP3>

sox -tmp3 $2 -traw -e signed-integer -b 8 -c 1 -r 48000 - | ./aucmp | wscat -b -l $1
