#!/bin/bash

# ensure doctoc is install

pkg_check=$(which doctoc)

if [[ "$pkg_check" == "" ]]; then

	sudo apt-get install npm
	sudo npm install -g doctoc

fi

# set dir
if [[ -d "$HOME/github_repos/SteamOS-Tools.wiki" ]]; then

	dir="$HOME/github_repos/SteamOS-Tools.wiki"

elif [[ -d "$HOME/SteamOS-Tools.wiki" ]]; then

	dir="$HOME/SteamOS-Tools.wiki"

else

	# clone wiki to $HOME and set dir
	cd
	git clone https://github.com/ProfessorKaos64/SteamOS-Tools.wiki.git
	dir="$HOME/SteamOS-Tools.wiki"

fi

# update TOC for a given wiki page
# hard-coded to local DIR on workstation

# update
cd $dir
git pull

clear

# show wiki dir
ls $dir

echo -e "\nUpdate which wiki page?\n"
sleep 1s
read -ep "Choice: " wiki_page

doctoc $wiki_page
git add .
git commit -m "update TOC"
git push origin master
