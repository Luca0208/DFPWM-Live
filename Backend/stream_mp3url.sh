#!/bin/sh
# Usage: ./stream_mp3url.sh <WSPort> <URL>

curl --output - -L $2| sox -tmp3 - -traw -e signed-integer -b 8 -c 1 -r 96000 - | ./aucmp | wscat -b -k -l $1
