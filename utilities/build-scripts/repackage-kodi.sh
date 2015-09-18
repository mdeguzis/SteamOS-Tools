# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	repackage-kodi.sh
# Script Ver:	0.2.9
# Description:	Overall goal of script is to automate rebuilding pkgs from
#		https://launchpad.net/~team-xbmc/+archive/ubuntu/
#
# Usage:	./repackage-kodi.sh
#
# Warning:	You MUST have the Debian repos added properly for
#		installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

install_prereqs()
{

	clear
	# set scriptdir
	scriptdir="$HOME/SteamOS-Tools"
	
	echo -e "==> Checking for Debian sources..."
	
	#############################################
	# Repo checks
	##############################################
	sources_check=$(sudo find /etc/apt -type f -name "jessie*.list")
	
	if [[ "$sources_check" == "" ]]; then
                echo -e "\n==INFO==\nSources do *NOT* appear to be added at first glance. Adding now..."
                sleep 2s
                "$scriptdir/add-debian-repos.sh"
        else
                echo -e "\n==INFO==\nJessie sources appear to be added."
                sleep 2s
        fi
	
	#############################################
	# Install readily available software
	##############################################
	
	echo -e "\n==> Installing main pre-requisites for building...\n"
	sleep 2s
	
	# Install needed packages from available repos (NON PPA ONLY HERE!)
	# We do not want to pull pre-reqs from our repo, they will be built
	# from apt-get source later below.
	
	sudo apt-get install autopoint bison build-essential ccache cmake curl \
	cvs default-jre fp-compiler gawk gdc gettext git-core gperf libasound2-dev \
	libass-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev \
	libbluetooth-dev libbluray-dev libbluray1 libboost-dev libboost-thread-dev \
	libbz2-dev libcap-dev libcdio-dev libcrystalhd-dev libcrystalhd3 \
	libcurl3 libcurl4-gnutls-dev libcwiid-dev libcwiid1 libdbus-1-dev libenca-dev \
	libflac-dev libfontconfig1-dev libfreetype6-dev libfribidi-dev libglew-dev \
	libiso9660-dev libjasper-dev libjpeg-dev libltdl-dev liblzo2-dev libmad0-dev \
	libmicrohttpd-dev libmodplug-dev libmp3lame-dev libmpeg2-4-dev libmpeg3-dev \
	libmysqlclient-dev libnfs-dev libogg-dev libpcre3-dev libplist-dev libpng12-dev \
	libpostproc-dev libpulse-dev libsamplerate0-dev libsdl1.2-dev libsdl-gfx1.2-dev \
	libsdl-image1.2-dev libsdl-mixer1.2-dev libshairport-dev libsmbclient-dev \
	libsqlite3-dev libssh-dev libssl-dev libswscale-dev libtiff5-dev libtinyxml-dev \
	libtool libudev-dev libusb-dev libva-dev libva-egl1 libva-tpi1 libvdpau-dev \
	libvorbisenc2 libxml2-dev libxmu-dev libxrandr-dev libxrender-dev libxslt1-dev \
	libxt-dev libyajl-dev mesa-utils nasm pmount python-dev python-imaging python-sqlite \
	swig unzip yasm zip zlib1g-dev pkg-kde-tools doxygen graphviz gsfonts-x11 \
	fpc libgif-dev libgif-dev librtmp-dev libsdl2-dev libtag1-dev libfuse-dev \
	libreadline-dev libncurses5-dev liblockdev1-dev autoconf automake libgcrypt11-dev \
	dh-autoreconf
	
}

set_vars()
{
	
	#############################################
	# Vars
	##############################################
	
	# build dir
	build_dir="/home/desktop/build-kodi-temp"
	
	# set source and prefences
	kodi_repo_src="deb-src http://ppa.launchpad.net/team-xbmc/ppa/ubuntu vivid main "
	#ubuntu_repo_src="deb-src http://archive.ubuntu.com/ubuntu trusty main restricted universe multiverse"

	# gpg keys
	kodi_gpg="91E7EE5E"
	#ubuntu_trusty1_gpg="437D05B5"
	#ubuntu_trusty1_gpg="C0B21F32"
	
	
	# set target
	target="kodi"
	#ubuntu_target="ubuntu-trusty"
	
	# set preferences file
	kodi_prefer_tmp="${target}"
	kodi_prefer="/etc/apt/preferences.d/${target}"
	
	#ubuntu_prefer_tmp="${ubuntu_target}"
	#ubuntu_prefer="/etc/apt/preferences.d/${ubuntu_target}"
}

main()
{
	
	# remove previous dirs if they exist
	if [[ -d "$build_dir" ]]; then
		sudo rm -rf "$build_dir"
	fi
	
	# create build dir and enter it
	mkdir -p "$build_dir"
	cd "$build_dir"
	
	#############################################
	# Source lists and pref files
	##############################################
	
	# prechecks
	echo -e "\n==> Attempting to add source list\n"
	sleep 2s
	
	# check for existance of kodi target, backup if it exists
	if [[ -f /etc/apt/sources.list.d/${target}.list ]]; then
		echo -e "\n==> Backing up ${target}.list to ${target}.list.bak"
		sudo mv "/etc/apt/sources.list.d/${target}.list" "/etc/apt/sources.list.d/${target}.list.bak"
	fi
	
	# check for existance of ubuntu target, backup if it exists
	#if [[ -f /etc/apt/sources.list.d/${ubuntu_target}.list ]]; then
	#	echo -e "\n==> Backing up ${ubuntu_target}.list to ${ubuntu_target}.list.bak"
	#	sudo mv "/etc/apt/sources.list.d/${ubuntu_target}.list" "/etc/apt/sources.list.d/${ubuntu_target}.list.bak"
	#fi
	
	# Check for existance of ${kodi_prefer} file
	if [[ -f ${kodi_prefer} ]]; then
		# backup preferences file
		echo -e "==> Backing up ${kodi_prefer} to ${kodi_prefer}.bak\n"
		sudo mv ${kodi_prefer} ${kodi_prefer}.bak
		sleep 1s
	fi
	
	# Check for existance of ${ubuntu_prefer} file
	#if [[ -f ${ubuntu_prefer} ]]; then
	#	# backup preferences file
	#	echo -e "==> Backing up ${ubuntu_prefer} to ${ubuntu_prefer}.bak\n"
	#	sudo mv ${ubuntu_prefer} ${ubuntu_prefer}.bak
	#	sleep 1s
	#fi

	# add source to sources.list.d/
	echo ${kodi_repo_src} > "${target}.list.tmp"
	sudo mv "${target}.list.tmp" "/etc/apt/sources.list.d/${target}.list"
	
	#echo ${ubuntu_repo_src} > "${ubuntu_target}.list.tmp"
	#sudo mv "${ubuntu_target}.list.tmp" "/etc/apt/sources.list.d/${ubuntu_target}.list"
	
	# add preference file so availabe SteamOS packages are used for deps
	# Example: libpostproc53 depends on libavutil-dev available in brewmaster

	cat <<-EOF > ${kodi_prefer_tmp}
	Package: *
	Pin: origin ""
	Pin-Priority:120
	EOF
	
	#cat <<-EOF > ${ubuntu_prefer_tmp}
	#Package: *
	#Pin: origin ""
	#Pin-Priority:120
	#EOF
	
	# move tmp var files into target locations
	sudo mv  ${kodi_prefer_tmp}  ${kodi_prefer}
	#sudo mv  ${ubuntu_prefer_tmp}  ${ubuntu_prefer}
	
	# update package lists
	sudo apt-get update
	
	##############################################
	# GPG checks
	##############################################
	
	echo -e "\n==> Adding GPG keys\n"
	sleep 2s
	$scriptdir/utilities/gpg_import.sh $kodi_gpg
	
	#############################################
	# Build packages
	##############################################
	
	# Get listing of PPA packages
  	pkg_list=$(awk '$1 == "Package:" { print $2 }' /var/lib/apt/lists/ppa.launchpad.net_team-xbmc*)
  
  	# remove packages we build outside of the loop down below - TODO
  	# cat file1.txt | sed -e "$line"'d' > file2.txt
  	
  	# There are a few pacakges that must be built and installed first, otherwise
  	# many of the builids will fail
  	
  	echo -e "\n==> Building and installing pacakges from PPA, required by other builds"
  	sleep 2s
  	
  	#####################################
	# Pre-req PPA builds - Ubuntu
	#####################################
  	# Search page: https://launchpad.net/ubuntu
  	
  	#####################################
	# Pre-req PPA builds - kodi/stable
	#####################################
  	
  	# libplatform1
  	echo -e "\n==Building platform==\n" && sleep 2s
  	apt-get source --build platform
  	echo -e "\n==Installing libplatform==\n" && sleep 2s
  	sudo dpkg -i libplatform*.deb
  	
  	# libshairplay
  	echo -e "\n==Building shairplay==\n" && sleep 2s
  	apt-get source --build shairplay
  	echo -e "\n==Installing libshairplay==\n" && sleep 2s
  	sudo dpkg -i libshairplay*.deb
  	
  	# libafpclient-dev
  	echo -e "\n==Building afpfs-ng==\n" && sleep 2s
  	apt-get source --build afpfs-ng
  	echo -e "\n==Installing libafpclient==\n" && sleep 2s
  	sudo dpkg -i libafpclient*.deb
  	
  	# libcec
  	# NOTICE - 20150918 - DID build earlier today, but even on a 
  	# fresh install, this is no longer the case. Backup debs were installed
  	
  	#echo -e "\n==Building libcec==\n" && sleep 2s
  	#apt-get source --build libcec
  	#echo -e "\n==Installing libcec==\n" && sleep 2s
  	#sudo dpkg -i libcec*.deb
  	
  	#####################################
	# Main builds
	#####################################
  
  	# remove the items we built ahead of time
	awk '$1 == "Package:" { print $2 }' \
	/var/lib/apt/lists/ppa.launchpad.net_team-xbmc_ppa_ubuntu_dists_vivid_main_source_Sources \
	> temp.txt && sed -i -e '/platform/d' -i -e '/shairplay/d' -i -e '/afpfs-ng/d'  temp.txt 
	
	# set new pkg list and cleanup
	pkg_list=$(cat temp.txt)
	rm temp.txt
  
  	echo -e "\n==> Continuing on to main builds\n"
  	sleep 2s
  
	# Rebuild all items in pkg_list
	for pkg in ${pkg_list}; 
	do
	
		# Attempt to build targets
		
		echo -e "\n==> Attempting to build ${pkg}:\n"
		sleep 2s
		
		build=$(apt-get source --build ${pkg} | grep "E: Child process failed")
		
		# bow out if build contains unment build deps
		if [[ "$build" != "" ]]; then
			echo -e "FAILURE TO BUILD"		
			exit 1
		fi
		
		# since this is building a large amount of packages, remove
		# directories and unecessary files as we go.
		
		# cut files so we just have our deb pkg
		rm -f $build_dir/*.tar.gz
		rm -f $build_dir/*.dsc
		rm -f $build_dir/*.changes
		rm -f $build_dir/*-dbg
		rm -f $build_dir/*-dev
		rm -f $build_dir/*-compat
		
		# remove source directory that was made
		find $build_dir -mindepth 1 -maxdepth 1 -type d -exec rm -r {} \;
		
		# test only
		#echo ${pkg}
		#sleep 1s

	done
	
	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)
	
	# back out of build temp to script dir if called from git clone
	if [[ "$scriptdir" != "" ]]; then
		cd "$scriptdir"
	else
		cd "$HOME"
	fi

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# cut files
		scp $build_dir/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming
		echo -e "\n"
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Transfer not requested\n"
	fi
	
	echo -e "\n==> Would you like to purge this source list addition? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " purge_choice
	
	if [[ "$purge_choice" == "y" ]]; then
	
		# remove list
		echo -e "\n"
		sudo rm -f /etc/apt/sources.list.d/${target}.list
		sudo apt-get update
		
	elif [[ "$purge_choice" == "n" ]]; then
	
		echo -e "\n==INFO==\nPurge not requested\n"
	fi
	
	echo -e "\n==> Remove local built packages? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " remove_choice
	
	if [[ "$remove_choice" == "y" ]]; then
	
		# remove list
		rm -rf "$build_dir"
		
	elif [[ "$remove_choice" == "n" ]]; then
	
		echo -e "\n==INFO==\nRemoval not requested\n"
	fi
	
}

#prereqs
install_prereqs

# set vars
set_vars

# start main
main
