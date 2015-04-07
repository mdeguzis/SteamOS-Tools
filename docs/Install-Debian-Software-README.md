## About
This script aids in installing basic or full sets of Debian software
to SteamOS.
 
## Usage

You can run the utility using the follwing options:
```
sudo ./install-debian-software.sh [option] [type]
```
**Options:** [install|uninstall|list]  
**Type:** [basic|extra|emulation|<pkg_name>]

**install:**   
installs software based on type desired  
**uninstall:**   
uninstalls software based on type installed already  
**list:**   
lists softare pacakges in each install group  

**basic:**  
installs basic Debian software (based on [Distrowatch](http://distrowatch.com/table.php?distribution=debian))  
**extra:**  
installs extra softare based on feedback and personal preference  
**emulation:**  
retroarch and associated emulators. 
**<pkg_name:**  
install package specifified from Alchemist/Wheezy  

Alternatively, and ideally, clone the repo for easy updates
```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
sudo ./install-debian-software.sh [option] [type]
```

## Emulation type Warning
Installing retroarch and the emulators takes a very long time!. Please be aware of this before attempting the installation. Installing prerequisite packages, compiling Retorarch, and it's emulators, is time-intensive. This component of the script is very much *still in progress!* 

I will do my best to reduce overhead on this installation piece as much as possible.

### Please note

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository
 here
