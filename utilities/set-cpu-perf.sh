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
If reversion to your original mode fails, typically this is 'powersave'.

EOF

echo "Setting CPU to perf mode. enter 'quit' to revert back."
# Looping code curtosy of reddit user /u/anti_brain_freeze
for i in `cat /proc/cpuinfo | sed -e '/processor/!d; s/^.*: \([0-9]*\)$/\1/'`
do
	if ! sudo cpufreq-set -g performance -c $i; then
		echo "ERROR: Failed to set cpufreq mode to performance mode"
		exit 1
	else
		echo "Verifying change for cpu$i: $(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor)"
	fi
done

echo "Checking cpufreq-info"
cpufreq-info -o

# Sit idle
#CURR_MODE=powersave
while true; do
	read input
	if [[ $input = "quit" ]] || [[ $input = "q" ]]; then
		echo "Setting mode back to ${CURR_MODE}"
		for i in `cat /proc/cpuinfo | sed -e '/processor/!d; s/^.*: \([0-9]*\)$/\1/'`
		do
			if ! sudo cpufreq-set -g ${CURR_MODE} -c $i; then
				echo "ERROR: Failed to set cpufreq mode to ${CURR_MODE} mode"
				exit 1
			else
				echo "Verifying change for cpu$i: $(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor)"
			fi
		done
	fi
	break
done
