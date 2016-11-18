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

cat <<-EOF

-----------------------------------------------------
Test: Default / Remove all configuration
-----------------------------------------------------

EOF

./configure-repos.sh && ./configure-repos.sh --remove

cat <<-EOF

-----------------------------------------------------
Test: Testing Repository / Remove Testing Repository
-----------------------------------------------------

EOF

./configure-repos.sh --enable-testing && ./configure-repos.sh --remove-testing

cat <<-EOF

-----------------------------------------------------
Test: Testing Repository / Remove all configurations 
-----------------------------------------------------

EOF

./configure-repos.sh --enable-testing && ./configure-repos.sh --remove

cat <<-EOF

-----------------------------------------------------
Test: Repair / Remove all configurations
-----------------------------------------------------

EOF

./configure-repos.sh --repair && ./configure-repos.sh --remove

cat <<-EOF

-----------------------------------------------------
Test: Default only
-----------------------------------------------------

EOF

./configure-repos.sh
