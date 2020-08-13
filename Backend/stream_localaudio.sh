#!/bin/sh
# Usage: ./stream_localaudio.sh <WSPort> <PathToAudioFile>

sox $2 -traw -e signed-integer -b 8 -c 1 -r 48000 - | ./aucmp | wscat -b -l $1
