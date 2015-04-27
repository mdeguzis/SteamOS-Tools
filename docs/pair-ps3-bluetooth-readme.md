<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [pair-ps3-bluetooth-readme.md](#pair-ps3-bluetooth-readmemd)
    - [About](#about)
    - [Prerequisites](#prerequisites)
    - [Usage](#usage)
    - [Please note](#please-note)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# pair-ps3-bluetooth-readme.md

### About
This script installs the necessary packages for pairing Sony Dualshcok 3 PS3 Controllers, 
and subsequently attempts to pair them.
 
### Prerequisites
You will need to properly have added the Debian sources to your system, and properly pinned them for priority
underneath the SteamOS Alchemist repository. You can use the `add-debian-repos.sh` script in the main
SteamOS-Tools repository to add this automatically. You will need a support bluetooth receiver, a generic listing
of which can be found [here](http://elinux.org/RPi_USB_Bluetooth_adapters). You will also need a USB A-Male to Mini-B 
cable for your PS3 controller to pair it to the bluetooth receiver ([example](http://amzn.com/B00NH11N5A)).
 
### Usage

Install and run the script using the following command:
```
./pair-ps3-bluetooth.sh
```

Alternatively, and ideally, clone the repo for easy updates
```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
./pair-ps3-bluetooth.sh
```

After prerequisites packages are installed, pairing will begin. Please follow the onscreen 
dialog prompts to complete the process. Up to 4 controllers can be paired to the system

### Please note

Submit all questions, comments, and pull requests to the issues and pull requests area.
