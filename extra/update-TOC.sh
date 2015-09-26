#!/bin/bash

if [[ -d "$HOME/github_repos/SteamOS-Tools.wiki" ]]; then

	dir="$HOME/github_repos/SteamOS-Tools.wiki"

elif [[ -d "$HOME/SteamOS-Tools.wiki" ]]; then

	dir="$HOME/SteamOS-Tools.wiki"

fi

# update TOC for a given wiki page
# hard-coded to local DIR on workstation

# update
cd $dir
git pull 

clear

# show wiki dir
ls

echo -e "\nUpdate which wiki page?\n"
sleep 1s
read -ep "Choice: " wiki_page

doctoc $wiki_page
git add .
git commit -m "update TOC"
git push origin master
