#! /bin/bash

#set variables
DIR=~/Videos
FRAMERATE=30
STARTNAME=recording
FORMAT=avi
export DISPLAY=:0.0

#grab resolution
RES=$(xdpyinfo|grep dimensions|awk '{print $2}')

# make recording directories if they don't exist yet
if [ ! -d ${DIR} ]
then
mkdir $DIR
fi

# set name of the recording
DATE=$(date +"_%Y%m%d")
NUMBER=1
while [ -f $DIR/$STARTNAME$NUMBER.$FORMAT ]
do
NUMBER=$(($NUMBER+1))
done
NAME=$STARTNAME$NUMBER$DATE 

# start the recording
avconv -f pulse -i default /tmp/pulse.wav -f x11grab -r ${FRAMERATE} -s $RES -i $DISPLAY -acodec pcm_s16le -vcodec libx264 -preset ultrafast -crf 0 -threads 0 $DIR/$NAME.avi

# In case the recording does finish/crash
rm /tmp/pulse.wav
