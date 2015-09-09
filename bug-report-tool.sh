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
bug_report_file="${bug_dir}/bug_report_${timestamp})"

# lspci test
cat lspci -v > $bug_report_file

# create gist using REST API

function msg() {
  echo -n '{"description":"","public":"false","files":{"file1.txt":{"content":"'
  sed 's:":\\":g' "$bug_report_file"
  echo '"}}'
}

msg "$bug_report_file" | curl -v -d '@-' https://api.github.com/gists


#gist_url=$(curl -sX POST --data-binary '{"files": {"file1.txt": {"content": "lspci -v"}}}' \
#https://api.github.com/gists| grep "gist.github" | grep html_url | cut -c 16-59)

# inform user to past url to git ticket

cat <<- EOF
-----------------------------------------------------------------
Summary
-----------------------------------------------------------------
Please paste the below URL into your SteamOS issues ticket at\n"
https://github.com/ValveSoftware/SteamOS/issues

URL: ${gist_url}

EOF

$gist
