#!/bin/bash
# https://gaming.stackexchange.com/questions/336934/how-to-set-default-color-and-brightness-of-leds-of-the-dualshock-4-controller-on/336936#336936

# Set device
# Theoretically, you could repeat this for js1+
#udevadm info -a -p $(udevadm info -q path -n /dev/input/js0)

action=$1
led=$2

if [[ -z ${action} ]]; then
	echo "ERROR: First argument must be one of: install, run"
	exit 1
fi

if [[ ${action} == "install" ]]; then
	device_id=$(udevadm info -a -p $(udevadm info -q path -n /dev/input/js0) | grep 'ATTRS{phys}' | awk -F'==' '{print $2}' | sed 's/"//g')
	echo "Detected device_id for js0 as: ${device_id}"
	sudo cp -v ds4-udev.rule /etc/udev/rules.d/10-local-ds4.rules
	sudo sed -i "s|CHANGEME|${device_id}|" /etc/udev/rules.d/10-local-ds4.rules
	cat /etc/udev/rules.d/10-local-ds4.rules

elif [[ ${action} == "run" ]]; then
	RED=$((16#${2:0:2}))
	GREEN=$((16#${2:2:2}))
	BLUE=$((16#${2:4:2}))

	GLOBAL_LED=$(ls /sys/class/leds | grep global)
	LED=$(echo "$led" | egrep -o '[[:xdigit:]]{4}:[[:xdigit:]]{4}:[[:xdigit:]]{4}\.[[:xdigit:]]{4}')

	[[ -z "$LED" || ! -d "/sys/class/leds/$LED:global" ]] && exit

	echo 0 > /sys/class/leds/$LED:red/brightness
	echo 0 > /sys/class/leds/$LED:green/brightness
	echo 0 > /sys/class/leds/$LED:blue/brightness

	echo $RED > /sys/class/leds/$LED:red/brightness
	echo $GREEN > /sys/class/leds/$LED:green/brightness
	echo $BLUE > /sys/class/leds/$LED:blue/brightness
fi


