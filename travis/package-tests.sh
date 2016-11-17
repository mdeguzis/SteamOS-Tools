#!/bin/bash

# Set applications to test
APPLICATION_TESTS="kodi retroarch"

# No need to enter repo dir, but do it anyway for now
cd steamos-tools

for PKG in ${APPLICATION_TESTS};
do

	echo -e "Installing: ${PKG}"

	if sudo apt-get install -y --force-yes ${PKG} &> /dev/null; then

		echo -e "Package: ${PKG} [OK]"

	else

		# echo and exit if package install fails
		echo -e "Package test: ${PKG} [FAILED]"
		exit 1

	fi

done
