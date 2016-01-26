#!/bin/sh

main()
{

  # start antimicro mouse control
  #antimicro_tmp
  
  BROWSER_TMP --kiosk WEB_URL_TMP &&
  
  sleep 1
  killall chrome
  killall antimicro

}

# start and log
rm -f /tmp/webapps_log.txt
main | tee /tmp/webapps_log.txt
