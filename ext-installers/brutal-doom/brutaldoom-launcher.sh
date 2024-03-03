#!/bin/bash

main ()
{

	# Description: start gzdoom with optional controller support
	
	# start antimicro mouse control
        #antimicro_tmp

	# start gzdoom
	# Either update the version of brutaldoom's pk3 here or come up with a swapable method
	/usr/bin/gzdoom gzdoom -file /home/desktop/.config/gzdoom/brutalv20.pk3

	# kill controller profile after gzdoom exits
	killall antimicro

}

# start main and log
if [[ "$USER" == "desktop" ]]; then
	main &> /home/desktop/gzdoom-log.txt
elif [[ "$USER" == "steam" ]]; then
	main &> /home/steam/gzdoom-log.txt
fi
