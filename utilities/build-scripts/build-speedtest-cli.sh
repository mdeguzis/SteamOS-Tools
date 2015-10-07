#!/bin/bash
# -------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	build-speedtest-cli.sh
# Script Ver:	0.1.1
# Description:	Attempts to build a deb package from speedtest-cli git source
#
# See:		https://launchpadlibrarian.net/219136562/speedtest-cli_2.19.3-1~vivid1.dsc
# Usage:	build-speedtest-cli.sh
# -------------------------------------------------------------------------------

arg1="$1"
scriptdir=$(pwd)
time_start=$(date +%s)
time_stamp_start=(`date +"%T"`)

# upstream URL
git_url="https://github.com/sivel/speedtest-cli"

# package vars
pkgname="speedtest-cli"
pkgver="20151006+git"
pkgrev="1"
dist_rel="brewmaster"
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"
maintainer="ProfessorKaos64"

# set build_dir
build_dir="$HOME/build-${pkgname}-temp"
git_dir="${build_dir}/${pkgname}"

install_prereqs()
{
	clear
	echo -e "==> Installing prerequisites for building...\n"
	sleep 2s
	# install basic build packages
	sudo apt-get install -y --force-yes build-essential pkg-config checkinstall bc python \
	python-setuptools debhelper python-all

}

main()
{
	
	# create build_dir
	if [[ -d "$build_dir" ]]; then
	
		sudo rm -rf "$build_dir"
		mkdir -p "$build_dir"
		
	else
		
		mkdir -p "$build_dir"
		
	fi
	
	# enter build dir
	cd "$build_dir" || exit

	# install prereqs for build
	install_prereqs
	
	# Clone upstream source code
	
	echo -e "\n==> Obtaining upstream source code\n"
	
	git clone "$git_url" "$git_dir"
 
	#################################################
	# Build speedtest-cli
	#################################################
	
	echo -e "\n==> Creating original tarball\n"
	sleep 2s

	
	# create the tarball from latest tarball creation script
	# use latest revision designated at the top of this script
	
	# create source tarball
	tar -cvzf "${pkgname}_${pkgver}-${pkgrev}.orig.tar.gz" "${pkgname}"
	
	# emter source dir
	cd "${pkgname}"
  	
	# copy in debian folder/files
	mkdir debian
	cp -r "$scriptdir/$pkgname/debian" .
	
	# copy debian shell changelog from SteamOS-Tools
	cp "$scriptdir/$pkgname/debian/changelog" "debian/changelog"
	
	# Change version, uploader, insert change log comments
	sed -i "s|version_placeholder|$pkgver-$pkgrev" debian/changelog
	sed -i "s|uploader|$uploader|g" debian/changelog
	sed -i "s|dist_rel|$dist_rel|g" debian/changelog
	
	# open debian/changelog and update
	echo -e "\n==> Opening changelog for build. Please ensure there is a revision number"
	sleep 3s
	nano debian/changelog
 
	#################################################
	# Build Debian package
	#################################################

	echo -e "\n==> Building Debian package ${pkgname} from source\n"
	sleep 2s

	dpkg-buildpackage -rfakeroot -us -uc

	#################################################
	# Post install configuration
	#################################################
	
	#################################################
	# Cleanup
	#################################################
	
	# clean up dirs
	
	# note time ended
	time_end=$(date +%s)
	time_stamp_end=(`date +"%T"`)
	runtime=$(echo "scale=2; ($time_end-$time_start) / 60 " | bc)
	
	# output finish
	echo -e "\nTime started: ${time_stamp_start}"
	echo -e "Time started: ${time_stamp_end}"
	echo -e "Total Runtime (minutes): $runtime\n"

	
	# assign value to build folder for exit warning below
	build_folder=$(ls -l | grep "^d" | cut -d ' ' -f12)
	
	# back out of build temp to script dir if called from git clone
	if [[ "$scriptdir" != "" ]]; then
		cd "$scriptdir" || exit
	else
		cd "$HOME" || exit
	fi
	
	# inform user of packages
	echo -e "\n############################################################"
	echo -e "If package was built without errors you will see it below."
	echo -e "If you don't, please check build dependcy errors listed above."
	echo -e "############################################################\n"
	
	echo -e "Showing contents of: ${build_dir}/build: \n"
	ls ${git_dir}/build | grep -E *.deb

	echo -e "\n==> Would you like to transfer any packages that were built? [y/n]"
	sleep 0.5s
	# capture command
	read -erp "Choice: " transfer_choice
	
	if [[ "$transfer_choice" == "y" ]]; then
	
		# cut files
		if [[ -d "${git_dir}/build" ]]; then
			scp ${git_dir}/build/*.deb mikeyd@archboxmtd:/home/mikeyd/packaging/SteamOS-Tools/incoming

		fi
		
	elif [[ "$transfer_choice" == "n" ]]; then
		echo -e "Upload not requested\n"
	fi

}

# start main
main
