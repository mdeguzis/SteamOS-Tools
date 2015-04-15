# steamos-stats.sh

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

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository
 here
