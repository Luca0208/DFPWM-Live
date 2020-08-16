#DFPWM-Live
This is a program to take a stream of audio, convert it to DFPWM and send it to CC to then play it using computronics tapes.

##Thanks
to kotahu for initially giving me the idea to do this
to Anavrins for helping me a lot with the websocket code

##Backend
In the Backend folder you can find a bunch of scripts that take a stream of audio and convert them to DFPWM to then dump then onto a websocket

##Frontend
In the Frontend folder you can find the stream.lua program which is used in CC to receive the data and write to the tape as it's played

##License
This program is Licensed under GPLv2. For the full text see LICENSE
