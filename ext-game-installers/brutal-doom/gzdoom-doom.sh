#!/bin/sh

main ()
{

	# Description: start gzdoom with optional controller support
	
	# start antimicro mouse control
        #antimicro_tmp

	# start gzdoom
	gzdoom

	# kill controller profile after gzdoom exits
	killall antimicro

}

# start main and log
main &> /home/steam/gzdoom-log.txt
