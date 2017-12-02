#!/bin/bash

user="steam"
date=`date +%Y-%m-%d`
data="/home/${user}/.config/supertuxkart"
backup_dir="/home/${user}/backups/supertuxkart/${date}-backup"

sudo mkdir -p ${backup_dir}

if [[ -d "${data}" ]]; then

	echo -e "\n==> Backing up ${data} to ${backup_dir}\n"

	if ! sudo cp -rv ${data}/* ${backup_dir}; then
		echo "Failed to make backup!"
		exit 1
	fi

	if ! sudo chown -R ${user}:${user} ${backup_dir}; then
		echo "Failed to assign permissions!"
		exit 1
	fi

	echo ""
	read -erp "Copy backup to alternate directory? (y/n): " response

	if [[ "${response}" == "y" ]]; then

		read -erp "Location: " alt_loc
		mkdir -p ${alt_loc}
	
		if ! cp -r ${backup_dir} ${alt_loc}; then

			echo "Could not copy to alt dir, do you have permissions at the target?"

		fi
	fi

	echo -e "\n=== Backup complete! ===\n"

else

	echo "No save data directory found at: ${data}!"

fi
