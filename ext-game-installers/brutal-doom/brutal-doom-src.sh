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

main ()
{
  
  if [[ "$opt" == "-help" ]]; then
  
  show_help
  
  elif [[ "$opt" == "install" ]]; then
  
  clear
  
  # remove previous log"
  rm -f "$scriptdir/logs/gzdoom-install.log"
  
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
  
  ############################################
  # Create folders for Project
  ############################################
  
  echo -e "\n==> Checking for Brutal Doom directory"
  sleep 0.2s
  
  if [[ -d "$HOME/gzdoom_build" ]]; then
    echo -e "\nBrutal Doom build directory found, cleaning"
    sudo rm -rf "$HOME/gzdoom-doom"
  else
    sudo mkdir "$HOME/gzdoom_build"
  fi
  
  ############################################
  # acquire GZDoom
  ############################################
  
  echo -e "\n==> Acquiring GZDoom files\n"
  sleep 2s
  
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
  
  echo -e "\n==> Acquiring FMOD files\n"
  
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
  
  echo -e "\n==> Configuring GZDoom\n"
  sleep 2s
  
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
  
  echo -e "\n==> Backing up important files\n"
  sleep 2s
  
  cd $HOME/gzdoom_build && \
  BACKUPGZDOOM="$(sed -n 's/.*#define GIT_DESCRIPTION "\(.*\)".*/\1/p' \
  gzdoom/src/gitinfo.h)" && \
  mkdir -pv "$BACKUPGZDOOM"
  
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/gzdoom" "$BACKUPGZDOOM"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/gzdoom.pk3" "$BACKUPGZDOOM"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/lights.pk3" "$BACKUPGZDOOM"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/brightmaps.pk3" "$BACKUPGZDOOM"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/liboutput_sdl.so" "$BACKUPGZDOOM"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/$FMODFOLDER/api/lib/$FMODFILE.so" "$BACKUPGZDOOM"
  
  #############################################
  # install GZDoom (deb pkg may be built later)
  #############################################
  
  echo -e "\n==> Building GZDoom\n"
  sleep 2s
  
  echo -e "\n==> Backing up important files\n"
  sleep 2s
  
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
  
  # Copy gzdoom, gzdoom.pk3, lights.pk3, brightmaps.pk3, 
  # liboutput_sdl.so and libfmodex64-4.26.36.so or 
  # libfmodex-4.26.36.so to /usr/games/gzdoom: 
  
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/gzdoom" "/usr/games/gzdoom"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/gzdoom.pk3" "/usr/games/gzdoom"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/lights.pk3" "/usr/games/gzdoom"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/brightmaps.pk3" "/usr/games/gzdoom"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/build/liboutput_sdl.so" "/usr/games/gzdoom"
  sudo cp -v "/home/$USER/gzdoom_build/gzdoom/$FMODFOLDER/api/lib/$FMODFILE.so" "/usr/games/gzdoom"
  
  #############################################
  # create GZDoom script
  #############################################
  
  echo -e "\n==> Creating GZDoom script\n"
  sleep 2s
  
  cd /tmp && \
  echo '#!/bin/sh' > gzdoom && \
  echo >> gzdoom && \
  echo 'export LD_LIBRARY_PATH=/usr/games/gzdoom' >> gzdoom && \
  echo 'exec /usr/games/gzdoom/gzdoom "$@"' >> gzdoom && \
  chmod 755 gzdoom && \
  sudo cp -v gzdoom /usr/bin && \
  rm -fv gzdoom
  
  echo -e "\n==INFO==\nExecute gzdoom with 'gzdoom' from a terminal window to run"
  
  ############################################
  # Configure
  ############################################
  
  echo -e "\n==> Running post-configuration\n"
  sleep 2s
  
  # TODO ?
  
elif [[ "$opt" == "uninstall" ]]; then
  
  #uninstall
  
  echo -e "\n==> Uninstalling GZDoom...\n"
  sleep 2s
  
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

}

# start script and log
main | tee "$scriptdir/logs/gzdoom-install.log"
