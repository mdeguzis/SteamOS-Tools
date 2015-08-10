#!/bin/bash

main ()
{

	# Description: start gzdoom with optional controller support
	
	# start antimicro mouse control
        #antimicro_tmp

	# start gzdoom
	/usr/bin/gzdoom

	# kill controller profile after gzdoom exits
	killall antimicro

}

# start main and log
if [[ "$USER" == "desktop" ]]; then
	main &> /home/desktop/gzdoom-log.txt
elif [[ "$USER" == "steam" ]]; then
	main &> /home/steam/gzdoom-log.txt
fi
