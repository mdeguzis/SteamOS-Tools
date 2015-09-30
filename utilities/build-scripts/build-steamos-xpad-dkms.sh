#========================================================================
# Build Script for steamos-xpad-dkms
#======================================================================== 
#
# Author:       Michael DeGuzis, 
# Date:         20150929
# Version:      0.3
# Description:  steamos-xpad-dkms build script for packaging.
#               This build script is meant for PPA uploads.
#
# ========================================================================

# Upstream vars from Valve's repo
steamos_kernel_url='https://github.com/ValveSoftware/steamos_kernel'
xpadsteamoscommit='9ce95a199ff868f76b059338ee8d5760aa33a064'
xpadsteamoscommit_short='9ce95a1'
xpad_source_file="https://github.com/ValveSoftware/steamos_kernel/raw/9ce95a199ff868f76b059338ee8d5760aa33a064/drivers/input/joystick/xpad.c"

# define base version
pkgname="steamos-xpad-dkms"
pkgver="20150930+git"

# build_dir
build_dir="${HOME}/${pkgname}_${pkgver}"

# Define release
dist_rel="Trusty"

# Define branch
BRANCH="master"

# Define upload target
LAUNCHPAD_PPA="ppa:mdeguzis/steamos-tools"

# Define uploader for changelog
uploader="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

# Define package maintainer for dsc and $pkgname-$pkgver-$pkgrel file 
pkgmaintainer="SteamOS-Tools Signing Key <mdeguzis@gmail.com>"

clear

cat<<- EOF
#####################################################################
Building steamos-xpad-dkms (patch level $PL)
#####################################################################

EOF

if [[ -n "$1" ]]; then

  echo ""
  echo -e "==INFO==\nbuild target is $1"
  echo ""

else
  echo ""
  echo -e "==INFO==\nbuild target is source"
  echo ""
fi

sleep 2s

cat<<- EOF
##########################################
Fetching necessary packages for build
##########################################

EOF

# install needed packages
sudo apt-get install git devscripts build-essential checkinstall \
debian-keyring debian-archive-keyring cmake g++ g++-multilib \
libqt4-dev libqt4-dev libxi-dev libxtst-dev libX11-dev bc libsdl2-dev \
gcc gcc-multilib

cat <<-EOF
##########################################
Setup build directory
##########################################

EOF

echo "$build_dir"

# setup build directory
if [[ -d "$build_dir" ]]; then

  # reset dir
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  cd "$build_dir"
  
else

  # setup build dir
  mkdir -p "$build_dir"
  cd "$build_dir"
  
fi

cat <<-EOF
##########################################
Setup package base files
##########################################

EOF

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
cd steamos-xpad-dkms || exit
git pull
git checkout $BRANCH
# remove git files
rm -rf .git .gitignore .hgeol .hgignore

# Create archive
echo -e "\n==> Creating archive"
cd .. || exit
tar cfj steamos-xpad-dkms.orig.tar.bz2 steamos-xpad-dkms
mv "steamos-xpad-dkms.orig.tar.bz2" "${pkgname}_${pkgver}.orig.tar.bz2"

cat <<-EOF
##########################################
Unpacking debian files
##########################################

EOF

# enter github repository
cd steamos-xpad-dkms

# copy in xpad.c over top the existing file from the desired commit
wget -O xpad.c $xpad_source_file

echo -e "\n==> changelog"
# Change version, uploader, insert change log comments
sed -i "s|version_placeholder|$pkgname_$pkgver|g" debian/changelog
sed -i "s|uploader|$uploader|g" debian/changelog
sed -i "s|dist_rel|$dist_rel|g" debian/changelog

echo -e "\nOpening change log for details to be added...\n"
sleep 5s
nano debian/changelog

echo -e "\n==> control"
sed -i "s|pkgmaintainer|$pkgmaintainer|g" debian/control

echo -e "\n==> rules"
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
  cat <<-EOF
  echo ##########################################
  echo Building binary package now
  echo ##########################################
  
EOF

    #build binary package
    debuild -us -uc

    if [ $? -eq 0 ]; then  
        cat <<-EOF
        ##########################################
        Building finished
        ##########################################
        
EOF
        
        ls -lah ~/pkg-build-tmp/steamos-xpad-dkms
         exit 0
    else  
        echo "debuild failed to generate the binary package, aborting"
        exit 1
    fi 
    ;;
  source)
    #get secret key
    gpgkey=$(gpg --list-secret-keys|grep "sec   "|cut -f 2 -d '/'|cut -f 1 -d ' ')

    if [[ -n "$gpgkey" ]]; then

      cat <<-EOF
      ##########################################
      Building source package
      ##########################################
      
EOF
    
      sleep 3s
      debuild -S -sa -k${gpgkey}

      if [ $? -eq 0 ]; then
        echo ""
        echo ""
        ls -lah ~/pkg-build-tmp/steamos-xpad-dkms
        echo ""
        echo ""
        echo "you can upload the package with dput ppa:mdeguzis/steamos-tools ~/pkg-build-tmp/steamos-xpad-dkms/steamos-xpad-dkms/${pkgname}_${pkgver}_source.changes"
        echo "all good"
        echo ""
        echo ""

        while true; do
            read -rp "Do you wish to upload the source package?    " yn
            case $yn in
                [Yy]* ) dput ppa:mdeguzis/steamos-tools ~/pkg-build-tmp/steamos-xpad-dkms/steamos-xpad-dkms/${pkgname}_${pkgver}_source.changes; break;;
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




