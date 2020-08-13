#!/bin/sh
# Usage: ./stream_mp3youtube.sh <WSPort> <Youtube URL>
# Requires: ffmpeg, youtube-dl packages
# Sometimes youtube-dl will refuse to accept the video, guess that's their bug
# RE: Make sure you use the most latest version of youtube-dl, if possible, do the manual option here https://yt-dl.org/update

youtube-dl -q -no-video "$2" -o - | ffmpeg -i pipe: -y -loglevel 0 -hide_banner -strict -2 -f mp3 - | sox -tmp3 - -traw -e signed-integer -b 8 -c 1 -r 96000 - | ./aucmp | wscat -b -l $1
