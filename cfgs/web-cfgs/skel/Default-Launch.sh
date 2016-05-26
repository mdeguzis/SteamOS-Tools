#!/bin/sh

main()
{

  WIN_RES=$(DISPLAY=:0 xdpyinfo | grep dimensions | awk '{print $2}')
  COMMA_WIN_RES=$(echo $WIN_RES | awk '{sub(/x/, ","); print}')

  /usr/bin/Xephyr :15 -ac -screen $WIN_RES -fullscreen -host-cursor -once & XEPHYR_PID=$!

  # For some reason, the Xephyr window never gets populated with a value for the 
  # STEAM_GAME atom. It is possible to set the property manually though
  # This may not be necessary, see discussion under issue #60
  sleep 1s
  WINDOW_ID=$(xwininfo -root -children | grep "Xephyr" | awk '{print $1}')
  xprop -id $WINDOW_ID -f "STEAM_GAME" 32c -set "STEAM_GAME" 8000

  # start antimicro mouse control
  #antimicro_tmp

  export DISPLAY=:15
  LD_PRELOAD= BROWSER_TMP --kiosk WEB_URL_TMP --window-size=$COMMA_WIN_RES &&

  sleep 1
  killall chrome
  killall antimicro
  kill $XEPHYR_PID

}

# start and log
rm -f /tmp/webapps_log.txt
main | tee /tmp/webapps_log.txt
