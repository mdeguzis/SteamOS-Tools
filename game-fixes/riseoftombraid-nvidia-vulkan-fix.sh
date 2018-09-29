#!/bin/bash
echo "For nvidia only! CTRL C to exit now"
sleep 5s
sudo apt-get purge amdgpu-pro-vulkan-driver
sudo apt purge mesa-vulkan-drivers
sudo apt purge mesa-vulkan-drivers:i386

echo "Check for warn/error in vulkaninfo..."
sleep 2s
vulkaninfo | less
