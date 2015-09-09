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

# pre-reqs
sudo apt-get install git

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

# Some basic info
echo "-------------------------------------------------------" > bug.txt
echo "CPU Info" >> bug.txt
echo "-------------------------------------------------------" >> bug.txt
cat /proc/cpuinfo | grep -m3 -E 'model name|cpu cores|MHz' >> bug.txt
echo ""

# hardware info
echo "-------------------------------------------------------" > bug.txt
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
