#!/bin/bash

# just a simple command to reclone the git repo if things get our of hand
cd
rm -rf ~/SteamOS-Tools
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
git checkout testing
