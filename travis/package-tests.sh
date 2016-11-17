#!/bin/bash

# Vars
BETA_REPO="false"

cat<<-EOF

----------------------------------------------------------
SteamOS-Tools package test suite
----------------------------------------------------------

EOF

# Set applications to test
APPLICATION_TEST+=()
APPLICATION_TEST+=("kodi")
APPLICATION_TEST+=("openpht")
APPLICATION_TEST+=("retroarch")

# Enter repo dir
cd steamos-tools

#############################
# Prep configure repos
#############################

# Don't invoke sudo
sed -i 's/sudo //g' configure-repos.sh
sed -i 's/sudo //g' desktop-software.sh

# Remove any sleep commands to speed up process
sed -i '/sleep/d' configure-repos.sh

# Configures repos
if [[ "$BETA_REPO" == "true" ]]; then

	./configure-repos.sh --enable-testing

else

	./configure-repos.sh

fi

#############################
# Application tests
#############################

for PKG in "${APPLICATION_TEST[@]}"
do

	cat<<-EOF

	----------------------------------
	Testing Package: ${PKG}
	----------------------------------

	EOF

	if apt-get install -y --force-yes ${PKG}; then

		echo -e "Package: ${PKG} [OK]"

	else

		# echo and exit if package install fails
		echo -e "Package test: ${PKG} [FAILED]"
		exit 1

	fi

done
