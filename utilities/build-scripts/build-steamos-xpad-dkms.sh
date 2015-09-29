#========================================================================
# Build Script for steamos-xpad-dkms
#======================================================================== 
#
# Author:  Michael DeGuzis, 
# Date:    20150929
# Version: 0.1
# 
# ========================================================================


# define base version
pkgname='steamos-xpad-dkms'
pkgver='valve-git'
pkgrel='9ce95a1'

# Upstream vars from Valve's repo
steamos_kernel_url='https://github.com/ValveSoftware/steamos_kernel'
xpadsteamoscommit='f5f73eb889cac32cbabfc40362fe5635a2255836'

# Define release
REL="vivid"

#define branch
BRANCH="master"

#define upload target
LAUNCHPAD_PPA="ppa:mdeguzis/steamos-tools"

#define uploader for changelog
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

#define manpage program author
manpage_author="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

#define package maintainer for dsc and $pkgname-$pkgver-$pkgrel file 
pkgmaintainer="SteamOS-Tools Team <mdeguzis@gmail.com>"


clear
echo "#####################################################################"
echo "Building steamos-xpad-dkms (patch level $PL)"
echo "#####################################################################"
echo ""
if [[ -n "$1" ]]; then

  echo ""
  echo "build target is $1"
  echo ""

else
  echo ""
  echo "build target is source"
  echo ""
fi

sleep 2s

# Fetch build pkgs
if [[ -n "$2" ]]; then

  echo ""
  echo "##########################################"
  echo "Fetching necessary packages for build"
  echo "##########################################"
  echo ""

  #apt-get install packages
  sudo apt-get install -y build-essential fakeroot devscripts automake autoconf autotools-dev

  #get build dependencies
  sudo apt-get -y install debhelper cmake gcc

else
  echo ""
  echo "skipping installation of build packages, use arbitrary second argument to get those packages"
  echo ""
fi

echo ""
echo "##########################################"
echo "Setup build directory"
echo "##########################################"
echo ""
echo "~/pkg-build-tmp/steamos-xpad-dkms"
# start in $HOME
cd

# remove old build directory
rm -rf ~/pkg-build-tmp/steamos-xpad-dkms

#create build directory
mkdir -p ~/pkg-build-tmp/steamos-xpad-dkms

#change to build directory
cd ~/pkg-build-tmp/steamos-xpad-dkms

echo ""
echo "##########################################"
echo "Setup package base files"
echo "##########################################"

echo "dsc file"
sed -i "s|version_placeholder|$pkgname-$pkgver-$pkgrel|g" "steamos-xpad-dkms-$pkgname-$pkgver-$pkgrel.dsc"
sed -i "s|pkgmaintainer|$pkgmaintainer|g" "steamos-xpad-dkms-$pkgname-$pkgver-$pkgrel.dsc"

echo "original tarball"
git clone https://github.com/ProfessorKaos64/steamos-xpad-dkms

# sanity check
file steamos-xpad-dkms/

if [ $? -eq 0 ]; then  
    echo "successfully cloned/copied"
else  
    echo "git clone/copy failed, aborting"
    exit
fi 

# change to source folder
cd steamos-xpad-dkms
git pull
git checkout $BRANCH
# remove git files
rm -rf .git .gitignore .hgeol .hgignore

# Create archive
cd ..
tar cfj steamos-xpad-dkms.orig.tar.bz2 steamos-xpad-dkms
mv steamos-xpad-dkms.orig.tar.bz2 $pkgname_$pkgver-$pkgrel.orig.tar.bz2

echo ""
echo "##########################################"
echo "Unpacking debian files"
echo "##########################################"
echo ""

# enter github repository
cd steamos-xpad-dkms

# enter debian build folder
cd debian/

echo "changelog"
sed -i "s|version_placeholder|$pkgname-$pkgver-$pkgrel|g" debian/changelog
sed -i "s|uploader|$uploader|g" debian/changelog

echo "control"
sed -i "s|pkgmaintainer|$pkgmaintainer|g" debian/control

echo "rules"
sed -i "s|pkgver|$pkgver|g" debian/rules
sed -i "s|pkgrel|$pkgrel|g" debian/rules

if [[ -n "$1" ]]; then
  arg0=$1
else
  # set up default
  arg0=source
fi

case "$arg0" in
  compile)
    echo ""
    echo "##########################################"
    echo "Building binary package now"
    echo "##########################################"
    echo ""

    #build binary package
    debuild -us -uc

    if [ $? -eq 0 ]; then  
        echo ""
        echo "##########################################"
        echo "Building finished"
        echo "##########################################"
        echo ""
        ls -lah ~/pkg-build-tmp/steamos-xpad-dkms
         exit 0
    else  
        echo "debuild failed to generate the binary package, aborting"
        exit 1
    fi 
    ;;
  source)
    #get secret key
    gpgkey=`gpg --list-secret-keys|grep "sec   "|cut -f 2 -d '/'|cut -f 1 -d ' '`

    if [[ -n "$gpgkey" ]]; then

      echo ""
      echo "##########################################"
      echo "Building source package"
      echo "##########################################"
      echo ""
      echo "****** please copy your gpg passphrase into the clipboard ******"
      echo ""
      sleep 10

      debuild -S -sa -k$gpgkey

      if [ $? -eq 0 ]; then
        echo ""
        echo ""
        ls -lah ~/pkg-build-tmp/steamos-xpad-dkms
        echo ""
        echo ""
        echo "you can upload the package with dput ppa:mdeguzis/steamos-tools ~/pkg-build-tmp/steamos-xpad-dkms/steamos-xpad-dkms/$pkgname_$pkgver-$pkgrel""_source.changes"
        echo "all good"
        echo ""
        echo ""

        while true; do
            read -p "Do you wish to upload the source package?    " yn
            case $yn in
                [Yy]* ) dput ppa:mdeguzis/steamos-tools ~/pkg-build-tmp/steamos-xpad-dkms/steamos-xpad-dkms/$pkgname_$pkgver-$pkgrel""_source.changes; break;;
                [Nn]* ) break;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        exit 0
      else	
        echo "debuild failed to generate the source package, aborting"
        exit 1
      fi
    else
      echo "secret key not found, aborting"
      exit 1
    fi
    ;;
esac




