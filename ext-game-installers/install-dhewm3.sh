# TEMP WIP - DO NOT USE YET

INSTALL DHEWM3 FROM LIBREGEEK REPO

METHODS

CDROM (Does SteamOS automount in desktop mode / SSH?)

	insert disc 1
		find /media/cdrom/ -iname "*.pk4" -exec cp -v {} $DIR \;
	insert disc 2
		find /media/cdrom/ -iname "*.pk4" -exec cp -v {} $DIR \;
	insert disc 3
		find /media/cdrom/ -iname "*.pk4" -exec cp -v {} $DIR \;

STEAM

	copy from folder
		find $STEAMDIR -iname "*.pk4" -exec cp -v {} $DIR \;

CUSTOM
	
	ask for folder

COPY FILES TO DESIGNATED DIR

COPY LAUNCHER

COPY DESKTOP FILE

COPY ARTWORK
