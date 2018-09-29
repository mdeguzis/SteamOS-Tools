#!/bin/bash
echo "For nvidia only! CTRL C to exit now"
sleep 3s
echo "Detecting driver nvidia..."
sleep 2s
gpu_driver=$(lshw -c video 2> /dev/null | awk '/configuration/{print $2}' | sed 's/driver=//')
if [[ ${gpu_driver} != "nvidia" ]]; then
	echo "ERROR: Failed to locate nvidia driver in use, aborting..."
	echo "Got: ${gpu_driver}"
	exit 1
else
	echo "Found driver: ${gpu_driver}"
fi
sudo apt-get purge amdgpu-pro-vulkan-driver
sudo apt purge mesa-vulkan-drivers
sudo apt purge mesa-vulkan-drivers:i386

echo "Check for warn/error in vulkaninfo..."
sleep 2s
vulkan_err_warn=$(vulkaninfo | grep -iE 'error|warn')
if [[ ${vulkan_err_warn} != "" ]]; then
	echo "Got these vulkan err/warn messages, please check into these:"
	echo ${vulkan_err_warn}
else
	echo "No vulkaninfo warn/err messages!"
fi

echo "For more info, run 'vulkaninfo'"
