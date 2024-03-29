#!/bin/bash
# NOTE: This was yanked from ChimeraOS, add credit due there for this copy of the script.
export LC_ALL=C

# Scaffold some hefty guard rails around ensuring DISPLAY works
if [ -z "${DISPLAY}" ]; then
    # Hunt for an accessible DISPLAY
    for LOOP in {0..5}; do
        if env DISPLAY=:"${LOOP}" xdotool sleep 0 >&/dev/null; then
            export DISPLAY=:${LOOP}
            break
        fi
        if [ "${LOOP}" -eq 5 ]; then
            echo "ERROR! Failed to find an accessible display."
            exit 1
        fi
    done
else
    # Ensure DISPLAY is accessible
    if ! xdotool sleep 0 >&/dev/null; then
        echo "ERROR! ${DISPLAY} is not accessible."
        exit 1
    fi
fi

# Dump data
for CMD in glxinfo xdpyinfo xrandr; do
    # NOTE: xdpyinfo is not currently available in ChimeraOS; so we check availability
    if [ -x "$(command -v ${CMD})" ]; then
        if ! "${CMD}" > "/tmp/${CMD}.txt"; then
            echo "ERROR! ${CMD} failed."
            exit 1
        fi
    fi
done
cat /proc/cpuinfo > /tmp/cpuinfo.txt
udevadm info --export-db > /tmp/udevadm.txt

# Computer Information:
MANUFACTURER=$(cat /sys/devices/virtual/dmi/id/board_vendor)
MODEL=$(cat /sys/devices/virtual/dmi/id/board_name)
FORM_FACTOR=$(hostnamectl chassis)
if [ -z "${FORM_FACTOR}" ]; then
    FORM_FACTOR="unknown"
fi
TOUCH_DETECTED=$(grep ID_INPUT_TOUCHSCREEN=1 /tmp/udevadm.txt)
if [ -z "${TOUCH_DETECTED}" ]; then
    TOUCH_INPUT="No Touch Input Detected"
else
    TOUCH_INPUT="Touch Input Detected: $(awk '/ID_INPUT_TOUCHSCREEN=1/' RS= /tmp/udevadm.txt | grep "^E: NAME=" | cut -d '"' -f2)"
fi

# Processor Information:
CPU_VENDOR=$(grep 'vendor_id' /tmp/cpuinfo.txt | head -n1 | cut -d':' -f2 | sed 's/^ //')
CPU_NAME=$(grep 'model name' /tmp/cpuinfo.txt | head -n1 | cut -d':' -f2 | sed 's/^ //')
CPU_FAMILY="0x$(printf '%x\n' "$(grep 'cpu family' /tmp/cpuinfo.txt | head -n1 | cut -d':' -f2 | tr -d ' ')")"
CPU_MODEL="0x$(printf '%x\n' "$(grep 'model' /tmp/cpuinfo.txt | head -n1 | cut -d':' -f2 | tr -d ' ')")"
CPU_STEPPING="0x$(printf '%x\n' "$(grep 'stepping' /tmp/cpuinfo.txt | head -n1 | cut -d':' -f2 | tr -d ' ')")"
CPU_TYPE="0x0"
CPU_LOGICAL=$(nproc --all)
CPU_PHYSICAL=$(grep 'cpu cores' /tmp/cpuinfo.txt | head -n1 | cut -d':' -f2 | tr -d ' ')
CPU_SPEED="$(lscpu | grep 'CPU max MHz' | cut -d':' -f2 | tr -d ' ' | cut -d'.' -f1)"

function cpu_flag_status() {
    local FLAG=$1
    local LABEL=$2
    if grep ^flags /tmp/cpuinfo.txt | head -n1 | grep -q "${FLAG}"; then
        echo "    ${LABEL}:  Supported"
    else
        echo "    ${LABEL}:  Unsupported"
    fi
}

# Operating System Version:
OS="$(grep ^PRETTY_NAME /etc/os-release | cut -d'"' -f2) ($(getconf LONG_BIT) bit)"
if [ -r "/tmp/xdpyinfo.txt" ]; then
    X_SERVER_VENDOR=$(grep 'vendor string:' /tmp/xdpyinfo.txt | cut -d':' -f2 | sed 's/^[[:space:]]*//')
    X_SERVER_RELEASE=$(grep 'vendor release number:' /tmp/xdpyinfo.txt | cut -d':' -f2 | sed 's/^[[:space:]]*//')
else
    X_SERVER_VENDOR="Unknown"
    X_SERVER_RELEASE="Unknown"
fi

if pidof -q gamescope; then
    X_WINDOW_MANAGER="Gamescope"
elif pidof -q steamcompmgr; then
    X_WINDOW_MANAGER="Steam"
else
    X_WINDOW_MANAGER="Unknown"
fi

if [ -d "${HOME}"/.local/share/Steam/steamapps/common ]; then
    STEAM_RUNTIME_VERSION="steam-runtime_$(grep BUILD_ID "${HOME}"/.local/share/Steam/steamapps/common/SteamLinuxRuntime*/var/tmp-*/usr/lib/os-release | cut -d'"' -f2)"
else
    STEAM_RUNTIME_VERSION="None"
fi

# Video Card:
OPENGL_RENDERER=$(grep 'OpenGL renderer string:' /tmp/glxinfo.txt | cut -d':' -f2 | sed 's/^ //')
OPENGL_VERSION_LONG=$(grep 'OpenGL version string' /tmp/glxinfo.txt | cut -d':' -f2 | sed 's/^ //')
OPENGL_VERSION_SHORT=$(grep 'OpenGL version string' /tmp/glxinfo.txt | cut -d':' -f2 | cut -c 2-4)
if [ -r "/tmp/xdpyinfo.txt" ]; then
    COLOR_DEPTH=$(grep 'depth of root window:' /tmp/xdpyinfo.txt | cut -d':' -f2 | tr -s ' ' | cut -d' ' -f2)
    DESKTOP_RESOLUTION=$(grep 'dimensions:' /tmp/xdpyinfo.txt | sed -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/' | sed 's/x/ x /')
else
    COLOR_DEPTH="24"
    DESKTOP_RESOLUTION=$(env DISPLAY=${DISPLAY} xdotool getdisplaygeometry | sed 's/ / x /')
fi
REFRESH_RATE=$(grep -Eo '[0-9][0-9][.][0-9][0-9]\*' /tmp/xrandr.txt | head -n1 | cut -d'.' -f1)
VGA_PCI_ID=$(lspci -nd::0300 | head -n1 | grep -Eo "[[:xdigit:]]{4}:[[:xdigit:]]{4}")
VGA_VENDOR_ID="0x${VGA_PCI_ID:0:4}"
VGA_DEVICE_ID="0x${VGA_PCI_ID:5:4}"
NUM_OF_MONITORS=$(env DISPLAY=${DISPLAY} xrandr --listmonitors | head -n1 | cut -d':' -f2 | tr -d ' ')
NUM_OF_VIDEO_CARDS=$(lspci | grep -c ' VGA ')
PRIMARY_DISPLAY_RESOLUTION=$(env DISPLAY=${DISPLAY} xdotool getdisplaygeometry | sed 's/ / x /')
# Get the primary display size, accounting for multi-monitor setups where the primary might be disconnected
PRIMARY_DISPLAY_SIZE=$(awk '/ connected primary/{print sqrt( ($(NF-2)/10)^2 + ($NF/10)^2 )/2.54"\" (diag)"}' /tmp/xrandr.txt)
if [ -z "${PRIMARY_DISPLAY_SIZE}" ]; then
    PRIMARY_DISPLAY_SIZE=$(awk '/ connected/{print sqrt( ($(NF-2)/10)^2 + ($NF/10)^2 )/2.54"\" (diag)"}' /tmp/xrandr.txt)
fi
PRIMARY_VRAM=$(grep "Dedicated video memory:" /tmp/glxinfo.txt | cut -d':' -f2 | sed 's/^ *//')

# Sound card:
AUDIO_DEVICE=$(pulsemixer --list-sinks | grep Default | cut -d',' -f2 | sed 's/ Name: //')

# Memory:
RAM=$(grep MemTotal /proc/meminfo | tr -s ' ' | cut -d' ' -f2)
RAM=$((RAM / 1024))

# Miscellaneous:
DISK_SIZE=$(df -h --output='size' --block-size M /home | tail -n1 | tr -d ' M')
DISK_AVAIL=$(df -h --output='avail' --block-size M /home | tail -n1 | tr -d ' M')

# Storage:
HDD=0
SSD=0
OLD_IFS="${IFS}"
IFS=$'\n'
for BLOCK_DEVICE in $(lsblk --nodeps --output name,tran,rota --noheadings --exclude 7); do
    TRANSPORT=$(echo "${BLOCK_DEVICE}" | awk '{print $2}')
    # Ignore USB connected drives
    if [ "${TRANSPORT}" == "usb" ]; then
        continue
    else
        ROTATIONAL=$(echo "${BLOCK_DEVICE}" | awk '{print $3}')
        if [ "${ROTATIONAL}" -eq 1 ]; then
            ((HDD+=1))
        else
            ((SSD+=1))
        fi
    fi
done
IFS="${OLD_IFS}"

# The spacing below is required to be compatible with Steam System Information output
echo "
Computer Information:
    Manufacturer:  ${MANUFACTURER}
    Model:  ${MODEL}
    Form Factor: ${FORM_FACTOR^}
    ${TOUCH_INPUT}

Processor Information:
    CPU Vendor:  ${CPU_VENDOR}
    CPU Brand:  ${CPU_NAME}
    CPU Family:  ${CPU_FAMILY}
    CPU Model:  ${CPU_MODEL}
    CPU Stepping  ${CPU_STEPPING}
    CPU Type:  ${CPU_TYPE}
    Speed:  ${CPU_SPEED} Mhz
    ${CPU_LOGICAL} logical processors
    ${CPU_PHYSICAL} physical processors"
    cpu_flag_status ht HyperThreading
    cpu_flag_status cmov FCMOV
    cpu_flag_status sse2 SSE2
    cpu_flag_status sse3 SSE3
    cpu_flag_status sse4a SSE4a
    cpu_flag_status sse4_1 SSE41
    cpu_flag_status sse4_2 SSE42
    cpu_flag_status aes AES
    cpu_flag_status avx AVX
    cpu_flag_status avx2 AVX2
    cpu_flag_status avx512f AVX512F
    cpu_flag_status avx512pf AVX512PF
    cpu_flag_status avx512er AVX512ER
    cpu_flag_status avx512cd AVX512CD
    cpu_flag_status avx512_vnni AVX512VNNI
    cpu_flag_status sha_ni SHA
    cpu_flag_status cx16 CMPXCHG16B
    cpu_flag_status lahf_lm LAHF/SAHF
    cpu_flag_status prefetch PrefetchW
echo "
Operating System Version:
    ${OS}
    Kernel Name:  $(uname)
    Kernel Version:  $(uname -r)
    X Server Vendor:  ${X_SERVER_VENDOR}
    X Server Release:  ${X_SERVER_RELEASE}
    X Window Manager:  ${X_WINDOW_MANAGER}
    Steam Runtime Version:  ${STEAM_RUNTIME_VERSION}

Video Card:
    Driver:  ${OPENGL_RENDERER}
    Driver Version:  ${OPENGL_VERSION_LONG}
    OpenGL Version: ${OPENGL_VERSION_SHORT}
    Desktop Color Depth: ${COLOR_DEPTH} bits per pixel
    Monitor Refresh Rate: ${REFRESH_RATE} Hz
    VendorID:  ${VGA_VENDOR_ID}
    DeviceID:  ${VGA_DEVICE_ID}
    Revision Not Detected
    Number of Monitors:  ${NUM_OF_MONITORS}
    Number of Logical Video Cards:  ${NUM_OF_VIDEO_CARDS}
    Primary Display Resolution:  ${PRIMARY_DISPLAY_RESOLUTION}
    Desktop Resolution: ${DESKTOP_RESOLUTION}
    Primary Display Size: ${PRIMARY_DISPLAY_SIZE}
    Primary VRAM: ${PRIMARY_VRAM}

Sound card:
    Audio device: ${AUDIO_DEVICE}

Memory:
    RAM:  ${RAM} MB

VR Hardware:
    VR Headset: None detected

Miscellaneous:
    UI Language:  English
    LANG:  $(localectl status | grep 'LANG=' | cut -d'=' -f2)
    Total Hard Disk Space Available:  ${DISK_SIZE} MB
    Largest Free Hard Disk Block:  ${DISK_AVAIL} MB

Storage:
    Number of SSDs: ${SSD}
    Number of HDDs: ${HDD}"

rm /tmp/cpuinfo.txt /tmp/glxinfo.txt /tmp/xdpyinfo.txt /tmp/xrandr.txt  /tmp/udevadm.txt 2>/dev/null

