#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  	Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	fetch-steamos.sh
# Script Ver:		0.9.5
# Description:		Fetch latest Alchemist and Brewmaster SteamOS release files
#			to specified directory and run SHA512 checks against them.
#			Allows user to then image/unzip the installer to their USB
#			drive.
#
# Usage:      		./fetch-steamos.sh 
#			./fetch-steamos.sh --help
#			./fetch-steamos.sh --checkonly
# -------------------------------------------------------------------------------

arg1="$1"

help()
{
	
	clear
	cat <<-EOF
	#####################################################
	Help file
	#####################################################
	
	Usage:
	
	./fetch-steamos.sh 		-fetch release, checked for file integrity
	./fetch-steamos.sh --help	-show this help file
	./fetch-steamos.sh --checkonly	-Check existing release files (if exist)
	
	EOF
	
}

pre_reqs()
{
	echo -e "\n==> Checking for prerequisite packages\n"
	
	#check for unzip
	distro_check=$(uname -r)
	
	if [[ "$distro_check" == "*Debian*" ]]; then
	
		echo -e "Distro detected: Debian variant"
		# set package manager
		pkginstall="apt-get install"
		sudo $pkginstall unzip git
	
	elif [[ "$distro_check" =~ "ARCH" ]]; then
		echo -e "Distro detected: Arch Linux variant"
		# set package manager
		pkginstall="pacman -S"
		sudo $pkginstall unzip git
	
		# Stephensons vairants require apt-tools, not included YET
		echo -e "Distro detected: Arch Linux variant"
		echo -e "Warning: Only official Valve releases are supported at this time"
		sleep 5s
	else
	
		echo -e "Warning: Distro not supported"
		sleep 3s
		exit 1
		
	fi
	
}

image_drive()
{
	
	echo -e "\nImage SteamOS to drive? (y/n)"
	read -erp "Choice: " usb_choice
	echo ""
	
	if [[ "$usb_choice"  == "y" ]]; then
	
		if [[ "$file" == "SteamOSInstaller.zip" ]]; then
			
			echo -e "\n==>Showing current usb drives\n"
			lsblk
			
			echo -e "\n==> Enter drive path: "
			sleep 0.5s
			read -erp "Choice: " drive_choice
			
			echo -e "==> Formatting drive"
			parted "$drive_choice" mkpart primary fat32
			
			echo -e "\n==> Installing release to usb drive"
			unzip "$file" -d $drive_choice
			
		elif [[ "$file" == "SteamOSDVD.iso" ]]; then
		
			echo -e "\n==>Showing current usb drives\n"
			lsblk
			
			echo -e "\n==> Enter drive path: "
			sleep 0.5s
			read -erp "Choice: " drive_choice
			
			echo -e "\n==> Installing release to usb drive"
			sudo dd bs=1M if="$file" of="$drive_choice"
			
		else
		
			echo -e "\nAborting..."
			clear
			exit 1
			
		fi
		
	elif [[ "$usb_choice"  == "n" ]]; then
	
		echo -e "\nSkipping USB installation"
		
	fi
	
}

check_download_integrity()
{
  
	echo -e "\n==> Checking integrity of installer\n"
	sleep 2s
	
	# remove old MD5 and SHA files
	rm -f $md5file
	rm -f $shafile
	
	# download md5sum
	if [[ "$md5file" != "none" ]];then
	
		wget --no-clobber "$base_url/$release/$md5file"
		
	else
		
		echo -e "Integrity check skipped, no md5 file to check"
	
	fi
	
	# download shasum
	if [[ "$shafile" != "none" ]];then
	
		wget --no-clobber "$base_url/$release/$shafile"
		
	else
		
		echo -e "Integrity check skipped, no sha file to check"
	
	fi
	
	# for some reason, only the brewmaster integrity check files have /var/www/download in them
	if [[ "$release" == "alchemist" ]]; then
		
		# do nothing
		echo "" > /dev/null
		
	elif [[ "$release" == "brewmaster" ]]; then
	
		orig_prefix="/var/www/download"
		#new_prefix="$HOME/downloads/$release"
		
		sed -i "s|$orig_prefix||g" "$HOME/downloads/$release/$shafile"
	
	fi
	
	# remove MD512/SHA512 line that does not match our file so we don't get check errors
	
	#trim_md512sum=$(grep -v $file "$HOME/downloads/$release/MD5SUMS")
	#trim_sha512sum=$(grep -v $file "$HOME/downloads/$release/SHA512SUMS")
	
  
	if [[ "$md5file" != "none" ]];then
	
		sed -i "/$file/!d" $md5file
		sed -i "/$file/!d" $shafile
	
		echo -e "\nMD5 Check:"
		md5sum -c "$HOME/downloads/$release/$md5file"
	
	fi
	
	if [[ "$shafile" != "none" ]];then
	
		sed -i "/$file/!d" $md5file
		sed -i "/$file/!d" $shafile
	
		echo -e "\nSHA512 Check:"
		sha512sum -c "$HOME/downloads/$release/$shafile"
		
	fi
  
}

check_file_existance()
{
	
	# check fo existance of dirs
	if [[ ! -d "$HOME/downloads/$release" ]]; then
		mkdir -p "$HOME/downloads/$release"
	fi
  
  	# check for git repo existance (stephesons rocket)
  	if [[ -d "$HOME/downloads/$release/stephensons-rocket" ]]; then
  	
  		echo -e "\n$Github directory exists in destination directory\nRemove or pull? (r/p)\n"
		read -erp "Choice: " rdl_choice
		echo ""
  	
	  	if [[ "$rdl_choice" == "r" ]]; then
			
			# do not pull directory in downdload section
			pull="no"
			# Remove file and download again
			rm -rf "$HOME/downloads/$release/stephensons-rocket"
			download_release
				
		elif [[ "$rdl_choice" == "p" ]]; then
				
			# pull directory in downdload section
			pull="yes"
			# Abort script and exit to prompt
			echo -e "Skipping download..."
			sleep 2s
	
	  	else
	  		
	  		# File does not exist, download release
	  		download_release
	  	
	  	fi
	  	
	 fi
  	
	# check for file existance (Valve releases)
	if [[ -f "$HOME/downloads/$release/$file" ]]; then
	
		echo -e "\n$file exists in destination directory\nOverwrite? (y/n)\n"
		read -erp "Choice: " rdl_choice
		echo ""
		
		if [[ "$rdl_choice" == "y" ]]; then
		
			# Remove file and download again
			rm -rf "$HOME/downloads/$release/$file"
			download_release
			
		else
		
			# Abort script and exit to prompt
			echo -e "Skipping download..."
			sleep 2s
			
		fi

  	else
  		
  		# File does not exist, download release
  		download_release
  	
  	fi
	
}

download_release()
{
	
	# enter base directory for release
	cd "$HOME/downloads/$release"
	
	# download requested file (Valve official)
	
	if [[ "$file" == "SteamOSInstaller.zip" || "file" == "SteamOSDVD.iso" ]]; then
	
		wget --no-clobber "$base_url/$release/$file"
		
	elif [[ "$file" == "vaporos2.iso" ]]; then
	
		wget --no-clobber "$base_url/$release/$file"
	
	elif [[ "$file" == "stephensons.iso" ]]; then 
		
		if [[ "$pull" == "no" ]]; then
		
			# prereqs
			sudo apt-get install apt-utils
			
			# clone
			git clone --depth=1 https://github.com/steamos-community/stephensons-rocket.git --branch $release
			cd stephensons-rocket
			
			# generate iso image
			./gen.sh
			
		elif [[ "$pull" == "yes" ]]; then
			
			# update repo
			cd stephensons-rocket
			git pull
			
			# generate iso image
			./gen.sh

		fi
		
	fi
}



main()
{
	
	cat <<-EOF
	------------------------------------------------------
	SteamOS Installer download utility
	------------------------------------------------------
	
	EOF
	
	# set base DIR
	base_dir="$HOME/downloads"

  	clear
  	# prompt user if they would like to load a controller config
  	echo -e "Please choose a release to download. Releases checked for integrity\n"
  	echo "(1) Alchemist (standard zip, UEFI only)"
  	echo "(2) Alchemist (legacy ISO, BIOS systems)"
  	echo "(3) Brewmaster (standard zip, UEFI only)"
  	echo "(4) Brewmaster (legacy ISO, BIOS systems)"
  	echo "(5) Stephensons Rocket (Alchemist repsin)"
  	echo "(6) Stephensons Rocket (Brewmaster repsin)"
  	echo "(7) VaporOS (Legacy ISO)"
  	echo "(8) VaporOS (Stephenson's Rocket Mod)"
  	echo ""
  	
  	# the prompt sometimes likes to jump above sleep
	sleep 0.5s
	
	read -erp "Choice: " rel_choice
	
	case "$rel_choice" in
	
		1)
		base_url="repo.steampowered.com/download"
		release="alchemist"
		file="SteamOSInstaller.zip"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		#image_drive
		;;
		
		2)
		base_url="repo.steampowered.com/download"
		release="alchemist"
		file="SteamOSDVD.iso"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		#image_drive
		;;
		
		3)
		base_url="repo.steampowered.com/download"
		release="brewmaster"
		file="SteamOSInstaller.zip"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		#image_drive
		;;
		
		4)
		base_url="repo.steampowered.com/download"
		release="brewmaster"
		file="SteamOSDVD.iso"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		#image_drive
		;;
		
		5)
		base_url="https://github.com/steamos-community/stephensons-rocket"
		release="alchemist"
		file="stephensons.iso"
		md5file="none"
		shafile="none"
		# set github default action
		pull="no"
		#image_drive
		;;
		
		6)
		base_url="https://github.com/steamos-community/stephensons-rocket"
		release="brewmaster"
		file="stephensons.iso"
		md5file="none"
		shafile="none"
		# set github default action
		pull="no"
		#image_drive
		;;
		
		7)
		base_url="http://trashcan-gaming.nl"
		release="iso"
		file="vaporos2.iso"
		md5file="vaporos2.iso.md5"
		shafile="none"
		#image_drive
		;;
		
		8)
		base_url="https://github.com/sharkwouter/vaporos-mod"
		release="iso"
		file="vaporos2.iso"
		md5file="vaporos2.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		#image_drive
		;;
		
		*)
		echo "Invalid Input, exiting"
		exit 1
		;;
	
	esac
	
	# assess if download is needed
	if [[ "$arg1" == "--checkonly" ]]; then
 
 		# just check integrity of files
 		cd "$HOME/downloads/$release"
 		check_download_integrity
 		
 	else
 		# Check for and download release
 		check_file_existance
 		download_release
		check_download_integrity
		
 	fi
 	
} 

#######################################
# Start script
#######################################

# MAIN
pre_reqs
main
