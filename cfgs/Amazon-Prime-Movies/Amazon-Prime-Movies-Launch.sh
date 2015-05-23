#!/bin/sh

main ()
{

	WIN_RES=$(DISPLAY=:0 xdpyinfo | grep dimensions | awk '{print $2}')
	COMMA_WIN_RES=$(echo $WIN_RES | awk '{sub(/x/, ","); print}')

	/usr/bin/Xephyr :15 -ac -screen $WIN_RES -fullscreen -host-cursor -once & XEPHYR_PID=$!

	export DISPLAY=:15
	LD_PRELOAD= google-chrome --kiosk http://www.amazon.com/Prime-Instant-Video/b?node=2676882011 --window-size=$COMMA_WIN_RES &&

	sleep 1
	killall chrome
	kill $XEPHYR_PID

}

# start main and log
main &> /home/steam/chrome-log.txt
Enter file contents here
