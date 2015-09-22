#!/bin/bash
# -------------------------------------------------------------------------------
# Author: 	    Michael DeGuzis
# Git:	      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name: 	test-suite.sh
# Script Ver:	  0.3.1
# Description:	Runs some tests to make sure package installs and functions on a
#               basic level work
#
# Usage:	      test-suite.sh [type]
# -------------------------------------------------------------------------------

type="$1"
scriptdir=$(pwd)

show_summary()
{
  
cat <<-EOF
----------------------------------------
Test suite $test Passed
----------------------------------------
EOF
sleep 3s

}

show_failure()

{
  
cat <<-EOF
----------------------------------------
Test suite $test FAILED!
----------------------------------------
EOF

exit 1
sleep 3s

}

reset_state()
{
  
  echo -e "==> Resetting state"
  sleep 2s
  
  # Remove packages
  sudo apt-get remove remove gedit -y &> /dev/null
  
  # Purge archive package
  sudo rm -f "/var/cache/apt/archive/gedit*"
  
}

run_test()
{
  
  # TEST
  if "$command"; then
  
    # show summary
    show_summary
    
  else
    
    # show failure
    show_failure
  
  fi
  
}


run_basic_tests()
{
  
  # reset test package states
  reset_state
  
  # desktop-software.sh tests
  test="desktop-software.sh [Debian Package]"
  pkg="gedit"
  # change to directory for test
  cd ..
  # set command and run test
  command="./desktop-software.sh install ${pkg}"
  run_test
  # return to scriptdir 
  cd "$scriptdir"
  
}

main()
{
  if [[ "$type" == "basic" ]]; then

   # run basic
    run_basic_tests
  
  fi
  
}

# MAIN script
clear
main
