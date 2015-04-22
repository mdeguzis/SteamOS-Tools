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

Per: [https://github.com/ValveSoftware/SteamOS/wiki/Installing-Applications-From-The-Wheezy-Repo-In-SteamOS](Github/Valve)

[quote]
Unfortunately the add/remove packages GUI pre-installed won't let you see any of the packages from the Debian repo. It would work if we set the pin priority to 110, but -10 safer.

N.B. Valve issued updates in January 2014 which means there is no need to use apt-pinning for wheezy repo. 
[/quote]

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository here
