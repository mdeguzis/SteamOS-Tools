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
  
  echo -e "==> Running test $test, please wait."
  sleep 2s
  
  # TEST
  if bash -c "$command"; then
  
    # show summary
    echo -e "\n\tTest $test [PASSED]"
    
  else
    
    # show failure
    echo -e "\n\tTest $test [FAILED]"
  
  fi
  
}


run_basic_tests()
{
  
  # reset test package states
  reset_state
  
  #######################################################
  # desktop-software.sh tests
  #######################################################
  test="desktop-software.sh [Debian Package]"
  pkg="gedit"
  command="echo c | ../desktop-software.sh install ${pkg} &> /dev/null"
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
