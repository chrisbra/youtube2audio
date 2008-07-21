#!/bin/bash

# When aborting, be sure to remove the temp directory
trap 'cleanup; exit 3' 1 2 3 6 15

set -x
VERSION=0.2
NAME=$(basename $0)

for i in mplayer youtube-dl lame id3v2 ; do
   which "$i" || { echo "$i not found; exiting" && exit 3; }
done

cleanup(){
    if [ -d "$TMP" ]; then
	rm -rf "$TMP";
    fi
}


help(){
cat <<-EOF
`basename $0` downloads a video from youtube and
uses mencoder and lame to dump the music into a
mp3 file.
It will use id3 to generate tags.

Version: $VERSION
EOF
exit 2;
}

if [ "$#" -eq 0 ]; then
    help;
fi

youtubeopts="-q"
mplayeropts="-really-quiet -ao pcm:file=audio.wav -vo null"
oggopts="-q 3 -Q -o audio.ogg"
lameopts="--quiet --vbr-new"
encoder="mp3"
mode="interactive"

args=$(getopt -o b -l title:,album:,genre:,track:,artist:,comment:,year:,lameopts:,mplayeropts:,ogg,oggopts:,batch -n "$NAME" -- "$@")
if [ $? != 0 ] ; then echo "Error Parsing Commandline...Exiting" >&2; exit 1; fi
eval set -- "$args"

#T=`getopt -l title:,artist:,comment:,year:,lameopts:,mplayeropts:,youtubeopts: -n $NAME -- "$@"`

#eval set -- "$T"

while [ ! -z "$1" ]; do
    case "$1" in
	--title)        title="$2"; shift 2 ;;
	--album)        album="$2"; shift 2 ;;
	--genre)        genre="$2"; shift 2 ;;
	--track)        track="$2"; shift 2 ;;
	--artist)       artist="$2"; shift 2 ;;
	--comment)      comment="$2"; shift 2 ;;
	--year)         jahr="$2"; shift 2 ;;
	--lameopts)     lameopts+=" $2"; shift 2 ;;
	--mplayeropts) mplayeropts+=" $2"; shift 2 ;;
	--ogg)          encoder="ogg"; shift ;;
	--oggopts)      oggopts+=" $2"; shift ;;
	-b|--batch)     mode="batch"; shift ;;
	--help)         help ;; 
        --)             shift ; break ;;
    esac

done


OPWD=$(pwd)
TMP=$(mktemp -d)

# download flash video
cd "$TMP"
echo "Downloading Video"
#youtube-dl $youtubeopts "$1" -o youtube.flv
cp /tmp/*.flv .
echo "Dumping Audio"
mplayer $mplayeropts youtube.flv
echo "Encoding Audio"

if [ "$encoder" == "mp3" ]; then
    lame $lameopts audio.wav audio.mp3
elif [ "$encoder" == "ogg" ]; then
    oggenc $oggopts audio.wav
fi

echo "Tagging mp3"

if [ "$mode" == "interactive" ]; then 
    echo "Enter Values (leave blank if you do not know)!"
    read -p"Titel:      " title
    read -p"Interpret:  " artist
    read -p"Album:      " album
    read -p"Jahr:       " jahr
    read -p"Genre:      " genre
    read -p"Tracknr:    " track
fi

if [ "$encoder" == "mp3" ]; then

    [ -n "$title" ] && id3v2 -t "$title" audio.mp3
    [ -n "$artist" ] && id3v2 -a "$artist" audio.mp3
    [ -n "$album" ] && id3v2 -A "$album" audio.mp3
    [ -n "$jahr" ] && id3v2 -y "$jahr" audio.mp3
    [ -n "$genre" ] && id3v2 -g "$genre" audio.mp3
    [ -n "$track" ] && id3v2 -T "$track" audio.mp3
    [ -n "$comment" ] && id3v2 -c "$comment" audio.mp3
    id3v2 -c "info: downloaded on `date +%D` from ${1##http://} using $NAME" audio.mp3

elif [ "$encoder" == "ogg" ]; then
    [ -n "$title" ] && vorbiscomment -a  -t "TITLE=\"$title\"" audio.ogg
    [ -n "$artist" ] && vorbiscomment -a  -t "ARTIST=\"$artist\"" audio.ogg
    [ -n "$album" ] && vorbiscomment -a  -t "ALBUM=\"$album\"" audio.ogg
    [ -n "$jahr" ] && vorbiscomment -a  -t "DATE=\"$jahr\"" audio.ogg
    [ -n "$genre" ] && vorbiscomment -a  -t "GENRE=\"$genre\"" audio.ogg
    [ -n "$track" ] && vorbiscomment -a  -t "TRACKNUMBER=\"$track\"" audio.ogg
    [ -n "$comment" ] && vorbiscomment -a  -t "DESCRIPTION=\"$comment\"" audio.ogg
    vorbiscomment -a -t "DESCRIPTION=\"downloaded on `date +%D` from $1 using $NAME\"" audio.ogg
fi


if [ -n "$title" -a -n "$artist" ]; then
    mv audio."$encoder" "$OPWD"/"$artist - $title"."$encoder"
else
    mv audio."$encoder" "$OPWD"/
fi

cleanup
