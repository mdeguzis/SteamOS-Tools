#! /bin/bash
#set -x

#set variables
RECORDER="avconv"
DIR=~/Videos
LOG=/tmp/dumps/${RECORDER}-recording.log
FRAMERATE=30
STARTNAME=recording
FORMAT=mkv
export DISPLAY=:0.0

# log errors
exec 2>${LOG}

# if a recording is already running, kill it and stop the script
if [[ ! -z $(ps aux|awk '{print $11}'|grep ${RECORDER}) ]]
then
	killall ${RECORDER}
	echo "${RECORDER} closed by steamos-recording.sh."2>>${LOG}
	exit 0
fi

#grab resolution
RES=$(xdpyinfo|grep dimensions|awk '{print $2}')

# make recording directory if it doesn't exist yet
mkdir -p $DIR

# set name of the recording
NUMBER=1
while [ -f $DIR/$STARTNAME$NUMBER.$FORMAT ]
do
	NUMBER=$(($NUMBER+1))
done
NAME=$STARTNAME$NUMBER

## start the recording
${RECORDER} -f pulse -i default /tmp/pulse.wav -f x11grab -r ${FRAMERATE} -s ${RES} -i ${DISPLAY} -acodec pcm_s16le -vcodec libx264 -preset ultrafast -crf 0 -threads 0 $DIR/$NAME.mkv

# In case the recording does finish/crash
rm /tmp/pulse.wav
