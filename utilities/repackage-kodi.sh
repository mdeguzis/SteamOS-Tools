# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	repackage-kodi.sh
# Script Ver:	0.1.3
# Description:	Overall goal of script is to automate rebuilding pkgs from
#		https://launchpad.net/~team-xbmc/+archive/ubuntu/ppa?field.series_filter=trusty
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
	
	# check for repos
	sources_check=$(sudo find /etc/apt -type f -name "jessie*.list")
	
	if [[ "$sources_check" == "" ]]; then
                echo -e "\n==INFO==\nSources do *NOT* appear to be added at first glance. Adding now..."
                sleep 2s
                "$scriptdir/add-debian-repos.sh"
        else
                echo -e "\n==INFO==\nJessie sources appear to be added."
                sleep 2s
        fi
	
	echo -e "\n==> Installing pre-requisites for building...\n"
	
	sleep 1s
	# install needed packages
	sudo apt-get install autopoint bison build-essential ccache cmake curl \
	cvs default-jre fp-compiler gawk gdc gettext git-core gperf libasound2-dev \
	libass-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev \
	libbluetooth-dev libbluray-dev libbluray1 libboost-dev libboost-thread-dev \
	libbz2-dev libcap-dev libcdio-dev libcec-dev libcec1 libcrystalhd-dev libcrystalhd3 \
	libcurl3 libcurl4-gnutls-dev libcwiid-dev libcwiid1 libdbus-1-dev libenca-dev \
	libflac-dev libfontconfig-dev libfreetype6-dev libfribidi-dev libglew-dev \
	libiso9660-dev libjasper-dev libjpeg-dev libltdl-dev liblzo2-dev libmad0-dev \
	libmicrohttpd-dev libmodplug-dev libmp3lame-dev libmpeg2-4-dev libmpeg3-dev \
	libmysqlclient-dev libnfs-dev libogg-dev libpcre3-dev libplist-dev libpng-dev \
	libpostproc-dev libpulse-dev libsamplerate-dev libsdl-dev libsdl-gfx1.2-dev \
	libsdl-image1.2-dev libsdl-mixer1.2-dev libshairport-dev libsmbclient-dev \
	libsqlite3-dev libssh-dev libssl-dev libswscale-dev libtiff-dev libtinyxml-dev \
	libtool libudev-dev libusb-dev libva-dev libva-egl1 libva-tpi1 libvdpau-dev \
	libvorbisenc2 libxml2-dev libxmu-dev libxrandr-dev libxrender-dev libxslt1-dev \
	libxt-dev libyajl-dev mesa-utils nasm pmount python-dev python-imaging python-sqlite \
	swig unzip yasm zip zlib1g-dev
	
	echo -e "\n== Checking for extra standalone prequisite packages for batch building\n"
	
	# libplatform is needed to do batch rebuild of the PPA
	PKG="libplatform1"
	PKG_OK_DPKG=$(dpkg-query -W --showformat='${Status}\n' $PKG | grep "install ok installed")
	if [[ "$PKG_OK_DPKG" == "" ]]; then
	
		# bail out
		echo -e "\n==ERROR==\nlibplatform must be installed for batch rebuild of PPA!"
		echo -e "Please install this seperately"
		
	else 
	
		echo "Checking for $PKG [OK]"
		sleep 0.5s

	fi
}

set_vars()
{
	
	# build dir
	build_dir="/home/desktop/build-kodi-temp"
	
	# set source
	repo_src="deb-src http://ppa.launchpad.net/team-xbmc/ppa/ubuntu trusty main "

	# GPG key
	gpg_pub_key="91E7EE5E ("
	
	# set target
	target="kodi"
	
	
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
	
	# prechecks
	echo -e "\n==> Attempting to add source list"
	sleep 2s
	
	# check for existance of target, backup if it exists
	if [[ -f /etc/apt/sources.list.d/${target}.list ]]; then
		echo -e "\n==> Backing up ${target}.list to ${target}.list.bak"
		sudo mv "/etc/apt/sources.list.d/${target}.list" "/etc/apt/sources.list.d/${target}.list.bak"
	fi
	
	# add source to sources.list.d/
	echo ${repo_src} > "${target}.list.tmp"
	sudo mv "${target}.list.tmp" "/etc/apt/sources.list.d/${target}.list"
	
	echo -e "\n==> Adding GPG key\n"
	sleep 2s
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $gpg_pub_key
	#"$scriptdir/utilities.sh ${gpg_pub_key}"
	
	echo -e "\n==> Updating system package listings...\n"
	sleep 2s
	sudo apt-key update
	sudo apt-get update
	
	# Get listing of PPA packages
  	pkg_list=$(awk '$1 == "Package:" { print $2 }' /var/lib/apt/lists/ppa.launchpad.net_team-xbmc*)
  
	# Rebuild all items in pkg_list
	for pkg in ${pkg_list}; 
	do
	
		# Attempt to build target
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

	echo -e "\n==> Would you like to upload the packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -ep "Choice: " upload_choice
	
	if [[ "$upload_choice" == "y" ]]; then
	
		# set vars for upload
		sourcedir="$build_dir"
		user="thelinu2"
		host='libregeek.org'
		destdir="/home2/thelinu2/public_html/SteamOS-Extra/build-tmp/"
		
		echo -e "\n"
		
		# perform upload
		scp -r $sourcedir $user@$host:$destdir
		
	elif [[ "$upload_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
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
