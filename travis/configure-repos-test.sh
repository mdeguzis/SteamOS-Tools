#!/bin/bash

cat <<-EOF

------------------------------------------
Configure repos test
------------------------------------------

EOF

# enter repo folder
cd steamos-tools

# Don't invoke sudo
sed -i 's/sudo //g' configure-repos.sh

# Remove any sleep commands to speed up process
sed -i '/sleep/d' configure-repos.sh

# run tests
sed -i 's/-q --show-progress -nc/-nc/g' configure-repos.sh
./configure-repos.sh && ./configure-repos.sh --remove
./configure-repos.sh --enable-testing && ./configure-repos.sh --remove-testing
./configure-repos.sh --enable-testing && ./configure-repos.sh --remove
./configure-repos.sh --default && ./configure-repos.sh --remove
./configure-repos.sh --repair && ./configure-repos.sh --remove
./configure-repos.sh
