#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  bug-report-tool.sh
# Script Ver:	  0.1.1
# Description:	Captures important system information in a semi-readible format
#               to attach to a SteamOS bug report at github.com/ValveSoftware/SteamOS/issues
#
# Usage:	      bug-report-tool.sh
#
# -------------------------------------------------------------------------------

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

# some basic output to test:
# CPU
echo "-------------------------------------------------------" > bug.txt
echo "Steam Info" >> bug.txt
echo "-------------------------------------------------------" >> bug.txt
echo $steam_ver >> bug.txt
echo $steam_api >> bug.txt

# CPU
echo -e "\n-------------------------------------------------------" >> bug.txt
echo "CPU Info" >> bug.txt
echo "-------------------------------------------------------" >> bug.txt
cat /proc/cpuinfo | grep -m3 -E 'model name|cpu cores|MHz' >> bug.txt
echo ""

#GPU
echo -e "\n-------------------------------------------------------" >> bug.txt
echo "GPU Info" >> bug.txt
echo "-------------------------------------------------------" >> bug.txt
lspci -v | grep -A 10 VGA | grep -E 'VGA|Kernel' >> bug.txt

# hardware info
echo -e "\n-------------------------------------------------------" >> bug.txt
echo "Full PCI info" >> bug.txt
echo "-------------------------------------------------------" >> bug.txt
lspci -v >> bug.txt

clear
cat <<- EOF
-----------------------------------------------------------------
Summary
-----------------------------------------------------------------
Please paste the below URL into your SteamOS issues ticket at\n"
https://github.com/ValveSoftware/SteamOS/issues

EOF

# create gist
./gistcli -f bug.txt

#gist_url=$(curl -sX POST --data-binary '{"files": {"file1.txt": {"content": "lspci -v"}}}' \
#https://api.github.com/gists| grep "gist.github" | grep html_url | cut -c 16-59)
