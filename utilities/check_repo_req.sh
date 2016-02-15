
#!/bin/bash
# -----------------------------------------------------------------------
# Author: 		Michael DeGuzis
# Git:		      	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	  	check_repo_req.sh
# Script Ver:	  	0.1.3
# Description:		Check if Debian repos or outside sources are needed. 
#               	If user did not add these, exit.
#               	Vars are set per package and exported from the 
#			parent script this is called from.
#	
# Usage:	      	n/a , called from another script
# -----------------------------------------------------------------------

	
sources_check=$(sudo find /etc/apt -type f -name "$deb_repo_name")

# test vars if need be.
# echo "deb_repo_req is: $deb_repo_req"
# echo "sources_check is: $sources_check"
# echo "deb_repo_name is: $deb_repo_name"

# start repo check
if [[ "$deb_repo_req" == "yes" ]]; then

	echo -e "\n==Repository Check==\nExternal repository needed: [Yes]"
	
	# start sources eval
	if [[ "$sources_check" == "" ]]; then 
		echo -e "\n==ERROR==\nRequired external repository *NOT* detected!" 
		
		echo -e "\nIf you wish to exit, please press CTRL+C now."
	        echo -e "[c]ontinue, [a]dd Debian sources, [e]xit\n"
	
		# get user choice
		sleep 0.2s
		read -ep "Choice: " user_choice
	
		
		case "$user_choice" in
		        c|C)
			echo -e "\nContinuing...\n"
		        ;;
		        
		        a|A)
			echo -e "\nProceeding to configure-repos.sh"
			"$scriptdir/configure-repos.sh"
		        ;;
		         
		        e|e)
			echo -e "\nExiting script...\n"
			exit 1
		        ;;
		        
		         
		        *)
			echo -e "\nInvalid Input, Exiting script.\n"
			exit 1
			;;
		esac

	else 
                # simple output
                echo -e "Required external repository detected [OK]"
                
        # end sources eval
        fi
        
elif [[ "$deb_repo_req" == "no" ]]; then
	
	echo -e "\n==Repository Check==\nExternal repository needed: [No]\n"

# end repo check	
fi 


