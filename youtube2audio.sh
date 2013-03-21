#!/bin/bash --
#
# Shell script to convert videos from youtube to audio files
#
# Author: Christian Brabandt <cb@256bit.org>
# License: BSD

# SVN-ID: $Id$:

cleanup(){ #{{{
    # Declared here, because we need this function in trap, so it must be defined!
    if [ -d "$TMP" ]; then
        rm -rf "$TMP";
    fi
}

# Settings {{{1
# When aborting, be sure to remove the temp directory
trap 'cleanup; exit 3' 1 2 3 6 15

# abort in case of any error (-e)
# and complain about empty variables (-u)
set -e
VERSION=0.8
NAME=$(basename $0)

# Functions #{{{1

init(){ #{{{2
# Assign default values, if variables are not yet declared
youtubeopts=${youtubeopts:="-q"}
ffmpegopts=${ffmpegopts:="audio.wav"}
oggopts=${oggopts:="-q 3 -Q -o audio.ogg"}
lameopts=${lameopts:="--quiet --vbr-new"}
encoder=${encoder:="mp3"}
get=${get:="youtube-dl"}
mode=${mode:="interactive"}
opwd=$(pwd)
# Will later be initialized
unset tagg
}

help(){ #{{{2
cat <<-EOF
$NAME [OPTIONS] URL

This script downloads clips from youtube and converts the video clips
to audio files.
Downloading is performed using youtube-dl, converting to audio files
(wav) using ffmpeg and optionally converted to mp3 (using lame) or
ogg (using oggenc) and then optionally tagged.

OPTIONS can be any of the following:

     -b|--batch        Batch mode
     -i|--interactive  Interactive mode (default)
     -h|--help         Display this help screen
     --dir <directory> Store audiofile in <directory>

     Tagging Options:
     --title value   Set title for tagging the file (id3v2 or vorbis comment)
     --album value   Set album for tagging the file (id3v2 or vorbis comment)
     --genre value   Set genre for tagging the file (id3v2 or vorbis comment)
     --track value   Set track for tagging the file (id3v2 or vorbis comment)
     --artist value  Set artist for tagging the file (id3v2 or vorbis comment)
     --comment value Set comment for tagging the file (id3v2 or vorbis comment) 
     --year value    Set year for tagging the file (id3v2 or vorbis comment) 
     --lametag       Use lame for tagging the file (only usable with mp3)

     Download Options:
     --youtube-dl     Use youtube-dl for downloading (default)
     --clive          Use clive for downloading 

     Encoder Options:
     --lameopts value      Specify Options for lame 
                     (default "$lameopts")
     --ffmpegopts value   Specify ffmpeg options (default
                     "$ffmpegopts")
     --youtubeopts value   Specify Youtube-dl options (default "$youtubeopts")
     --oggopts value       Specify oggenc options
                     (default "$oggopts")

     Output Format:
     --mp3           Encode to mp3
     --wav           Do not encode, only convert to a plain wav file
     --ogg           Encode to ogg

By default, $NAME will simply retrieve the specified video from
youtube and encode it to mp3. If batch mode is not specified $NAME
will query interactively for Tags to use with id3v2. Any tag that is
left empty will not be set. If an ogg file is generated, it will use
vorbiscomment to tag the file. Obviously, when creating plain wav
files, tagging makes no sense.

Instead of writing lengthy options for youtube-dl,ffmpeg,ogg or lame
you can simply specify environment variables that are named like the
option (so use \$lameopts, \$oggopts, \$ffmpegopts and \$youtubeopts). 
When these options are specified as environment variables, they will
override the default, while when specified as option to $NAME,
they will be appended to their default values.
   
Version: $VERSION
EOF
exit 0;
}

check(){ #{{{2
if [ "$encoder" == "ogg" ]; then
    comp=oggenc
    tagg=vorbiscomment
elif [ "$encoder" == "mp3" ]; then
    comp=lame
    if [ -z "$tagg" ]; then
        tagg=id3v2
    fi
fi

if [ "$get" == "youtube-dl" ] ; then
    out="-o"
else
    out="-O"
fi

#for i in ffmepg youtube-dl $comp $tagg ; do
for i in ffmpeg $get $comp $tagg ; do
   which "$i" >/dev/null || { echo "$i not found; exiting" && exit 3; }
done

}

debug(){ #{{{2
     # Debugging
     echo "youtubeopts: $youtubeopts"
     echo "ffmpegopts: $ffmpegopts"
     echo "oggopts: $oggopts"
     echo "lameopts: $lameopts"
     echo "encoder: $encoder"
     echo "mode: $mode"
     echo "opwd: $opwd"
     echo "tagg: $tagg"
     echo "URL: $1"
     exit 4
}

move_files(){ #{{{2
if [ -n "$title" -a -n "$artist" ]; then
    title=$(echo "$title"| tr '/\\' '-')
    artist=$(echo "$artist" | tr '/\\' '-')
    mv audio."$encoder" "$opwd"/"$artist - $title"."$encoder"
else
    mv audio."$encoder" "$opwd"/audio_"$(date +%Y%m%d)"."$encoder"
fi
}

input_tags() { #{{{2

    if [ "$mode" == "interactive" ]; then 
        echo 'Enter Values (leave blank if you do not know)!'
        [ -z "$title" ]    &&  read -p"Titel:      " title  && title=$(encode    "$title")
        [ -z "$artist" ]   &&  read -p"Interpret:  " artist && artist=$(encode   "$artist")
        [ -z "$album" ]    &&  read -p"Album:      " album  && album=$(encode    "$album")
        [ -z "$jahr" ]     &&  read -p"Jahr:       " jahr   && jahr=$(encode     "$jahr")
        [ -z "$genre" ]    &&  read -p"Genre:      " genre  && genre=$(encode    "$genre")
        [ -z "$track" ]    &&  read -p"Tracknr:    " track  && track=$(encode    "$track")
        [ -z "$comment" ]  &&  read -p"Comment:    " comment && comment=$(encode "$comment")
    fi

}

encode() { #{{{2
    if [ "$encoder" == "mp3" -a "$tagg" == "id3v2" ]; then
        enc='latin1'
    else
        enc='utf8'
    fi
    tag=$(printf "%s" "$(echo "$1" |iconv -t "$enc")")
    printf "%s" "$tag"

}

init

if [ "$#" -eq 0 ]; then
    help;
fi

args=$(getopt -o bhi -l title:,album:,genre:,track:,artist:,comment:,year:,lameopts:,ffmpegopts:,youtubeopts:,dir:,ogg,oggopts:,batch,wav,mp3,interactive,help,clive,youtube-dl,lametag -n "$NAME" -- "$@")
if [ $? != 0 ] ; then echo "Error Parsing Commandline...Exiting" >&2; exit 1; fi
eval set -- "$args"

while [ ! -z "$1" ]; do
    case "$1" in
        --title)              title="$2"; shift 2 ;;
        --album)              album="$2"; shift 2 ;;
        --genre)              genre="$2"; shift 2 ;;
        --track)              track="$2"; shift 2 ;;
        --artist)             artist="$2"; shift 2 ;;
        --comment)            comment="$2"; shift 2 ;;
        --year)               jahr="$2"; shift 2 ;;
        --lameopts)           lameopts+=" $2"; shift 2 ;;
        --ffmpegopts)         ffmpegopts+=" $2"; shift 2 ;;
        --youtubeopts)        youtubeopts+=" $2"; shift 2 ;;
        --oggopts)            oggopts+=" $2"; shift 2 ;;
        --ogg)                encoder="ogg"; shift ;;
        --lame)               encoder="mp3"; shift ;;
        --mp3)                encoder="mp3"; shift ;;
        --lametag)            tagg="lame"; shift ;;
        --wav)                encoder="wav"; shift ;;
        --dir)                opwd="$2"; shift 2 ;;
        --clive)              get="clive"; shift ;;
        --youtube-dl)         get="youtube-dl"; shift ;;
        -b|--batch)           mode="batch"; shift ;;
        -i|--interactive)     mode="interactive"; shift ;;
        -h|--help)            help ;; 
        --)                   shift ; break ;;
    esac

done


# Main #{{{1

check

# For debugging enable the following line
# debug $1

[ -w "$opwd" ] || { echo "$opwd is not writable... exiting"; exit 5; }

if [ ! -f "$1" ]; then
    TMP=$(mktemp -d)

    # Download, decode and encode #{{{2
    # download flash video
    cd "$TMP"
    # Get Tags
    input_tags
    echo "Downloading Video using $get"
    $get $youtubeopts $out youtube.flv "$1" 
    echo "Dumping Audio"
    ffmpeg -i youtube.flv $ffmpegopts 
else
    # Get Tags
    input_tags
    echo "Dumping Audio"
    mplayer -i "$1" $ffmpegopts "$1"
fi
echo "Encoding Audio" #{{{2

if [ "$encoder" == "mp3" ]; then
    if [ "$tagg" == "lame" ]; then
        # use lame for tagging
        lame $lameopts --tt "$title" \
        --ta "$artist" \
        --tl "$album" \
        --ty "$jahr" \
        --tg "$genre" \
        --tn "$track" \
        --tc "$comment" \
        --ignore-tag-errors \
        audio.wav audio.mp3
    else
        lame $lameopts audio.wav audio.mp3
    fi

elif [ "$encoder" == "ogg" ]; then
    oggenc $oggopts audio.wav
fi

echo "Tagging" #{{{2

if [ "$encoder" == "mp3" ]; then

    if [ "$tagg" == "id3v2" ]; then

        [ -n "$title" ]   && id3v2 -t "$title" audio.mp3
        [ -n "$artist" ]  && id3v2 -a "$artist" audio.mp3
        [ -n "$album" ]   && id3v2 -A "$album" audio.mp3
        [ -n "$jahr" ]    && id3v2 -y "$jahr" audio.mp3
        [ -n "$genre" ]   && id3v2 -g "$genre" audio.mp3
        [ -n "$track" ]   && id3v2 -T "$track" audio.mp3
        [ -n "$comment" ] && id3v2 -c "$comment" audio.mp3
        if [ ! -f "$1" ]; then
            id3v2 -c "info: downloaded on `date +%D` from ${1##http://} using $NAME" audio.mp3
        fi

    fi

elif [ "$encoder" == "ogg" ]; then

        [ -n "$title" ]   && vorbiscomment -a  -t "TITLE=$title" audio.ogg
        [ -n "$artist" ]  && vorbiscomment -a  -t "ARTIST=$artist" audio.ogg
        [ -n "$album" ]   && vorbiscomment -a  -t "ALBUM=$album" audio.ogg
        [ -n "$jahr" ]    && vorbiscomment -a  -t "DATE=$jahr" audio.ogg
        [ -n "$genre" ]   && vorbiscomment -a  -t "GENRE=$genre" audio.ogg
        [ -n "$track" ]   && vorbiscomment -a  -t "TRACKNUMBER=$track" audio.ogg
        [ -n "$comment" ] && vorbiscomment -a  -t "DESCRIPTION=$comment" audio.ogg
        if [ ! -f "$1" ]; then
            vorbiscomment -a -t "DESCRIPTION=\"downloaded on `date +%D` from $1 using $NAME\"" audio.ogg
        fi
fi


move_files

cleanup #}}}

# vim: ft=sh fdm=marker et
