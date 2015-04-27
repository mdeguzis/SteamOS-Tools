<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [add-debian-repos-readme.md](#add-debian-repos-readmemd)
    - [About](#about)
    - [Usage](#usage)
    - [Please note](#please-note)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# add-debian-repos-readme.md

### About
This script automatically adds or removes the Debian repositories from SteamOS.
The script MUST be run with sudo/root access, due to the locations of the apt
preferences file and the sources list for Wheezy as well. 
 
### Usage

Install and run the utility using the script file provided here:
```
sudo ./add-debian-repos.sh [Install|Uninstall]
```

Alternatively, and ideally, clone the repo for easy updates
```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
sudo ./add-debian-repos.sh [install|uninstall]
```

### Please note

Per: [Valve on Github](https://github.com/ValveSoftware/SteamOS/wiki/Installing-Applications-From-The-Wheezy-Repo-In-SteamOS)

```
Unfortunately the add/remove packages GUI pre-installed won't let you see any of the packages 
from the Debian repo. It would work if we set the pin priority to 110, but -10 safer.

N.B. Valve issued updates in January 2014 which means there is no need 
to use apt-pinning for wheezy repo. 
```

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository.
