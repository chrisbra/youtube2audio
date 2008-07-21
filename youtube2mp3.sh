#!/bin/bash

# When aborting, be sure to remove the temp directory
trap 'if [ -d "$TMP" ]; then rm -rf "$TMP"; fi' 1 2 3 6 15

function help(){
cat <<-EOF
`basename $0` downloads a video from youtube and
uses mencoder and lame to dump the music into a
mp3 file.
It will use id3 to generate tags.
EOF
}

for i in mplayer youtube-dl lame id3v2 ; do
   which "$i" || { echo "$i not found; exiting" && exit 3; }
done

OPWD=$(pwd)
TMP=$(mktemp -d)

# download flash video
cd "$TMP"
echo "Downloading Video"
youtube-dl -q "$1" -o youtube.fl
echo "Dumping Audio"
mplayer -quiet -ao pcm:file=audio.wav -vo null youtube.flv
echo "Encoding Audio"
lame -quiet -v audio.wav audio.mp3

echo "Tagging mp3"
echo "Enter Values (leave blank if you do not know)!"
read -p"Titel:      " title
read -p"Interpret:  " interpret
read -p"Album:      " album
read -p"Jahr:       " jahr
read -p"Genre:      " genre
read -p"Tracknr:    " track

[ -n "$title" ] && id3v2 -t "$title" audio.mp3
[ -n "$interpret" ] && id3v2 -a "$interpret" audio.mp3
[ -n "$album" ] && id3v2 -A "$album" audio.mp3
[ -n "$jahr" ] && id3v2 -y "$jahr" audio.mp3
[ -n "$genre" ] && id3v2 -g "$genre" audio.mp3
[ -n "$track" ] && id3v2 -T "$track" audio.mp3

if [ -n "$title" -a -n "$interpret" ]; then
    mv audio.mp3 "$OPWD"/"$interpret - $title".mp3
else
    mv audio.mp3 "$OPWD"/
fi

rm -rf "$TMP"
