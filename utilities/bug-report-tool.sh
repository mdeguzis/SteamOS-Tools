#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  bug-report-tool.sh
# Script Ver:	  0.1.1
# Description:	Captures important system information in a semi-readible format
#               to attach to a SteamOS bug report at github.com/ValveSoftware/SteamOS/issues
#
# Usage:	      ./bug-report-tool.sh
#               ./bug-report-tool.sh --test
# -------------------------------------------------------------------------------

# Set test flag if output is just to be reviewed
test_opt="$1"

#############################################
# pre-reqs
#############################################
sudo apt-get install git lib32gcc1

#############################################
# Steam CMD
#############################################

#############################################
# set vars
#############################################

OS_INFO=$(lsb_release -a)
OS_KERNEL=$(uname -r)

CPU=$(cat /proc/cpuinfo | grep -m 1 "model name" | cut -c 14-44)
CPU_MODEL_SPEED=$(cat /proc/cpuinfo | grep -m 1 "model name" | cut -c 45-80)
CPU_CORES=$(cat /proc/cpuinfo | grep -m 1 "cpu cores")

GPU=$(lspci -v | grep "VGA" | cut -c 36-92)
GPU_DRIVER=$(lspci -v | grep -A 9 "VGA" | grep "Kernel" | cut -c 24-30)

AUDIO=$(lspci -v | grep -A 6 "Audio")

PCI_FULL=$(lspci -v)
UNAME_FULL=$(uname -a)

# Steam-specific
# There is a bug in the current steamcmd version that outputs a 
# Danish "o" in "version"
steam_ver=$(/home/desktop/steamcmd/steamcmd.sh "+versi$(echo -e '\xc3\xb8')n" +quit | grep "package" | cut -c 25-35)
steam_api=$(/home/desktop/steamcmd/steamcmd.sh "+versi$(echo -e '\xc3\xb8')n" +quit | grep -E "^Steam API\:" | cut -c 12-15)

#############################################
# bug report generation
#############################################

# set bug report dir
bug_dir="/home/desktop/bug-reports"

# create temp bug report file
if [[ ! -d "$bug_dir" ]]; then
  # create DIR
  mkdir -p "$bug_dir"
fi

# get timestamp
timestamp=$(date +%Y%m%d-%H:%M:%S)

# Create bug report file
#bug_report_file="${bug_dir}/bug_report_${timestamp})"

if [[ ! -d "$HOME/gist-cli" ]]; then
  cd
  git clone https://github.com/pranavk/gist-cli
  cd ~/gist-cli
  chmod +x gistcli
fi

# enter git dir
cd "$HOME/gist-cli"

cat <<- EOF > bug.txt
-------------------------------------------------------
SteamOS Info:
-------------------------------------------------------
$OS_INFO
Kernel:         $OS_KERNEL

-------------------------------------------------------
CPU Info:
-------------------------------------------------------
Manufacturer:   : $CPU
Model:          : $CPU_MODEL_SPEED
$CPU_CORES

-------------------------------------------------------
GPU Info:
-------------------------------------------------------
GPU Model       : $GPU
Driver          : $GPU_DRIVER

-------------------------------------------------------
Audio Info:
-------------------------------------------------------
$AUDIO

-------------------------------------------------------
Full System and PCI Info:
-------------------------------------------------------
$OS_INFO

$UNAME_FULL

$PCI_FULL

EOF


clear
cat <<- EOF
-----------------------------------------------------------------
Summary
-----------------------------------------------------------------
Please paste the below URL into your SteamOS issues ticket at
https://github.com/ValveSoftware/SteamOS/issues

EOF

if [[ "$test_opt" == "--test" ]]; then

  # create gist
  less bug.txt
  
elif [[ "$test_opt" == "" ]]; then

  # create gist
  ./gistcli -f bug.txt
  
fi

#gist_url=$(curl -sX POST --data-binary '{"files": {"file1.txt": {"content": "lspci -v"}}}' \
#https://api.github.com/gists| grep "gist.github" | grep html_url | cut -c 16-59)
