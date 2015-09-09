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

# prereqs

sudo apt-get install git

# function to paste to gist
# sourced from Stack exchange

function msg() {
  echo -n '{"description":"","public":"false","files":{"file1.txt":{"content":"'
  sed 's:":\\":g' "$1"
  echo '"}}'
}

# set bug report dir
bug_dir="/home/desktop/bug-reports"

# create temp bug report file
if [[ ! -d "$bug_dir" ]]
  # create DIR
  mkdir -p "$bug_dir"
fi

# get timestamp
timestamp=$(date +%Y%m%d-%H:%M:%S)

# Create bug report file
bug_report_file="${bug_dir}/bug_report_${timestamp})"

# lspci test
cat lspci -v > ${bug_report_file}

# create gist
msg  ${bug_report_file} | curl -v -d '@-' https://api.github.com/gists
