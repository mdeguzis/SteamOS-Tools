#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	Sharkwouter, Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	gog-downloader.sh
# Script Ver:	0.1.7
# Description:	Downloads and install GOG games - IN PROGRESS!!!
#
# Usage:
# -----------------------------------------------------------------------

# Ensure downloader tool from jessie is installed
# The current stable Debian Jessie package has an issue with recaptcha prompts
# Use gogdownloader built from source code. There is also a package in strech
# backports which works as well.
if ! which lgogdownloader &> /dev/null; then

        echo -e "\ngog downloader not found, installing now...\n"
        sudo apt-get install -y --force-yes lgogdownloader 1> /dev/null

fi

# sqlite3 need to export cookies
if ! which gksu &> /dev/null; then

        echo -e "\nGKSU downloader not found, installing now....\n"
        sudo apt-get install -y --force-yes gksu 1> /dev/null

fi

# check if password is set
pw_set=$(passwd -S | cut -f2 -d " ")

if [[ "$pw_set" != "P" ]];then

        pw_response=$(zenity --question --title="Set user password" \
        --text="Admin password not set! Do you want to set it now?")

	if [[ "$pw_response" == "Yes" ]]; then

        	ENTRY=`zenity --password`

		case $? in
         	0)
         		# set value for pw
	 		adminpw=$(echo $ENTRY | cut -d'|' -f2)
	 		
	 		# echo password to passwd
	 		echo -e "${adminpw}\n${adminpw}" | passwd
	 		
	 		# unset the password to delete the value, we do not want to store it
	 		unset adminpw
	 		
			;;
         	1)
                	echo "Stop login.";;
        	-1)
                	echo "An unexpected error has occurred.";;
		esac

	else

                zenity --error --text="Admin password has to be set to be able to install GOG games."
                exit 1

        fi
fi

# login to GOG if not done yet
# There is an issue with this, as GOG uses a recaptcha now, resulting in this message if you
# Try to use the --login parameter or API:

# Login form contains reCAPTCHA (https://www.google.com/recaptcha/)
# Login with browser and export cookies to "/home/desktop/.config/lgogdownloader/cookies.txt"
# HTTP: Login failed

# Now, ask user to login to GOG.com, then close the browser if cookies.txt does not exist
COOKIE_DB="${2:-$HOME/.mozilla/firefox/*.default/cookies.sqlite}"

zenity --warning --title="Authentication" --text="GOG now uses recaptcha for authentication. \
Please loging to GOG.com and then close the browser when done. Opening browser now..."

iceweasel www.gog.com

# grab credentials
ENTRY=`zenity \
--title="Login to GOG.com" \
--text="Please login to your GOG.com account" \
--password --username`

case $? in
 0)

 	gog_email=$(echo $ENTRY | cut -d'|' -f1)
 	gog_pw=$(echo $ENTRY | cut -d'|' -f2)
 	
 	# TODO - use user/pw to login to downloader
 	# As GOG.com uses recaptcha, we must use --login-api first to export the cookies
 	#echo -e "${gog_email}\n${gog_pw}" | lgogdownloader --login-api 2> /dev/null
 	
 	# for some reason, you cannot echo your user/pw values
 	# see: https://github.com/Sude-/lgogdownloader/issues/72
 	# for now, login via prompt
 	while [ ! -f ~/.config/lgogdownloader/config.cfg ];do
        	gnome-terminal -x /bin/bash -c "echo 'Log in to GOG:'; lgogdownloader --login;"
	done
 	
 	# forget values
 	unset gog_email
 	unset gog_pw
 	
	;;
 1)
	echo "Stop login.";;
-1)
	echo "An unexpected error has occurred.";;
esac


# select game to download
game=$(zenity --list \
--column=Games \
--text="Pick a game from your GOG library to install" `lgogdownloader --list 2> /dev/null \
--platform=4`)

# download game
./lgogdownloader --download \
--platform=4 \
--include=1 --game ${game}|zenity --progress --pulsate --no-cancel --auto-close \
--text="Downloading Installer of ${game}" \
--title="Downloading Installer"

# run installer
chmod +x ${game}/gog_${game}*.sh
gksudo -u steam -P "Please enter your admin password to install ${game}" ./${game}/gog_${game}*.sh
