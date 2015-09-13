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
	sudo apt-get install git devscripts build-essential checkinstall \
	debian-keyring debian-archive-keyring cmake libv4l-dev autotools-dev \
	dh-autoreconf pkg-kde-tools doxygen graphviz gsfonts-x11
	
	echo -e "\n== Checking for extra standalone prequisite packages for batch building"
	
	# libplatform is needed to do batch rebuild of the PPA
	pkg_check=$(dpkg -s libplatform1)
	if [[ "$pkg_check" == "" ]]; then
	
		# bail out
		echo -e "\n==ERROR==\nlibplatform must be installed for batch rebuild of PPA!"
		echo -e "Please install this seperately"

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
	
	echo -e "\n==> Adding GPG key:\n"
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
		
		build=$(apt-get source --build ${pkg} | grep "Unmet build dependencies")
		
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
