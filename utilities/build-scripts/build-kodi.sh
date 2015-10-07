#!/bin/bash
# -------------------------------------------------------------------------------
# Author:    		Michael DeGuzis
# Git:			https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	build-kodi.sh
# Script Ver:		0.9.5
# Description:		Attempts to build a deb package from kodi-src
#               	https://github.com/xbmc/xbmc/blob/master/docs/README.linux
#               	This is a fork of the build-deb-from-src.sh script. Due to the 
#               	amount of steps to build kodi, it was decided to have it's own 
#               	script. A deb package is built from this script. 
#
# Usage:      		./build-kodi.sh --cores [cpu cores]
#			./build-kodi.sh --package-deb
# See Also:		https://packages.debian.org/sid/kodi
# -------------------------------------------------------------------------------

time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)

# remove old log
rm -f "kodi-build-log.txt"

# Specify a final arg for any extra options to build in later
# The command being echo'd will contain the last arg used.
# See: http://www.cyberciti.biz/faq/linux-unix-bsd-apple-osx-bash-get-last-argument/
export extra_opts=$(echo "${@: -1}")

###################################
# global vars
###################################

# source args
$build_opts "$1"
cores_num="$2"

# defaults for packaging attempts
# use "latest release" tagged release
package_deb="no"
skip_to_build="no"
kodi_release="Isengard"
kodi_tag="15.1-Isengard"

# Set target
repo_target="xbmc"

# Set buld dir based on repo target to avoid recloning for different targets
if [[ "$repo_target" != "xbmc" ]]; then

	# set build dir to alternate
	build_dir="$HOME/kodi/kodi-${repo_target}"
else
	# set build dir to default
	build_dir="$HOME/kodi/kodi-source"

fi

# Set Git URL
git_url="git://github.com/${repo_target}/xbmc.git"
#git_url="git://github.com/xbmc/xbmc.git"

###################
# global vars
###################

# Allow more concurrent threads to be specified
if [[ "$build_opts" == "--cores" ]]; then

	# set cores
	cores="$core_num"
	
else

	# default to 2 cores as fallback
	cores="2"
fi
	

# assess extra opts from dekstop-software.sh
if [[ "$extra_opts" == "--package-deb" || "$arg1" == "--package-deb" ]]; then

	# set package to yes if deb generation is requested
	package_deb="yes"
	
elif [[ "$extra_opts" == "--skip-build" || "$arg1" == "--skip-build" ]]; then

	# If Kodi is confirmed by user to be built already, allow build
	# to be skipped and packaging to be attempted directly
	skip_build="yes"
	package_deb="yes"
	
fi

##################################
# Informational
##################################

# Source build notes:
# https://github.com/xbmc/xbmc/blob/master/docs/README.linux

# Current version:
# https://github.com/xbmc/xbmc/blob/master/version.txt

# model control file after:
# https://packages.debian.org/sid/kodi

# Current checkinstall config:
# cfgs/source-builds/kodi-checkinstall.txt

function_install_pkgs()
{
	
	# cycle through packages defined
	
	for dep in ${deps}; do
	
		pkg_chk=$(dpkg-query -s ${dep})
		
		if [[ "$pkg_chk" == "" ]]; then
		
			echo -e "\n==INFO==\nInstalling package: ${dep}\n"
			sleep 1s
			
			if apt-get install ${dep} -y --force-yes; then
			
				echo -e "\n${dep} installed successfully\n"
				sleep 1s
			
		else
				echo -e "Cannot install ${dep}. Exiting in 15s. \n"
				sleep 15s
				exit 1
			fi
			
		fi
	
	done
	
}

kodi_prereqs()
{
	clear
	
	cat <<-EOF
	-----------------------------------------------------------
	Kodi-src build script
	-----------------------------------------------------------
	EOF
	
	# Main build dependencies are installed via desktop-software.sh
	# from the software list cfgs/software-lists/kodi-src.txt
	
	echo -e "==> Installing main deps for building\n"
	
	deps="autoconf automake autopoint autotools-dev bc ccache cmake curl dcadec1 dcadec-dev \
	doxygen default-jre gawk gperf g++ libao-dev libasound2-dev libass-dev libavahi-client-dev \
	libavahi-common-dev libbluetooth-dev libbluray-dev libbluray1 libboost-dev libboost-thread-dev \
	libbz2-dev libcap-dev libcdio-dev libcec-dev libcrossguid1 libcrossguid-dev libcurl3 libcurl4-gnutls-dev \
	libcwiid-dev libdbus-1-dev libfontconfig1-dev libfreetype6-dev libfribidi-dev libgif-dev libglew-dev \
	libglu1-mesa-dev libiso9660-dev libgnutls28-dev libjasper-dev libjpeg-dev libltdl-dev liblzo2-dev \
	libmicrohttpd-dev libmodplug-dev libmpcdec-dev libmpeg2-4-dev libmysqlclient-dev libnfs-dev libogg-dev \
	libpcre3-dev libplist-dev libpng12-dev libpulse-dev librtmp-dev libsdl1.2-dev libsdl2-dev libshairport-dev \
	libsmbclient-dev libsqlite3-dev libssh-dev libssl-dev libswscale-dev libtag1-dev libtiff5-dev libtinyxml-dev \
	libtool libudev-dev libusb-dev libva-dev libvdpau-dev libvorbis-dev libxinerama-dev libxml2-dev libxmu-dev \
	libxrandr-dev libxslt1-dev libxt-dev libyajl-dev lsb-release nasm python-dev python-imaging python-support \
	swig unzip uuid-dev yasm zip zlib1g-dev"
	
	# install dependencies / packages
	function_install_pkgs

	# required for building kodi debs
	if [[ "$package_deb" == "yes" ]]; then
	
		#####################################
		# Dependencies - Debian sourced
		#####################################
	
		echo -e "==> Installing build deps for packaging\n"
		sleep 2s
	
		deps="build-essential fakeroot devscripts checkinstall \
		cowbuilder pbuilder debootstrap cvs fpc gdc libflac-dev libsamplerate0-dev libgnutls28-dev"
		
		# install dependencies / packages
		function_install_pkgs
	
		echo -e "\n==> Installing build deps sourced from ppa:team-xbmc/xbmc-ppa-build-depends\n"
		sleep 2s

		#####################################
		# Dependencies - ppa:xbmc sourced
		#####################################

		# Info: packages are rebuilt on SteamOS brewmaster, and hosted at 
		# packages.libregeek.org
		
		# Origin: ppa:team-xbmc/ppa 
		deps="libcec3 libcec-dev libafpclient-dev libgif-dev libmp3lame-dev libgif-dev libplatform-dev"
		
		# install dependencies / packages
		function_install_pkgs
		
		# Origin: ppa:team-xbmc/xbmc-nightly
		# It seems shairplay, libshairplay* are too old in the stable ppa
		deps="libshairport-dev libshairplay-dev shairplay"
		
		# install dependencies / packages
		function_install_pkgs

	fi
}

kodi_package_deb()
{
	
	# Debian link: 	    https://wiki.debian.org/BuildingTutorial
	# Ubuntu link: 	    https://wiki.ubuntu.com/PbuilderHowto
	# XBMC/Kodi readme: https://github.com/xbmc/xbmc/blob/master/tools/Linux/packaging/README.debian
	
	# Maybe use sudo "bash -c 'cat "TEXT" >> "/etc/sudoers'""
	# These next 3 lines will need added to /etc/sudoers, if not added already
	
	# Defaults env_reset,env_keep="DIST ARCH CONCURRENCY_LEVEL"
	# Cmnd_Alias PBUILDER = /usr/sbin/pbuilder, /usr/bin/pdebuild, /usr/bin/debuild-pbuilder
	# Desktop ALL=(ALL) PBUILDER
	
	# copy pbuilder template
	# If called standalone change copy paths
	
	############################################################
	# Assess if we are to build for host/ARCH we have or target
	############################################################
	
	# Ensure we are in the proper directory
	cd "$build_dir"
	
	echo -e "Which Kodi release do you wish to build for:"
	
	# show tags instead of branches
	git tag -l --column
	echo ""
	
	# get user choice
	sleep 0.2s
	read -erp "Choice: " kodi_tag
	
	# checkout proper release
	git checkout "tags/${kodi_tag}"
	
	# Testing...use our fork with a different changelog setup
	
	# change address in xbmc/tools/Linux/packaging/mk-debian-package.sh 
	# See: http://unix.stackexchange.com/a/16274
	sed -i "s|\bxbmc/xbmc-packaging/archive/master.tar.gz\b|ProfessorKaos64/xbmc-packaging/archive/${kodi_tag}.tar.gz|g" "tools/Linux/packaging/mk-debian-package.sh"
	
	echo -e "\nBuild Kodi for our host/ARCH or for target? [host|target]"
	
	# get user choice
	sleep 0.2s
	read -erp "Choice: " build_choice

	if [[ "$build_choice" == "host" ]]; then
	
		# build for host type / ARCH ONLY
		tools/Linux/packaging/mk-debian-package.sh
		
	elif [[ "$build_choice" == "target" ]]; then
		
		# ask for DIST target
		echo -e "\nEnter DIST to build for (see utilities/pbuilder-helper.txt)"
		
		# get user choice
		sleep 0.2s
		read -erp "Choice: " dist_choice
		
		# add desktop file for SteamOS/BPM
		touch "$HOME/.pbuilderrc"
		sudo touch "/root/.pbuilderrc"
		cp ../testing/pbuilder-helper.txt "$HOME/.pbuilderrc"
		sudo cp "../utilities/pbuilder-helper.txt" "/root/.pbuilderrc"

		# setup dist base
		if sudo DIST=brewmaster pbuilder create; then
		
			echo -e "\nBrewmaster environment created successfully!"
			
		else 
		
			echo -e "\nBrewmaster environment creation FAILED! Exiting in 10 seconds"
			sleep 10s
			exit 1
		fi
	
	
		# Clean xbmc pbuilder dir
		rm -rf "/home/$USER/xbmc-packaging/pbuilder"
		mkdir -p "/home/$USER/xbmc-packaging/pbuilder"
		
		# create directory for dependencies
		mkdir -p "/home/$USER/xbmc-packaging/deps"
		
		RELEASEV=16 \
		DISTS="$dist_choice" \
		ARCHS="amd64" \
		BUILDER="pdebuild" \
		PDEBUILD_OPTS="--debbuildopts \"-j4\"" \
		PBUILDER_BASE="/home/$USER/xbmc-packaging/pbuilder" \
		DPUT_TARGET="local" \
		tools/Linux/packaging/mk-debian-package.sh

	# end building
	fi

}

kodi_clone()
{
	
	echo -e "\n==> Cloning the Kodi repository:"
	echo -e "    $git_url"

	# If git folder exists, evaluate it
	# Avoiding a large download again is much desired.
	# If the DIR is already there, the fetch info should be intact
	
	if [[ -d "$build_dir" ]]; then

		echo -e "\n==Info==\nGit folder already exists! Reclone [r] or pull [p]?\n"
		sleep 1s
		read -ep "Choice: " git_choice

		if [[ "$git_choice" == "p" ]]; then
			# attempt to pull the latest source first
			echo -e "\n==> Attempting git pull..."
			sleep 2s

			# attempt git pull, if it doesn't complete reclone
			if ! git pull; then
				
				# command failure
				echo -e "\n==Info==\nGit directory pull failed. Removing and cloning...\n"
				sleep 2s
				rm -rf "$build_dir"
				# create and clone to $HOME/kodi
				cd
				git clone ${git_url} ${build_dir}
				
				
			fi

		elif [[ "$git_choice" == "r" ]]; then
			echo -e "\n==> Removing and cloning repository again...\n"
			sleep 2s
			sudo rm -rf "$build_dir"
			# create and clone to $HOME/kodi
			cd
			git clone ${git_url} ${build_dir}

		else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# create and clone to $HOME/kodi
			cd
			git clone ${git_url} ${build_dir}

		fi

	else

			echo -e "\n==> Git directory does not exist. cloning now...\n"
			sleep 2s
			# create DIRS
			cd
			# create and clone to current dir
			git clone ${git_url} ${build_dir}

	fi

}

kodi_build()
{
	#################################################
	# Build Kodi
	#################################################

	# Skip to debian packaging, if requested
	if [[ "$skip_build" == "yes" || "$package_deb" == "yes" ]]; then
	
		# fire off deb packaging attempt
		echo -e "\n==> Attempting to package existing files in ${build_dir}\n"
		sleep 2s
		
		# attempt deb package
		kodi_package_deb
		
		echo -e "\nPlease review above output. Exiting script in 15 seconds."
		exit 1
		
	fi

	echo -e "\n==> Building Kodi in $build_dir\n"

	# enter build dir
	cd "$build_dir"
	
	# checkout target release
	git checkout "tags/${kodi_tag}"

  	# create the Kodi executable manually perform these steps:
	if ./bootstrap; then
	
		echo -e "\nBootstrap successful\n"
		
	else
	
		echo -e "\nBoostrap failed. Exiting in 10 seconds."
		sleep 10s
		exit 1
		
	fi

	# ./configure <option1> <option2> PREFIX=<system prefix>... 
	# (See --help for available options). For now, use the default PREFIX
        # A full listing of supported options can be viewed by typing './configure --help'.
	# Default install path is:
	
	# FOR PACKAGING DEB ONLY (TESTING)
	# It may seem that per "http://forum.kodi.tv/showthread.php?tid=80754", we need to
	# export package config. 
	
	# Configure with bluray support
	# Rmove --disable-airplay --disable-airtunes, not working right now
	
	if ./configure --prefix=/usr --enable-libbluray --enable-airport; then
	
		echo -e "\nConfigured successfuly\n"
		
	else
	
		echo -e "\nConfigure failed. Exiting in 10 seconds."
		sleep 10s
		exit 1
		
	fi

	# make the package
	# By adding -j<number> to the make command, you describe how many
     	# concurrent jobs will be used. So for quad-core the command is:

	# make -j4
	
	# Default core number is 2 if '--cores $n' argument is not specified
	if make -j${cores}; then
	
		echo -e "\nKodi built successfuly\n"
		
	else
	
		echo -e "\nBuild failed. Exiting in 10 seconds."
		sleep 10s
		exit 1
		
	fi

	# install source build
	sudo make install

	# From v14 with commit 4090a5f a new API for binary addons is available. 
	# Not used for now ...

	# make -C tools/depends/target/binary-addons

	####################################
	# (Optional) build Kodi test suite
	####################################

	#make check

	# compile the test suite without running it

	#make testsuite

	# The test suite program can be run manually as well.
	# The name of the test suite program is 'kodi-test' and will build in the Kodi source tree.
	# To bring up the 'help' notes for the program, type the following:

	#./kodi-test --gtest_help

	#################################################
	# Post install configuration
	#################################################

}

show_summary()
{

	cat <<-EOF
	----------------------------------------------------------------
	Summary
	----------------------------------------------------------------
	Time started: ${time_stamp_start}
	Time started: ${time_stamp_end}
	Total Runtime (minutes): $runtime

	You should now be able to add Kodi as a non-Steam game in Big
	Picture Mode. Please see see the wiki for more information
	
	EOF
	sleep 2s
	
}

kodi_post_cfgs()
{
	
	echo -e "\n==> Adding desktop file and artwork"

		
	# copy files based of pwd
	sudo cp ""../../cfgs/desktop-files/kodi.desktop" "/usr/share/applications"
	sudo cp ""../../artwork/banners/Kodi.png" "/home/steam/Pictures"

	#################################################
	# Cleanup
	#################################################

	# clean up dirs

	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# check if Kodi really installed
	if [[ -f "/usr/local/bin/kodi" ]]; then
	
		echo -e "\n==INFO==\nKodi was installed successfully."
		
	else 
	
		echo -e "\n==INFO==\nKodi install unsucessfull\n"
	
	fi
	
	
}



####################################################
# Script sequence
####################################################
# Main order of operations
main()
{
	kodi_prereqs
	kodi_clone
	kodi_build
	kodi_post_cfgs
	
}

#####################################################
# MAIN
#####################################################
main | tee log_temp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_temp.txt > kodi-build-log.txt &> /dev/null

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' kodi-build-log.txt

# remove file not needed anymore
rm -f "log_temp.txt"
