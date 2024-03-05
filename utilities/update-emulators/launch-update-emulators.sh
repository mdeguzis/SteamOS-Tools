#!/bin/bash
# Spaws a new Konsole window to run the script

# Ignore dumb .so warnings by setting LD_PRELOAD to undefined
export LD_PRELOAD=""
konsole -e '$SHELL -c "${HOME}/.local/bin/update-emulators.sh; $SHELL" 2> /dev/null'
echo "Done!"
sleep 5
exit
