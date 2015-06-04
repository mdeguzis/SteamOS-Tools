<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [build-deb-from-PPA-readme](#build-deb-from-ppa-readme)
- [About](#about)
- [Usage](#usage)
- [Arguments](#arguments)
- [Troubleshooting](#troubleshooting)
- [Please note](#please-note)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# build-deb-from-PPA-readme

### About
This script allows you to plug in a few parameters to attempt to rebuild a Ubuntu PPA package on Debian.
 
### Usage

Install and run the utility using the script file provided here:
```
sudo ./build-deb-from-PPA.sh
```

### Arguments
You will be asked the following once the script is ran (examples below each):

**Please enter or paste the repo src URL now:**  
`deb-src http://ppa.launchpad.net/libretro/stable/ubuntu trusty main`

**Please enter or paste the GPG key for this repo now:**  
`ECA3745F `

**Please enter or paste the desired package name now:**  
`retroarch`

### Troubleshooting

If you received a large list of dependencies, run this through the `desktop-software.sh` script in the main repository folder.

```
./desktop-software install pkg1 pkg2 pkg3 pkg4
```

### Please note

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository.
