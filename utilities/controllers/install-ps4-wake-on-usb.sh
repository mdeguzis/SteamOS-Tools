#!/bin/bash

# =================================================================
# BAZZITE HTPC RECOVERY SCRIPT: PS4 Controller / Intel Bluetooth
# Targeted for: ASUS Z690, AMD GPU, Intel AX201
# =================================================================

echo "🚀 Starting Bazzite HTPC Sleep/Wake Fix..."

# 1. KERNEL ARGUMENTS (S3 Deep Sleep & PCIe Fix)
# Checks if args exist before adding to prevent duplicates
echo "Checking Kernel Arguments..."
CURRENT_KARGS=$(rpm-ostree kargs)

if [[ ! $CURRENT_KARGS == *"mem_sleep_default=deep"* ]]; then
    echo "Adding mem_sleep_default=deep..."
    sudo rpm-ostree kargs --append="mem_sleep_default=deep"
fi

if [[ ! $CURRENT_KARGS == *"pcie_port_pm=off"* ]]; then
    echo "Adding pcie_port_pm=off..."
    sudo rpm-ostree kargs --append="pcie_port_pm=off"
fi

# 2. UDEV RULES (Intel Bluetooth Wake Persistence)
echo "Restoring Udev Rules for Intel Bluetooth & USB Bus 1..."
UDEV_FILE="/etc/udev/rules.d/90-ps4-controller-wake.rules"
sudo mkdir -p /etc/udev/rules.d/

cat <<EOF | sudo tee $UDEV_FILE > /dev/null
# Enable wake for Intel Bluetooth (Bus 1, Port 14)
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTR{power/wakeup}="enabled"

# Enable wake for the parent root hub (Bus 1)
ACTION=="add", SUBSYSTEM=="usb", KERNEL=="usb1", ATTR{power/wakeup}="enabled"
EOF

# 3. ACPI WAKE TRIGGERS (Stopping the Wake Loop)
# Note: /proc/acpi/wakeup is a toggle. We check status first.
echo "Disarming noisy ACPI triggers (XHCI/AWAC)..."
for trigger in "XHCI" "AWAC"; do
    if grep -q "$trigger.*enabled" /proc/acpi/wakeup; then
        echo "Disabling $trigger..."
        echo "$trigger" | sudo tee /proc/acpi/wakeup
    else
        echo "$trigger is already disabled or not found."
    fi
done

# 4. BLUETOOTH STACK OPTIMIZATION
echo "Optimizing Bluetooth for FastConnectable..."
BT_CONF="/etc/bluetooth/main.conf"
# Using sed to ensure settings are correct without overwriting the whole file
sudo sed -i 's/^#\(FastConnectable = \).*/\1true/' $BT_CONF
sudo sed -i 's/^\(FastConnectable = \).*/\1true/' $BT_CONF

# 5. RELOAD SYSTEM
echo "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "-------------------------------------------------------"
echo "✅ Configuration Re-applied!"
echo "NOTE: If rpm-ostree added kernel args, you MUST restart."
echo "Current Sleep Mode: $(cat /sys/power/mem_sleep)"
echo "-------------------------------------------------------"
