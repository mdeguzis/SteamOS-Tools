#!/bin/bash
# -----------------------------------------------------------------------
# Author: 	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	add-debian-repos.sh
# Script Ver:	0.7.2
# Description:	This script automatically enables Debian and/or Libregeek 
#		repositories
#
#		See: https://wiki.debian.org/AptPreferences#Pinning
#
# Usage:	./add-debian-repos [install|uninstall|--help]
# Extra args:	--enable-testing --debian-only
# ------------------------------------------------------------------------

#####################################################
# Set global variables
#####################################################

# remove old custom files
rm -f "log.txt"

# Specify a final arg for any extra options to build in later
# The command being echo'd will contain the last arg used.
# See: http://www.cyberciti.biz/faq/linux-unix-bsd-apple-osx-bash-get-last-argument/
export final_opts=$(echo "${@: -1}")

# set default actions if no args are specified
install="yes"
test_repo="no"
debian_only="no"

# get top level current dir
current_dir=$(basename "$PWD") 

#####################################################
# Source options
#####################################################

# check for and set install status
if [[ "$1" == "install" ]]; then
	install="yes"
elif [[ "$1" == "uninstall" ]]; then
    	install="no"
fi

# enable test repo if desired
if [[ "$final_opts" == "--debian-only" ]]; then
	
	debian_only="yes"
	
elif [[ "$final_opts" == "--enable-testing" ]]; then
	
	test_repo="yes"
	
elif [[ "$final_opts" != "--enable-testing" ]]; then
    	
    	test_repo="no"
    	# ensure testing repo is removed
    	sudo sed -ei '/Libregeek Debian testing repository/,+1d' "/etc/apt/sources.list.d/steamos-tools.list"
    	
fi

fucnt_check_gpg()
{
	if [[ "$current_dir" != "SteamOS-Tools" ]]; then
	
		#  Find where the user cloned SteamOS-Tools to
		echo -e "==INFO==\nadd-debian-repos.sh was run from a foreign directory!"
		echo -e "Assessing location of SteamoS-Tools, please wait...\n"
		scriptdir=$(find / -name "SteamOS-Tools" 2> /dev/null)
		
	elif [[ "$scriptdir" == "" ]]; then 
	
		# We are in SteamOS-Tools, but it is not called from desktop-software.sh
		# set scriptdir to pwd
		scriptdir="$PWD"
		
	fi

	echo -e "==> Importing GPG keys\n"
	sleep 1s

	# Key Desc: Libregeek Signing Key
	# Key ID: 34C589A7
	# Full Key ID: 8106E72834C589A7
	echo -ne "Adding Libregeek public signing key: " && \
	$scriptdir/utilities/gpg-import.sh 8106E72834C589A7 2> /dev/null
	
}

funct_create_dirs()
{
	
# set directories to add
steamos_tools_configs="$HOME/.config/SteamOS-Tools"
	
echo -e "\n==> Adding needed directories"
sleep 2s

dirs="${steamos_tools_configs}"

for dir in ${dirs};
do
	if [[ ! -d "${dir}" ]]; then
	
		mkdir -p "${dir}"
	
	fi
	
done
	
}

funct_set_vars()
{
	# Set default user options
	reponame="jessie"
	backports_reponame="jessie-backports"
	steamos_tools_reponame="steamos-tools"
	
	# tmp vars
	sourcelist_tmp="${reponame}.list"
	backports_sourcelist_tmp="${backports_reponame}.list"
	steamos_tools_sourcelist_tmp="${steamos_tools_reponame}.list"
	
	prefer_tmp="${reponame}"
	backports_prefer_tmp="${backports_reponame}"
	steamos_prefer_tmp="steamos"
	steamos_tools_prefer_tmp="${steamos_tools_reponame}"
	
	# target vars
	sourcelist="/etc/apt/sources.list.d/${reponame}.list"
	backports_sourcelist="/etc/apt/sources.list.d/${backports_reponame}.list"
	steamos_tools_sourcelist="/etc/apt/sources.list.d/${steamos_tools_reponame}.list"
	
	prefer="/etc/apt/preferences.d/${reponame}"
	backports_prefer="/etc/apt/preferences.d/${backports_reponame}"
	steamos_prefer="/etc/apt/preferences.d/steamos"
	steamos_tools_prefer="/etc/apt/preferences.d/${steamos_tools_reponame}"
}

funct_show_help()
{
	
	clear
	cat<<- EOF
	###########################################################
	Usage instructions
	###########################################################
	You can run this script as such:
	
	./add-debian-repos [install|uninstall|--help]
	
	Additional arguments:
	
	"--enable-testing" (Add libregeek testing repos)
	"--debian-only" (only add Debian sources)
	
	EOF
	
}

main()
{
	#####################################################
	# Install/Uninstall process
	#####################################################
	
	# Ensure multiarch is enabled (should be by default)
	if ! dpkg --print-foreign-architectures | grep i386 &> /dev/null; then
	
		# add multiarch
		dpkg --add-architecture i386
		
	fi
	
	if [[ "$install" == "yes" ]]; then
		
		# Check/add gpg key for libregeek
		fucnt_check_gpg
		
		if [[ "$debian_only" == "no" ]]; then
		
			echo -e "\n==> Adding Debian ${reponame}, ${backports_reponame}, and ${steamos_tools_reponame} sources\n"
			
		elif [[ "$debian_only" == "yes" ]]; then
		
			echo -e "\n==> Adding Debian ${reponame}, and ${backports_reponame} only"
			EOF
		
		fi
		
		if [[ "$test_repo" == "yes" ]]; then
		
			echo -ne "    [SteamOS-Tools testing enabled]\n\n"
			
		fi
		
		sleep 1s
		
		# Check for existance of /etc/apt/preferences file (deprecated, see below)
		if [[ -f "/etc/apt/preferences" ]]; then
			# backup preferences file
			echo -e "==> Backing up /etc/apt/preferences to /etc/apt/preferences.bak\n"
			sudo mv "/etc/apt/preferences" "/etc/apt/preferences.bak"
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{steamos_prefe} file
		if [[ -f ${steamos_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${steamos_prefer} to ${steamos_prefer}.bak\n"
			sudo mv ${steamos_prefer} ${steamos_prefer}.bak
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{prefer} file
		if [[ -f ${prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${prefer} to ${prefer}.bak\n"
			sudo mv ${prefer} ${prefer}.bak
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{backports_prefer} file
		if [[ -f ${backports_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${backports_prefer} to ${backports_prefer}.bak\n"
			sudo mv ${backports_prefer} ${backports_prefer}.bak
			sleep 1s
		fi
		
		# Check for existance of /etc/apt/preferences.d/{steamos_tools_prefer} file
		if [[ -f ${steamos_tools_prefer} ]]; then
			# backup preferences file
			echo -e "==> Backing up ${steamos_tools_prefer} to ${steamos_tools_prefer}.bak\n"
			sudo mv ${steamos_tools_prefer} ${steamos_tools_prefer}.bak
			sleep 1s
		fi
		
	
		# Create and add required text to preferences file
		# Verified policy with apt-cache policy
		cat <<-EOF > ${prefer_tmp}
		Package: *
		Pin: origin ""
		Pin-Priority:110
		
		Package: *
		Pin: release o=Debian 
		Pin-Priority:110
		EOF
		
		cat <<-EOF > ${backports_prefer_tmp}
		Package: *
		Pin: origin ""
		Pin-Priority:120
		
		Package: *
		Pin: release o=Debian 
		Pin-Priority:110
		EOF
	
		cat <<-EOF > ${steamos_prefer_tmp}
		Package: *
		Pin: release l=Steam
		Pin-Priority: 900
		
		Package: *
		Pin: release l=SteamOS
		Pin-Priority: 900
		EOF
		
		# modify pinning based on setup for testing or not
		if [[ "$test_repo" == "no" && "$debian_only" == "no" ]]; then
			
			cat <<-EOF > ${steamos_tools_prefer_tmp}
			Package: *
			Pin: release n=brewmaster
			Pin-Priority:150
			EOF
		
		elif [[ "$test_repo" == "yes" && "$debian_only" == "no" ]]; then
		
			cat <<-EOF > ${steamos_tools_prefer_tmp}
			Package: *
			Pin: release n=brewmaster
			Pin-Priority:150
			
			Package: *
			Pin: release n=brewmaster_testing
			Pin-Priority:200
			EOF
			
		fi
		
		# move tmp var files into target locations
		sudo mv  ${prefer_tmp}  ${prefer}
		sudo mv  ${backports_prefer_tmp}  ${backports_prefer}
		sudo mv  ${steamos_prefer_tmp}  ${steamos_prefer}
		
		# only move steamos tools if the file is actually going to be populated
		if [[  "$debian_only" == "no" ]]; then
		
			sudo mv  ${steamos_tools_prefer_tmp}  ${steamos_tools_prefer}
			
		fi
		
		#####################################################
		# Check for lists in repos.d
		#####################################################
		
		# If it does not exist, create it
		
		if [[ -f ${sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${sourcelist} to ${sourcelist}.bak\n"
	        	sudo mv ${sourcelist} ${sourcelist}.bak
	        	sleep 1s
		fi
		
		if [[ -f ${backports_sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${backports_sourcelist} to ${backports_sourcelist}.bak\n"
	        	sudo mv ${backports_sourcelist} ${backports_sourcelist}.bak
	        	sleep 1s
		fi
		
		if [[ -f ${steamos_tools_sourcelist} ]]; then
	        	# backup sources list file
	        	echo -e "==> Backing up ${steamos_tools_sourcelist} to ${steamos_tools_sourcelist}.bak\n"
	        	sudo mv ${steamos_tools_sourcelist} ${steamos_tools_sourcelist}.bak
	        	sleep 1s
		fi

		#####################################################
		# Create and add required text to jessie.list
		#####################################################

		# Debian jessie
		cat <<-EOF > ${sourcelist_tmp}
		# Debian-jessie repo
		deb http://httpredir.debian.org/debian/ jessie main contrib non-free
		deb-src http://httpredir.debian.org/debian/ jessie main contrib non-free
		EOF
		
		# Debian jessie-backports
		cat <<-EOF > ${backports_sourcelist_tmp}
		deb http://httpredir.debian.org/debian jessie-backports main
		EOF
		
		# packages.libregeek.org
		if [[ "$test_repo" == "no" && "$debian_only" == "no" ]]; then
		
			cat <<-EOF > ${steamos_tools_sourcelist_tmp}
			# Libregeek Debian repository
			deb http://packages.libregeek.org/SteamOS-Tools/ brewmaster main games
			deb-src http://packages.libregeek.org/SteamOS-Tools/ brewmaster main games
			EOF
			
		elif [[ "$test_repo" == "yes" && "$debian_only" == "no" ]];then
		
			cat <<-EOF > ${steamos_tools_sourcelist_tmp}
			# Libregeek Debian repository
			deb http://packages.libregeek.org/SteamOS-Tools/ brewmaster main games
			deb-src http://packages.libregeek.org/SteamOS-Tools/ brewmaster main games
			
			# Libregeek Debian testing repository
			deb http://packages.libregeek.org/SteamOS-Tools/ brewmaster_testing main games
			EOF
			
		fi

		# move tmp var files into target locations
		sudo mv  ${sourcelist_tmp} ${sourcelist}
		sudo mv  ${backports_sourcelist_tmp} ${backports_sourcelist}
		
		# Only move file if populated above
		if [[ "$debian_only" == "no" ]]; then
		
			sudo mv  ${steamos_tools_sourcelist_tmp} ${steamos_tools_sourcelist}
			
		fi
		
		# Add unattended upgrade file to update libregeek packages along side Valve's
		sudo cp "$scriptdir/cfgs/apt/apt.conf.d/60unattended-steamos-tools" "/etc/apt/apt.conf.d/"
		
		# Remove old file (keep this for some time) that was named out of conventional standards
		sudo rm -f "/etc/apt/apt.conf.d/60-unattended-steamos-tools"
		
		# Update system
		echo -e "\n==> Updating index of packages...\n"
		sleep 2s
		sudo apt-get update

		#####################################################
		# Remind user how to install
		#####################################################
		
		cat <<-EOF
		
		#################################################################
		How to use
		#################################################################
		You can now not only install package from the SteamOS repository,
		but also from the Debian and Libregeek repositories with either:
		
		'sudo apt-get install <package_name>'
		'sudo apt-get -t [release] install <package_name>'
		
		Warning: If the apt package manager seems to want to remove a lot
		of packages you have already installed, be very careful about proceeding.
		
		EOF
	
	elif [[ "$install" == "no" ]]; then

		echo -e "==> Removing debian repositories...\n"
		sleep 2s
		
		# sourcelists (original)
		sudo rm -f ${sourcelist}
		sudo rm -f ${backports_sourcelist}
		sudo rm -f ${multimedia_sourcelist}
		sudo rm -f ${steamos_tools_sourcelist}
		
		# preference files (original)
		sudo rm -f ${prefer}
		sudo rm -f ${steamosprefer}
		sudo rm -f ${mulitmedia_prefer}
		sudo rm -f ${steamos_tools_prefer}
		
		# sourcelist backups
		sudo rm -f ${sourcelist}.bak
		sudo rm -f ${backports_sourcelist}.bak
		sudo rm -f ${multimedia_sourcelist}.bak
		sudo rm -f ${steamos_tools_sourcelist}.bak
		
		# prefer backups
		sudo rm -f ${prefer}.bak
		sudo rm -f ${steamosprefer}.bak
		sudo rm -f ${mulitmedia_prefer}.bak
		sudo rm -f ${steamos_tools_prefer}.bak
		
		# apt configs
		sudo rm -f "/etc/apt/apt.conf.d/60unattended-steamos-tools"
		
		# Remove improper file committed, remove after some time
		sudo rm -f "/etc/apt/apt.conf.d/60-unattended-steamos-tools"
		
		sleep 2s
		sudo apt-get update
		echo "Done!"
	fi
}

#Show help if requested
if [[ "$1" == "--help" ]]; then
        funct_show_help
	exit 0
fi
#####################################################
# handle prerequisites
#####################################################
clear
funct_create_dirs
funct_set_vars

#####################################################
# MAIN
#####################################################
main | tee log_temp.txt

#####################################################
# cleanup
#####################################################

# convert log file to Unix compatible ASCII
strings log_temp.txt > log.txt

# strings does catch all characters that I could 
# work with, final cleanup
sed -i 's|\[J||g' log.txt

# remove file not needed anymore
rm -f "log_temp.txt"
