# Bazzite HTPC Sleep & Wake Configuration (ASUS Z690)

Documentation of fixes for the "Instant Wake/Reboot Loop" and "Black Screen on Resume" issues on Bazzite (Fedora-based) for ASUS Z690 systems using AMD GPUs and Intel Bluetooth.

## 🛠 System Environment
- **OS:** Bazzite (Atomic/Immutable)
- **Motherboard:** ASUS Z690 Series
- **GPU:** AMD Radeon (using `amdgpu` drivers)
- **Bluetooth/Wi-Fi:** Intel AX201 (Internal USB/PCIe)
- **Controller:** DualShock 4 (PS4) via Bluetooth

---

## 1. The Core Issues Resolved
1. **Instant Wake Loop:** The system would "click" off and immediately power back on when trying to sleep.
2. **Black Screen on Resume:** The GPU failed to initialize the display when waking from default `s2idle` mode.
3. **Broken Wake-on-Controller:** The Bluetooth radio was disabled during deep sleep, preventing the PS4 controller from waking the PC.

---

## 2. The Final Working Configuration

### A. Kernel Arguments (The Foundation)
Forced the system to use **S3 (Deep Sleep)** instead of Modern Standby to fix the AMD GPU black screen and power stability.

```
# Set sleep mode to Deep and disable PCIe Port Power Management
sudo rpm-ostree kargs --append="mem_sleep_default=deep" --append="pcie_port_pm=off"
```

### B. ACPI Wake Disarming

To stop the "Instant Wake" loop, we disarmed noisy hardware triggers. The most critical was `XHCI` (USB 3.0) and `AWAC` (RTC).

```
# Surgical disable of auto-wake triggers
echo "XHCI" | sudo tee /proc/acpi/wakeup
echo "AWAC" | sudo tee /proc/acpi/wakeup
```

### C. Persistent USB Wake for Bluetooth

To allow the PS4 controller to wake the PC, we created a custom `udev` rule. This enables wake *only* for the Intel Bluetooth radio and its parent USB hub (`Bus 001`), keeping the rest of the noisy USB ports quiet.

**File:** `/etc/udev/rules.d/90-ps4-controller-wake.rules`

```udev
# Enable wake for Intel Bluetooth (Bus 1, Port 14)
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTR{power/wakeup}="enabled"

# Enable wake for the parent root hub (Bus 1)
ACTION=="add", SUBSYSTEM=="usb", KERNEL=="usb1", ATTR{power/wakeup}="enabled"
```

### D. Bluetooth Stack Optimization

Adjusted the Bluetooth service to scan more aggressively upon waking, helping the controller reconnect after the S3 "cold boot."

**File:** `/etc/bluetooth/main.conf`

```ini
[General]
FastConnectable = true
PageScanInterval = 16
PageScanWindow = 16
PageTimeout = 32768

[Policy]
AutoEnable = true
```

---

## 3. The "Double-Tap" Compromise

Because **Deep Sleep (S3)** completely powers down the Intel Bluetooth radio:

1. **Press 1:** Wakes the PC hardware from S3. The Linux Bluetooth driver begins loading firmware.
2. **Press 2 (3 seconds later):** Connects the controller to the now-active Bluetooth stack.

*Note: This is preferred over S2Idle as it prevents the GPU driver from hanging and saves significantly more power.*

---

## 4. Troubleshooting Checklist

* **BIOS Settings:**
* `APM Configuration > Power On By PCI-E`: **Enabled** (Required for the Bluetooth wake signal).
* `APM Configuration > ErP Ready`: **Disabled** (Required to keep 5V standby power to the Bluetooth chip).
* `USB Configuration > Legacy USB Support`: **Enabled** or **Auto**.


* **System Check:**
* Verify sleep state: `cat /sys/power/mem_sleep` (Should show `s2idle [deep]`).
* Verify wake paths: `grep . /sys/bus/usb/devices/usb1/power/wakeup` (Should show `enabled`).

