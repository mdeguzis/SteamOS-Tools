#!/bin/bash
#-------------------------------------------------------------------------------
# Author:	Michael DeGuzis
# Git:		https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt name:	steamos-systeminfo-tool.
# Script Ver:	0.7.7
# Description:	Tool to collect some information for troubleshooting issues
#
# Usage:	./steamos-systeminfo-tool.
# Opts:		[--testing]
#		Modifys build script to denote this is a test package build.
# -------------------------------------------------------------------------------

function_install_utilities()
{

	echo -e "==> Installing needed software...\n"

	PKGS="p7zip-full bc"

	for PKG in ${PKGS};
	do

		# This one-liner returns 1 (installed) or 0 (not installed) for the package
		if ! dpkg-query -W --showformat='${Status}\n' ${PKG} | grep "ok installed"; then

			sudo apt-get install -y ${PKG}
		else

			echo -e "Package: ${PKG} [OK]\n"

		fi

	done

}

function_set_vars()
{

	TOP=${PWD}

	DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
	DATE_SHORT=$(date +%Y%m%d)

	LOG_ROOT="${HOME}/logs"
	LOG_FOLDER="${LOG_ROOT}/steamos-logs"
	LOG_FILE="${LOG_FOLDER}/steamos-systeminfo-stdout.txt"
	ZIP_FILE="${LOG_FOLDER}_${DATE_SHORT}.zip"

	# Remove old logs to old folder and clean folder

	cp -r ${LOG_FOLDER} ${LOG_FOLDER}.old &> /dev/null
	rm -rf ${LOG_FOLDER}/*

	# Remove old zip files to avoid clutter.
	# Max: 90 days
	find ${LOG_ROOT} -mtime +90 -type f -name "steamos-logs*.zip" -exec rm {} \;

	# Create log folder if it does not exist
	if [[ ! -d "${LOG_FOLDER}" ]]; then

		mkdir -p "${LOG_FOLDER}"

	fi

	#################
	# OS
	#################

	KERNEL_INFO_FULL=$(uname -a)
	KERNEL_INFO_RELEASE=$(uname -r)
	KERNEL_INFO_ARCH=$(uname -m)

	# Suppress "No LSB modules available message"
	OS_BASIC_INFO=$(lsb_release -a 2> /dev/null)
	# See when OS updates were last checked for
	OS_UPDATE_CHECKTIME=$(stat /var/lib/apt/periodic/upgrade-stamp | grep "Modify" | tail -n 1 | sed 's/Modify: //')
	# Beta stuff
	OS_BETA_CHECK=$(dpkg-query -W --showformat='${Status}\n' steamos-beta-repo | grep "ok installed")

	if [[ "${OS_BETA_CHECK}" != "" ]]; then

		OS_BETA_STATUS="Enabled"

	else

		OS_BETA_STATUS="Disabled"

	fi

	#################
	# Hardware
	#################

	# CPU
	CPU_VENDOR=$(lscpu | awk '/Vendor ID/{print $3}')
	CPU_ARCH=$(lscpu | awk '/Arch/{print $2}')
	CPU_MHZ=$(lscpu | awk '/MHz/{print $3}')
	CPU_GHZ=$(echo "scale=2; ${CPU_MHZ}/1000" | bc)
	CPU_CORES=$(lscpu | awk '/Core\(s\)/{print $4}')

	# Memory

	SYSTEM_MEM_KB=$(cat /proc/meminfo | awk '/MemTotal/{print $2}')
	SYSTEM_MEM_GB=$(echo "scale=2; ${SYSTEM_MEM_KB}/1024/1024" | bc)
	SYSTEM_SWAP_KB=$(cat /proc/meminfo | awk '/SwapTotal/{print $2}')
	SYSTEM_SWAP_GB=$(echo "scale=2; ${SYSTEM_SWAP_KB}/1024/1024" | bc)

	# DISK

	# just use lsblk in output
	CMD_LSBLK=$(lsblk)

	# Check vendor
	GPU_VENDOR_STRING=$(lspci -v | grep "VGA compatible controller" | grep -Ei 'nvidia|ati|amd|intel')
	# Set vendor
	if echo "${GPU_VENDOR_STRING}" | grep -iw "nvidia" 1> /dev/null; then GPU_VENDOR="Nvidia"; fi
	if echo "${GPU_VENDOR_STRING}" | grep -iw "ati" 1> /dev/null; then GPU_VENDOR="ATI"; fi
	if echo "${GPU_VENDOR_STRING}" | grep -iw "amd" 1> /dev/null; then GPU_VENDOR="AMD"; fi
	if echo "${GPU_VENDOR_STRING}" | grep -iw "intel" 1> /dev/null; then GPU_VENDOR="Intel"; fi

	GPU_MODEL_FULL=$(lspci -v | awk -F":" '/VGA compatible controller/{print $3}')
	GPU_MODEL="${GPU_MODEL_FULL}"
	GPU_DRIVER_STRING=$(cat /var/log/Xorg.0.log | awk -F'\\)' '/GLX Module/{print $2}')
	# Use full driver string from Xorg log for now until more testing can be done
	GPU_DRIVER_VERSION="${GPU_DRIVER_STRING}"

	#################
	# Software
	#################

	SOFTWARE_LIST=$(dpkg-query -W -f='${Package}\t${Architecture}\t${Status}\t${Version}\n' "valve-*" \
	"*steam*" "nvidia*" "fglrx*" "*mesa*" "*libregeek*")

	# Steam vars
	STEAM_CLIENT_VER=$(grep "version" /home/steam/.steam/steam/package/steam_client_ubuntu12.manifest \
	| awk '{print $2}' | sed 's/"//g')
	STEAM_CLIENT_BUILT=$(date -d @${STEAM_CLIENT_VER})
	STEAMOS_VER=$(dpkg-query -W -f='${VERSION}\n' steamos-updatelevel)

}

function_gather_info()
{

	# OS
	cat<<-EOF
	==============================================
	SteamOS System Info Tool
	==============================================

	==========================
	OS Information
	==========================

	Kernel release: ${KERNEL_INFO_RELEASE}
	Kernel arch: ${KERNEL_INFO_ARCH}

	${OS_BASIC_INFO}
	SteamOS Version: ${STEAMOS_VER}
	SteamOS OS Beta: ${OS_BETA_STATUS}
	OS Updates last checked on: ${OS_UPDATE_CHECKTIME}

	==========================
	Hardware Information
	==========================

	CPU Vendor: ${CPU_VENDOR}
	CPU Arch: ${CPU_ARCH}
	CPU Clock: ${CPU_GHZ} GHz
	CPU Cores: ${CPU_CORES}

	System Total Memory: ${SYSTEM_MEM_GB} GB
	System Total Swap: ${SYSTEM_SWAP_GB} GB

	GPU Vendor: ${GPU_VENDOR}
	GPU Model: ${GPU_MODEL}
	GPU Driver: ${GPU_DRIVER_VERSION}

	Disk information:

	${CMD_LSBLK}

	==========================
	Software Information
	==========================

	${SOFTWARE_LIST}

	==========================
	Steam Information
	==========================

	Steam client version: ${STEAM_CLIENT_VER}
	Steam client built: ${STEAM_CLIENT_BUILT}

	EOF
}

function_gather_logs()
{

	echo -e "\n==> Gathering logs (sudo required for system paths)\n"

	# Simply copy logs to temp log folder to be tarballed later
	pathlist=()
	pathlist+=("/tmp/dumps/steam_stdout.txt")
	pathlist+=("/home/steam/.steam/steam/package/steam_client_ubuntu12.manifest")
	pathlist+=("/var/log/unattended-upgrades/unattended-upgrades-dpkg.log")
	pathlist+=("/var/log/unattended-upgrades/unattended-upgrades-shutdown.log")
	pathlist+=("/var/log/unattended-upgrades/unattended-upgrades.log")
	pathlist+=("/var/log/unattended-upgrades/unattended-upgrades-shutdown-output.log")
	pathlist+=("/run/unattended-upgrades/ready.json")

	for file in "${pathlist[@]}"
	do
		# Suprress only when error/not found
		sudo cp -v ${file} ${LOG_FOLDER} 2>/dev/null
	done

	# Gather lspci -v for kicks
	lspci -v &> "${LOG_FOLDER}/lspci.txt"

	# Notable logs not included right now
	# /home/steam/.steam/steam/logs*

}

main()
{

	# Install software
	function_install_utilities

	# get info about system
	function_gather_info

	# Get logs
	function_gather_logs

	# Archive log filer with date
	echo -e "==> Archiving logs\n"
	7za a "${ZIP_FILE}" ${LOG_FOLDER}/*

}

# Main
clear
function_set_vars
echo -e "Running SteamOS system info tool..."
echo -e "Note: sudo is required to access and store system level logs"
main &> ${LOG_FILE}

# output summary

cat<<- EOF
Logs directory: ${LOG_FOLDER}
Standard log ouput stored at: ${LOG_FILE}
Log archive stored at: ${ZIP_FILE}

EOF
