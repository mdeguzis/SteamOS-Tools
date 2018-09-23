#!/bin/bash
if [[ ! $(dpkg -l cpufrequtils 2> /dev/null) ]]; then
	echo "ERROR: cpufrequtils is not installed."
	echo "sudo apt-get install cpufrequtils"
	exit 1
fi

# Check current mode
CURR_MODE=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
cat<<-EOF

Note: Your current mode is ${CURR_MODE}
You will want to ensure you set this back when you are done playing
if you you forget to type "quit" when done here.

EOF

echo "Setting CPU to perf mode. enter 'quit' to revert back."
if ! sudo cpufreq-set -g performance; then
	echo "ERROR: Failed to set cpufreq mode to performance mode"
	exit 1
else
	echo "Verifying change:"
	cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
fi

# Sit idle
while true; do
	read input
	if [[ $input = "quit" ]] || [[ $input = "q" ]] 
		echo "Setting mode back to ${CURR_MODE}"
		sudo cpufreq-set -g ${CURR_MODE}
		echo "Verifying mode reversion:"
		cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
		then break 
	fi
done
