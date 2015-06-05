#!/bin/bash

# -------------------------------------------------------------------------------
# Author:         	Michael DeGuzis
# Git:		          https://github.com/ProfessorKaos64/SteamOS-Tools
# Scipt Name:	      brutal-doom.sh
# Script Ver:	      0.0.1
# Description:	    Installs the latest Brutal Doom under Linux / SteamOS
#                   Based off of https://github.com/coelckers/gzdoom and
#                   http://zdoom.org/wiki/Compile_GZDoom_on_Linux
#                   Compile using CMake.
#
# Usage:	          ./brutal-doom.sh [install|uninstall]
#                   ./brutal-doom.sh -help
#
# Warning:	        You MUST have the Debian repos added properly for
#	                	Installation of the pre-requisite packages.
# -------------------------------------------------------------------------------

# get option
opt="$1"

show_help()
{
  
  clear
  echo -e "Usage:\n"
  echo -e "./brutal-doom.sh [install|uninstall]"
  echo -e "./brutal-doom.sh -help\n"
  exit 1
}

if [[ "$opt" == "-help" ]]; then
  
  show_help

elif [[ "$opt" == "install" ]]; then

  # set scriptdir
  scriptdir="/home/desktop/SteamOS-Tools"
  
  ############################################
  # Prerequisite packages
  ############################################
  
  #Build deps (for source building)
  sudo apt-get install build-essential zlib1g-dev libsdl1.2-dev libsdl2-dev libjpeg-dev \
  nasm tar libbz2-dev libgtk2.0-dev cmake git libfluidsynth-dev libgme-dev \
  libgl1-mesa-dev libglew-dev
  
  ############################################
  # vars
  ############################################
  
  brutal_dir="/home/steam/brutal-doom"
  
  ############################################
  # Create folders for Project
  ############################################
  
  echo -n "\n==> Checkin for Brutal Doom directory"
  
  if [[ -d "$brutal_dir" ]]; then
    echo -n "\nBrutal Doom directory found"
  else
    sudo mkdir $brutal_dir
  fi
  
  # enter dir
  cd $brutal_dir
  
  ############################################
  # acquire GZDoom
  ############################################
  
  # build dir
  mkdir -pv $HOME/gzdoom_build
  
  # source location
  cd $HOME/gzdoom_build && \
  git clone git://github.com/coelckers/gzdoom
  mkdir -pv gzdoom/build
  
  ############################################
  # Versioning
  ############################################
  
  # show latest
  # cd $HOME/gzdoom_build/gzdoom && \
  # git describe --tags $(git rev-list --tags --max-count=1)
  
  ############################################
  # acquire FMOD
  ############################################
  
  cd $HOME/gzdoom_build && \
  if [ "$(uname -m)" = "x86_64" ]; then 
  FMODFOLDER="fmodapi42636linux64" 
  else
  FMODFOLDER="fmodapi42636linux"
  fi && \
  wget -nc http://www.fmod.org/download/fmodex/api/Linux/$FMODFOLDER.tar.gz && \
  tar -xvzf $FMODFOLDER.tar.gz -C gzdoom
  
  ############################################
  # Build GZDoom
  ############################################
  
  cd $HOME/gzdoom_build/gzdoom/build && \
  if [ "$(uname -m)" = "x86_64" ]; then
  FMODFOLDER="fmodapi42636linux64"
  FMODFILE="libfmodex64-4.26.36"
  else
  FMODFOLDER="fmodapi42636linux"
  FMODFILE="libfmodex-4.26.36"
  fi && \
  make clean ; \
  cmake -DCMAKE_BUILD_TYPE=Release \
  -DFMOD_LIBRARY=$HOME/gzdoom_build/gzdoom/$FMODFOLDER/api/lib/$FMODFILE.so \
  -DFMOD_INCLUDE_DIR=$HOME/gzdoom_build/gzdoom/$FMODFOLDER/api/inc .. && \
  make
  
  ############################################
  # Backup files
  ############################################
  
  cd $HOME/gzdoom_build && \
  BACKUPGZDOOM="$(sed -n 's/.*#define GIT_DESCRIPTION "\(.*\)".*/\1/p' \
  gzdoom/src/gitinfo.h)" && \
  mkdir -pv "$BACKUPGZDOOM" && \
  cp -v gzdoom/build/{gzdoom,gzdoom.pk3,lights.pk3,\
  brightmaps.pk3,output_sdl/liboutput_sdl.so} "$BACKUPGZDOOM"
  
  cd $HOME/gzdoom_build && \
  BACKUPGZD="$(date +%Y%m%d%H%M)" && \
  mkdir -pv "$BACKUPGZD" && \
  cp -v gzdoom/build/{gzdoom,gzdoom.pk3,lights.pk3,\
  brightmaps.pk3,output_sdl/liboutput_sdl.so} "$BACKUPGZD"
  
  #############################################
  # install GZDoom (deb pkg may be built later)
  #############################################
  
  sudo mkdir -pv /usr/games/gzdoom
  
  # Copy gzdoom, gzdoom.pk3, lights.pk3, brightmaps.pk3, 
  # liboutput_sdl.so and libfmodex64-4.26.36.so or 
  # libfmodex-4.26.36.so to /usr/games/gzdoom:
  
  if [ "$(uname -m)" = "x86_64" ]; then
  FMODFOLDER="fmodapi42636linux64"
  FMODFILE="libfmodex64-4.26.36"
  else
  FMODFOLDER="fmodapi42636linux"
  FMODFILE="libfmodex-4.26.36"
  fi && \
  sudo cp -v /home/$USER/gzdoom_build/gzdoom/{build/{gzdoom,\
  gzdoom.pk3,lights.pk3,brightmaps.pk3,output_sdl/liboutput_sdl.so},\
  $FMODFOLDER/api/lib/$FMODFILE.so} /usr/games/gzdoom
  
  # create GZDoom script
  
  cd /tmp && \
  echo '#!/bin/sh' > gzdoom && \
  echo >> gzdoom && \
  echo 'export LD_LIBRARY_PATH=/usr/games/gzdoom' >> gzdoom && \
  echo 'exec /usr/games/gzdoom/gzdoom "$@"' >> gzdoom && \
  chmod 755 gzdoom && \
  sudo cp -v gzdoom /usr/bin && \
  rm -fv gzdoom
  
  echo -e "\n==INFO==\nexecut gzdoom with 'gzdoom' from a terminal window to run\n"
  
  ############################################
  # Configure
  ############################################
  
  # TODO ?

elif [[ "$opt" == "uninstall" ]]; then

  #uninstall
  
  # Remove /usr/games/gzdoom directory and all its files:
  cd /usr/games && \
  sudo rm -rfv gzdoom
  # Remove gzdoom script:
  cd /usr/bin && \
  sudo rm -fv gzdoom
  
else

  # if nothing specified, show help
    show_help

fi
