#!/bin/bash

user="steam"
date=`date +%Y-%m-%d`
configs="/home/${user}/.config/supertuxkart"
data="/home/${user}/.local/share/supertuxkart"
backup_dir="/home/${user}/backups/supertuxkart/${date}-backup"

sudo mkdir -p ${backup_dir}

backup_items="${configs} ${data}"

for item in ${backup_items};
do

	if [[ -d "${item}" ]]; then

		echo -e "\n==> Backing up ${item} to ${backup_dir}\n"

		if ! sudo cp -r ${item}/* ${backup_dir}; then
			echo "Failed to make backup!"
			exit 1
		fi

		if ! sudo chown -R ${user}:${user} ${backup_dir}; then
			echo "Failed to assign permissions!"
			exit 1
		fi

		echo -e "    Backup complete!"

	else

		echo "No configs directory found at: ${configs}!"

	fi

done

echo ""
read -erp "Copy backup to alternate directory? (y/n): " response

if [[ "${response}" == "y" ]]; then

	read -erp "Location: " alt_loc
	mkdir -p ${alt_loc}

	if ! cp -r ${backup_dir} ${alt_loc}; then

		echo "Could not copy to alt dir, do you have permissions at the target?"

	fi
fi

