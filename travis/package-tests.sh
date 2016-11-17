#!/bin/bash

cat<<-EOF

----------------------------------------------------------
SteamOS-Tools package test suite
----------------------------------------------------------

EOF

# Travis vars
BETA_REPO="$BETA_REPO"

# Set applications to test
APPLICATION_TEST+=()
APPLICATION_TEST+=("kodi")
APPLICATION_TEST+=("openpht")
APPLICATION_TEST+=("retroarch")

# No need to enter repo dir, but do it anyway for now
cd steamos-tools

# Prep configure repos

# Don't invoke sudo
sed -i 's/sudo //g' configure-repos.sh

# Remove any sleep commands to speed up process
sed -i '/sleep/d' configure-repos.sh

# Configures repos
if [[ "$BETA_REPO" == "true" ]]; then

	./configure-repos.sh --enable-testing

else

	./configure-repos.sh

fi

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
