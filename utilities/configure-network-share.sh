#!/bin/bash
# -------------------------------------------------------------------------------
# Author:     		Michael DeGuzis
# Git:		    	https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:		configure-network-share.sh
# Script Ver:	  	0.1.1
# Description:		Create network sahre for other computers (IN PROGRESS)
#
# -------------------------------------------------------------------------------

scriptdir=$(pwd)

install_prereqs()
{

  # Install needed software
  sudo apt-get install -y --force-yes samba smbclient

}

main_menu()
{
  while [[ "$configure_choice" != "4" || "$configure_choice" != "done" ]];
  		do	
  		
  		cat<<- EOF 
  		#############################################################
  		What do you wish to do?
  		#############################################################
  		
  		(1) Create publich network share (no password)
  		(2) Connect existing share permanently
  		(3) Connect existing share temporarily
  		(4) Exit

      EOF
      
  		# the prompt sometimes likes to jump above sleep
  		sleep 0.5s
  	
  		read -erp "Choice: " configure_choice
  	
  		case "$configure_choice" in
  	
  			1)
  			share_type="public"
  			create_samba_share
  			;;
  	
  			2)
  			# attach_share_perm
  			;;
  			 
  			3)
  			# attach_share_temp
  			;;

  		esac

  done

}

create_samba_share()
{
  #################################################
  # Samba Shares
  #################################################
  # https://wiki.archlinux.org/index.php/Samba/Tips_and_tricks#Share_files_without_a_username_and_password
  
  echo -e "\n==> Configuring samba shares for remote access"
  
  # remove old shares
  
  # For saftely, a start/end method is used here to only kill the lines we added
  # This will only remove the tagged block of text
  # This keeps the share itself updated from whatever the repo is, of course provided
  # the tags are kept (note to self)
  
  # Name the share
  read -erp "Please name your share: " MYSHARE
  
  # See: http://serverfault.com/a/137848
  # Remove our previous entry added, to update with corrections or changes
  sudo sed -i '\:# START $MYSHARE shares:,\:# END $MYSHARE shares:d' "/etc/samba/smb.conf"
  
  # append config for shares
  if [[ "$share_type" == "public" ]]; then
  
    sudo bash -c 'cat "../cfgs/samba/generic-share-public.cfg" >> "/etc/samba/smb.conf"'
    
  fi
  
  # restart services smbd and nmbd, not samba
  # Debian bug: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=769714
  sudo systemctl restart smbd
  sudo systemctl restart nmbd
  
}

# Install needed software
install_prereqs

# start up main function
main_menu

