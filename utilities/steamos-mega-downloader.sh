#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    	  	Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	fetch-steamos.sh
# Script Ver:		0.9.7
# Description:		Fetch latest Alchemist and Brewmaster SteamOS release files
#			to specified directory and run SHA512 checks against them.
#			Allows user to then image/unzip the installer to their USB
#			drive. This NOT associated with Valve whatsover.
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
	
	This utility is NOT associated with Valve whatsover.
	
	EOF
	
}

pre_reqs()
{
	echo -e "\n==> Checking for prerequisite packages\n"
	
	#check for unzip
	distro_check=$(lsb_release -i | cut -c 17-25)
	
	if [[ "$distro_check" == "Debian" ]]; then
	
		echo -e "Distro detected: Debian"
		# set package manager
		pkginstall="apt-get install"
		sudo $pkginstall unzip git
		
	elif [[ "$distro_check" == "SteamOS" ]]; then
	
		echo -e "Distro detected: SteamOS"
		# set package manager
		pkginstall="apt-get install"
		sudo $pkginstall unzip git
	
	elif [[ "$distro_check" == "Arch" ]]; then
		
		echo -e "Distro detected: Arch Linux"
		
		# May keep a distro download hosted on libregreek for VaporOS and Stephenson's Rocket
		echo -e "Warning!: only official Valve releases are supported!"
		sleep 5s
		
		# set package manager
		pkginstall="pacman -S"
		
		# install standard set
		pkg_chk=$(pacman -Q unzip && pacman -Q git)
		if [[ "$pkg_chk" == "" ]]; then
		
			sudo $pkginstall unzip git

		fi
		
	else
	
		echo -e "Warning!: Distro not supported"
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
			
			echo -e "\n==> Enter path drive to drive (usually /run/media/...):"
			sleep 0.5s
			read -erp "Choice: " dir_choice
			
			echo -e "==> Formatting drive"
			parted "$drive_choice" mkpart primary fat32
			
			echo -e "\n==> Installing release to usb drive"
			unzip "$file" -d $dir_choice
			
		elif [[ "$file" == "SteamOSDVD.iso" ]]; then
		
			echo -e "\n==>Showing current usb drives\n"
			lsblk
			
			echo -e "\n==> Enter drive path (e.g. /dev/sdX):"
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
	
		echo -e "Skipping USB installation"
		
	fi
	
}

check_download_integrity()
{
  
	echo -e "==> Checking integrity of installer\n"
	sleep 2s
	
	# remove old MD5 and SHA files
	rm -f $md5file
	rm -f $shafile
	
	# download md5sum
	if [[ "$md5file" != "none" ]];then
	
		wget --no-clobber "$base_url/$release/$md5file"
		
	else
		
		echo -e "MD5 Check:\nNo file to check"
	
	fi
	
	# download shasum
	if [[ "$shafile" != "none" ]];then
	
		if [[ "$distro" == "stephensons" ]]; then
		
			# pull to update files
			git pull
		else
		
			# wget as normal
			wget --no-clobber "$base_url/$release/$shafile"
			
		fi
	
	else
		
		echo -e "SHA check:\nNo file to check"
	
	fi
	
	# for some reason, only the brewmaster integrity check files have /var/www/download in them
	if [[ "$release" == "alchemist" ]]; then
		
		# do nothing
		echo "" > /dev/null
		
	elif [[ "$release" == "brewmaster" ]]; then
	
		orig_prefix="/var/www/download"
		#new_prefix="$HOME/downloads/$release"
		
		if [[ "$distro" != "stephensons" ]]; then
		
			sed -i "s|$orig_prefix||g" "$HOME/downloads/$release/$shafile"
			
		fi
	
	fi
	
	# remove MD512/SHA512 line that does not match our file so we don't get check errors
	
	#trim_md512sum=$(grep -v $file "$HOME/downloads/$release/MD5SUMS")
	#trim_sha512sum=$(grep -v $file "$HOME/downloads/$release/SHA512SUMS")
	
  
	if [[ "$md5file" != "none" ]];then
	
		if [[ "$distro" != "stephensons" ]]; then
		
			# strip extra line(s) from Valve checksum file
			sed -i "/$file/!d" $md5file
			
		fi
	
		echo -e "\nMD5 Check:"
		md5sum -c "$HOME/downloads/$release/$md5file"
	
	fi
	
	if [[ "$shafile" != "none" ]];then
	
		if [[ "$distro" != "stephensons" ]]; then
		
			# strip extra line(s) from Valve checksum file
			sed -i "/$file/!d" $shafile
			
		fi
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
  	
  		echo -e "\nGithub directory exists in destination directory\nRemove or pull? (r/p)\n"
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
	
		echo -e "$file exists in destination directory\nOverwrite? (y/n)\n"
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
	
	if [[ "$distro" == "valve_official" ]]; then
	
		wget --no-clobber "$base_url/$release/$file"
		
	elif [[ "$distro" == "vaporos" ]]; then
	
		wget --no-clobber "$base_url/$release/$file"

	elif [[ "$distro" == "stephensons" ]]; then 
		
		# prereqs for Arch/Non-arch users
		
		if [[ "$distro_check" != "Arch" ]]; then
		
			# standard deps
			sudo $pkginstall apt-utils xorriso syslinux realpath isolinux
		
		elif [[ "$distro_check" == "Arch" ]]; then
			
			# standard deps
			deps="libisoburn syslinux coreutils rsync p7zip wget"
			for dep in ${deps}; do
				pkg_chk=$(pacman -Q apt)
				if [[ "$pkg_chk" == "" ]]; then
					:
				else
					$pkginstall  ${dep}
				fi
			done
			
			# apt
			pkg_chk=$(pacman -Q apt)
			if [[ "$pkg_chk" == "" ]]; then
			
				mkdir -p /tmp/apt
				wget -P /tmp "https://aur.archlinux.org/cgit/aur.git/snapshot/apt.tar.gz"
				tar -C /tmp/ -xzvf /tmp/apt.tar.gz
				cd /tmp/apt
				makepkg -sri
				rm -rf /tmp/apt/
				
			fi
		
		fi
		
		# user did not request git pull for Stephenson's repo
		if [[ "$pull" == "no" ]]; then
		
			# clone
			git clone --depth=1 https://github.com/steamos-community/stephensons-rocket.git --branch $release
			cd stephensons-rocket
			
			# remove apt-utils req for arch users (provided by apt AUR package)
			if [[ "$distro_check" == "Arch" ]]; then
				sed -i 's|apt-utils xorriso syslinux rsync wget p7zip-full realpath||g' gen.sh
			fi
			
			if [[ "$distro" == "vaporos-mod" ]]; then
			
				# clone sharkwouter's repo and build
				git clone $base_url
				cd ..
				./gen.sh -n "VaporOS" vaporos-mod
				
			else
			
				# generate "stock" iso image
				./gen.sh
				
			fi
			
			# move iso up a dir for easy md4/sha checks
			mv "rocket.iso" $base_url/$release
			mv "rocket.iso.md5" $base_url/$release
			
		# user requested git pull for stephensons repo
		elif [[ "$pull" == "yes" ]]; then
			
			# prereqs
			sudo $pkginstall apt-utils xorriso syslinux realpath isolinux
			
			# update repo
			cd stephensons-rocket
			git pull
			
			# remove apt-specific packages, handled in prereqs above
			if [[ "$distro_check" == "Arch" ]]; then
				sed -i 's|apt-utils xorriso syslinux rsync wget p7zip-full realpath||g' gen.sh
			fi
			
			# generate iso image
			./gen.sh

		fi
		
	fi
}



main()
{
	clear
	
	cat <<-EOF
	------------------------------------------------------------
	SteamOS Installer download utility | Distro:$distro_check
	------------------------------------------------------------
	For more information, see the wiki at: 
	github.com/ValveSoftware/SteamOS
	
	EOF
	
	# set base DIR
	base_dir="$HOME/downloads"

	# prompt user if they would like to load a controller config
	
	cat <<-EOF
	Please choose a release to download.
	Releases checked for integrity
	
	(1) Alchemist (standard zip, UEFI only)
	(2) Alchemist (legacy ISO, BIOS systems)
	(3) Brewmaster (standard zip, UEFI only)
	(4) Brewmaster (legacy ISO, BIOS systems)
	(5) Stephensons Rocket (Alchemist repsin)
	(6) Stephensons Rocket (Brewmaster repsin)
	(7) VaporOS (Legacy ISO)
	(8) VaporOS (Stephenson's Rocket Mod)

	EOF
  	
  	# the prompt sometimes likes to jump above sleep
	sleep 0.5s
	
	read -erp "Choice: " rel_choice
	echo ""
	
	case "$rel_choice" in
	
		1)
		distro="valve_official"
		base_url="repo.steampowered.com/download"
		release="alchemist"
		file="SteamOSInstaller.zip"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		2)
		distro="valve_official"
		base_url="repo.steampowered.com/download"
		release="alchemist"
		file="SteamOSDVD.iso"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		3)
		distro="valve_official"
		base_url="repo.steampowered.com/download"
		release="brewmaster"
		file="SteamOSInstaller.zip"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
				4)
		distro="valve_official"
		base_url="repo.steampowered.com/download"
		release="brewmaster"
		file="SteamOSDVD.iso"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		5)
		distro="stephensons"
		base_url="https://github.com/steamos-community/stephensons-rocket"
		release="alchemist"
		file="rocket.iso"
		md5file="rocket.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		;;
		
		6)
		distro="stephensons"
		base_url="https://github.com/steamos-community/stephensons-rocket"
		release="brewmaster"
		file="rocket.iso"
		md5file="rocket.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		;;
		
		7)
		distro="vaporos"
		base_url="http://trashcan-gaming.nl"
		release="iso"
		file="vaporos2.iso"
		md5file="vaporos2.iso.md5"
		shafile="none"
		;;
		
		8)
		distro="vaporos-mod"
		base_url="https://github.com/sharkwouter/vaporos-mod.git"
		release="iso"
		file="vaporos2.iso"
		md5file="vaporos2.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		
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
		image_drive
		
 	fi
 	
} 

#######################################
# Start script
#######################################

# MAIN
pre_reqs
main
