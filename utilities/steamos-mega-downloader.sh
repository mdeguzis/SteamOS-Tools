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
	
	Please note:
	Stephenson's Rocket and VaporOS are not official Valve releases of SteamOS.
	
	This utility is NOT associated with Valve whatsover.
	
	EOF
	
}

pre_reqs()
{
	# check fo existance of dirs
	if [[ ! -d "$HOME/downloads/$release" ]]; then
		mkdir -p "$HOME/downloads/$release"
	fi
	
	echo -e "\n==> Checking for prerequisite packages\n"
	
	#check for distro name
	distro_check=$(lsb_release -i | cut -c 17-25)
	
	############################################
	# Debian
	############################################
	if [[ "$distro_check" == "Debian" ]]; then
	
		echo -e "Distro detected: Debian"
		
		deps="apt-utils xorriso syslinux rsync wget p7zip-full realpath"
		for dep in ${deps}; do
			pkg_chk=$(dpkg-query -s ${dep})
			if [[ "$pkg_chk" == "" ]]; then
				sudo apt-get install ${dep}
				
				if [[ $? = 100 ]]; then
					echo -e "Cannot install ${dep}. Please install this manually \n"
					exit 1
				fi
				
			else
				echo "package ${dep} [OK]"
			fi
		done
		
	############################################
	# SteamOS
	############################################
	elif [[ "$distro_check" == "SteamOS" ]]; then

		# Debian sources are required to install xorriso for Stephenson's Rocket
		sources_check1=$(sudo find /etc/apt -type f -name "jessie*.list")
		sources_check2=$(sudo find /etc/apt -type f -name "wheezy*.list")
		
		if [[ "$sources_check1" == "" && "$sources_check2" == "" ]]; then
		
			echo -e "==WARNING==\nDebian sources are needed for xorriso, add now? (y/n)"
			read -erp "Choice: " sources_choice
		
			if [[ "$sources_choice" == "y" ]]; then
				../add-debian-repos.sh
			elif [[ "$sources_choice" == "n" ]]; then
				echo -e "Sources addition skipped"
			fi
			
		fi
		
		# Note: added isolinux, as syslinux contained within SteamOS does not contain
		# isohdpfx.bin, but isolinux does.
		deps="apt-utils xorriso syslinux rsync wget p7zip-full realpath isolinux"
		for dep in ${deps}; do
			pkg_chk=$(dpkg-query -s ${dep})
			if [[ "$pkg_chk" == "" ]]; then
				sudo apt-get install ${dep}
				
				if [[ $? = 100 ]]; then
					echo -e "Cannot install ${dep}. Please install this manually \n"
					exit 1
				fi
				
			else
				echo "package ${dep} [OK]"
				sleep .3s
			fi
		done
	
	############################################
	# Arch Linux
	############################################
	elif [[ "$distro_check" == "Arch" ]]; then
		
		echo -e "Distro detected: Arch Linux"
		echo -e "Only official Valve releases are supported at this time!\n"
		sleep 2s
		
		# Check dependencies (stephensons and vaporos-mod)
		deps="libisoburn syslinux coreutils rsync p7zip wget unzip git"
		for dep in ${deps}; do
			pkg_chk=$(pacman -Q ${dep})
			if [[ "$pkg_chk" == "" ]]; then
				sudo pacman -S  ${dep}
				
				if [[ $? = 100 ]]; then
					echo -e "Cannot install ${dep}. Please install this manually \n"
					exit 1
				fi
				
			else
				echo "package ${dep} [OK]"
				sleep .3s
			fi
		done
			
		# apt (need for stephenson's rocket / vaporos-mod)
		pkg_chk=$(pacman -Q apt)
		if [[ "$pkg_chk" == "" ]]; then
		
			mkdir -p /tmp/apt
			wget -P /tmp "https://aur.archlinux.org/cgit/aur.git/snapshot/apt.tar.gz"
			tar -C /tmp/ -xzvf /tmp/apt.tar.gz
			cd /tmp/apt
			makepkg -sri
			rm -rf /tmp/apt/
			
		fi
	
	############################################
	# All Others
	############################################	
	else
	
		echo -e "Warning!: Distro not supported"
		sleep 3s
		exit 1
		
	fi
	
	echo ""
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
			parted "$drive_choice" mktable msdos
			parted "$drive_choice" mkpart primary fat32 1024 100%
			
			echo -e "\n==> Installing release to usb drive"
			unzip "$file" -d $dir_choice
			
		elif [[ "$file" == "SteamOSDVD.iso" || \
			$file" == "rocket.iso ]]; then
		
			echo -e "\n==> Showing current usb drives\n"
			lsblk
			
			echo -e "\n==> Enter drive path (e.g. /dev/sdX):"
			sleep 0.5s
			read -erp "Choice: " drive_choice
			
			echo -e "\n==> Installing release to usb drive"
			sudo dd bs=1M if="$file" of="$drive_choice"
		
			
		else
		
			echo -e "\nRelease not supported for this operation. Aborting..."
			clear
			exit 1
			
		fi
		
	elif [[ "$usb_choice"  == "n" ]]; then
	
		echo -e "Skipping USB installation"
		
	fi
	
}

check_download_integrity()
{
  
	echo -e "\n==> Checking integrity of installer\n"
	sleep 2s
	
	# download md5sum
	if [[ "$md5file" != "none" ]];then
	
		if [[ "$distro" == "stephensons-rocket" ]]; then
		
			# This is handled during build
			echo "" > /dev/null
			
		elif [[ "$distro" == "vaporos" ]]; then
		
			wget --no-clobber "$base_url/iso/$md5file"
		
		else
			wget --no-clobber "$base_url/$release/$md5file"
			
		fi
		
	else
		
		echo -e "MD5 Check:\nNo file to check"
	
	fi
	
	# download shasum
	if [[ "$shafile" != "none" ]];then
	
		if [[ "$distro" == "stephensons-rocket" ]]; then
		
			# This is handled during build
			echo "" > /dev/null
			
		elif [[ "$distro" == "vaporos" ]]; then
		
			# no shafile currently for release
			echo "" > /dev/null
		
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
	
		orig_prefix="/var/www/download/brewmaster/"
		#new_prefix="$HOME/downloads/$release"
		
		if [[ "$distro" == "valve-official" ]]; then
		
			sed -i "s|$orig_prefix||g" "$HOME/downloads/$release/$shafile"
			sed -i "s|$orig_prefix||g" "$HOME/downloads/$release/$md5file"
			
		fi
	
	fi
	
	# Check md5sum of installer
	if [[ "$md5file" != "none" ]];then
	
		if [[ "$distro" == "valve-official" ]]; then
		
			# strip extra line(s) from Valve checksum file
			sed -i "/$file/!d" $md5file
			
		fi
	
		echo -e "\nMD5 Check:"
		md5sum -c "$HOME/downloads/$release/$md5file"
	
	fi
	
	# Check sha512sum of installer
	if [[ "$shafile" != "none" ]];then
	
		if [[ "$distro" == "valve-official" ]]; then
		
			# strip extra line(s) from Valve checksum file
			sed -i "/$file/!d" $shafile
			
		fi
		echo -e "\nSHA512 Check:"
		sha512sum -c "$HOME/downloads/$release/$shafile"
		
	fi
  
}

download_valve_steamos()
{
	# Downloads singular file (mainly ISO images or Valve's installers)
	# Also used for legacy VaporOS (ISO image)
	
	# remove previous files if desired
	if [[ "$HOME/downloads/$release/$file" ]]; then
		
		echo -e "\n$file exists, overwrite? (y/n)"
		# get user choice
		read -erp "Choice: " rdl_choice
		
		if [[ "$rdl_choice" == "y" ]]; then
		
			# remove and download
			rm -f "$HOME/downloads/$release/$file"
			rm -f "$HOME/downloads/$release/$md5file"
			rm -f "$HOME/downloads/$release/$shafile"
			wget --no-clobber "$base_url/$release/$file"
			
		elif [[ "$rdl_choice" == "n" ]]; then
		
			# remove so download sequence fetchs fresh checksums
			rm -f "$HOME/downloads/$release/$md5file"
			rm -f "$HOME/downloads/$release/$shafile"
			# download main file, no removal
			wget --no-clobber "$base_url/$release/$file"
	
		fi
	else
	
		# file does not exist, download
		wget --no-clobber "$base_url/$release/$file"
		
	fi
	
}

download_vaporos_legacy()
{
	# Downloads singular file (mainly ISO images or Valve's installers)
	# Also used for legacy VaporOS (ISO image)
	
	# remove previous files if desired
	if [[ "$HOME/downloads/$release/$file" ]]; then
		
		echo -e "\n$file exists, overwrite? (y/n)"
		# get user choice
		read -erp "Choice: " rdl_choice
		
		if [[ "$rdl_choice" == "y" ]]; then
		
			# remove and download
			rm -f "$HOME/downloads/$release/$file"
			rm -f "$HOME/downloads/$release/$md5file"
			rm -f "$HOME/downloads/$release/$shafile"
			wget --no-clobber "$base_url/iso/$file"
			
		elif [[ "$rdl_choice" == "n" ]]; then
		
			# remove so download sequence fetchs fresh checksums
			rm -f "$HOME/downloads/$release/$md5file"
			rm -f "$HOME/downloads/$release/$shafile"
			# download main file, no removal
			wget --no-clobber "$base_url/iso/$file"
	
		fi
	else
	
		# file does not exist, download
		wget --no-clobber "$base_url/iso/$file"
		
	fi
	
}

download_stephensons()
{
	# Downloads and builds iso/checksum for Stephenson's Rocket or
	# VaporOS-Mod
	
	# try git pull first
	
	if [[ -d "$HOME/downloads/$release/$distro" ]]; then
	
		echo -e "==INFO==\nGit DIR exists, trying remote pull"
		sleep 2s
	
		# change to git folder
		cd "$HOME/downloads/$release/$distro"
		
		# remove previous ISOs and checksum (if exists)
		rm -f "SteamOSDVD.iso"
		rm -f "rocket.iso"
		rm -f "rocket.iso.md5"
		
		# eval git status
		output=$(git pull)
		
		# set fallback if there is an issue upstream (will use professorkaos64 fork below)
		# Fallback set: 20150901
		# See: https://github.com/steamos-community/stephensons-rocket/pull/111
		fallback="true"
		
		# evaluate git pull. Remove, create, and clone if it fails
		if [[ "$output" != "Already up-to-date." || "$fallback" == "true" ]]; then
	
			echo -e "\n==Info==\nGit directory pull failed. Removing and cloning\n"
			sleep 2s
			rm -rf "$HOME/downloads/$release/$distro"
			# git clone --depth=1 https://github.com/steamos-community/stephensons-rocket.git --branch $release
		
			# Backup repo if there is an issue that can be fixed in the interim until PR is merged
			# by DirectHex
			git clone --depth=1 https://github.com/professorkaos64/stephensons-rocket.git --branch $release
		
			# Enter git repo
			cd stephensons-rocket
	
		else
		
			# echo output
			echo -e "$output\n"
		fi
	
	else
		# git dir does not exist, clone
		# git clone --depth=1 https://github.com/steamos-community/stephensons-rocket.git --branch $release
		
		# Backup repo if there is an issue that can be fixed in the interim until PR is merged
		# by DirectHex
		git clone --depth=1 https://github.com/professorkaos64/stephensons-rocket.git --branch $release
		
		# Enter git repo
		cd stephensons-rocket
	
	fi
	
	# remove apt-specific packages, handled in pre_req function
	if [[ "$distro_check" == "Arch" ]]; then
		sed -i 's|apt-utils xorriso syslinux rsync wget p7zip-full realpath||g' gen.sh
	fi
	
	# Generate image andchecksum files
	if [[ "$distro" == "vaporos-mod" ]]; then
	
		# clone sharkwouter's repo and build
		git clone $base_url
		cd ..
		./gen.sh -n "VaporOS" vaporos-mod
		
	else
	
		# generate "stock" iso image
		./gen.sh
		
	fi
	
	# move iso up a dir for easy md5/sha checks and for storage
	echo -e "\n==> Transferring files to release folder\n"
	sleep 2s
	mv -v "rocket.iso" "$HOME/downloads/$release/"
	mv -v "rocket.iso.md5" "$HOME/downloads/$release/"
	
	# move to release folder for checksum validation
	cd "$HOME/downloads/$release"

}

download_release_main()
{
	
	# enter base directory for release
	cd "$HOME/downloads/$release"
	
	# download requested file (Valve official)
	if [[ "$distro" == "valve-official" ]]; then
	
		download_valve_steamos
	
	# download requested file (VaporOS legacy)	
	elif [[ "$distro" == "vaporos" ]]; then
	
		download_vaporos_legacy

	# download requested file (Stephenson's Rocket variant)
	elif [[ "$distro" == "stephensons-rocket" ]]; then 
		
		download_stephensons
		
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
	github.com/ValveSoftware/SteamOS/wiki
	
	EOF
	
	# set base DIR
	base_dir="$HOME/downloads"

	# prompt user if they would like to load a controller config
	
	cat <<-EOF
	Please choose a release to download.
	Releases are checked for integrity
	
	(1) Alchemist (standard zip, UEFI only)
	(2) Alchemist (legacy ISO, BIOS systems)
	(3) Brewmaster (standard zip, UEFI only)
	(4) Brewmaster (legacy ISO, BIOS systems)
	(5) Stephensons Rocket (Alchemist repsin)
	(6) Stephensons Rocket (Brewmaster repsin)
	(7) VaporOS (Alchemist, Legacy ISO)
	(8) VaporOS (Alchemist, Stephenson's Rocket Mod)
	(9) VaporOS (Brewmaster, Stephenson's Rocket Mod)

	EOF
  	
  	# the prompt sometimes likes to jump above sleep
	sleep 0.5s
	
	read -erp "Choice: " rel_choice
	echo ""
	
	case "$rel_choice" in
	
		1)
		distro="valve-official"
		base_url="repo.steampowered.com/download"
		release="alchemist"
		file="SteamOSInstaller.zip"
		git="no"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		2)
		distro="valve-official"
		base_url="repo.steampowered.com/download"
		release="alchemist"
		file="SteamOSDVD.iso"
		git="no"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		3)
		distro="valve-official"
		base_url="repo.steampowered.com/download"
		release="brewmaster"
		file="SteamOSInstaller.zip"
		git="no"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		4)
		distro="valve-official"
		base_url="repo.steampowered.com/download"
		release="brewmaster"
		file="SteamOSDVD.iso"
		git="no"
		md5file="MD5SUMS"
		shafile="SHA512SUMS"
		;;
		
		5)
		distro="stephensons-rocket"
		base_url="https://github.com/steamos-community/stephensons-rocket"
		release="alchemist"
		file="rocket.iso"
		git="yes"
		md5file="rocket.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		;;
		
		6)
		distro="stephensons-rocket"
		base_url="https://github.com/steamos-community/stephensons-rocket"
		release="brewmaster"
		file="rocket.iso"
		git="yes"
		md5file="rocket.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		;;
		
		7)
		distro="vaporos"
		base_url="http://trashcan-gaming.nl"
		release="alchemist"
		file="vaporos2.1.iso"
		git="no"
		md5file="vaporos2.1.iso.md5"
		shafile="none"
		;;
		
		8)
		distro="vaporos-mod"
		base_url="https://github.com/sharkwouter/vaporos-mod.git"
		release="alchemist"
		file="vaporos.iso"
		git="yes"
		md5file="vaporos.iso.md5"
		shafile="none"
		# set github default action
		pull="no"
		;;
		
		8)
		distro="vaporos-mod"
		base_url="https://github.com/sharkwouter/vaporos-mod.git"
		release="brewmaster"
		file="vaporos2.iso"
		git="yes"
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
 		check_download_integrity
 		
 	else
 		# Check for and download release
 		pre_reqs
 		download_release_main
		check_download_integrity
		image_drive
		
 	fi
 	
} 

#######################################
# Start script
#######################################

# MAIN
main
