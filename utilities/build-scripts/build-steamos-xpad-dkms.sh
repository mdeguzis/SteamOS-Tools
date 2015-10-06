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
pkgver="20151001+git2"
pkgrev="1"
pkgrel="wily"

# build_dirs
build_dir="${HOME}/pkg-build-dir"
pkg_folder="${pkgname}_${pkgver}-${pkgrev}~${pkgrel}"

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
Building ${pkgname}_${pkgver}-${pkgrev}~${pkgrel}
#####################################################################

EOF

if [[ -n "$1" ]]; then

  echo ""
  echo -e "==INFO==\nbuild target is $1"
  echo ""

else
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
sudo apt-get install -y --force-yes git devscripts build-essential checkinstall \
debian-keyring debian-archive-keyring cmake g++ g++-multilib \
libqt4-dev libqt4-dev libxi-dev libxtst-dev libX11-dev bc libsdl2-dev \
gcc gcc-multilib nano dh-make gnupg-agent pinentry-curses

cat <<-EOF
##########################################
Setup build directory
##########################################

EOF

echo -e "\n==> Setup $build_dir\n"

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

echo -e "\n==> original tarball\n"
git clone https://github.com/ProfessorKaos64/steamos-xpad-dkms

# sanity check
file steamos-xpad-dkms/

if [ $? -eq 0 ]; then
    echo "successfully cloned/copied"
else
    echo "git clone/copy failed, aborting"
    exit
fi

# Change git folder to match pkg version format
mv steamos-xpad-dkms "$pkg_folder"

# change to source folder
cd "$pkg_folder" || exit
git pull
git checkout $BRANCH
# remove git files
rm -rf .git .gitignore .hgeol .hgignore

# Create archive
echo -e "\n==> Creating archive\n"
cd .. || exit
tar cfj steamos-xpad-dkms.orig.tar.bz2 "$pkg_folder"
# The original tarball should not have the revision and release tacked on
mv "steamos-xpad-dkms.orig.tar.bz2" "${pkgname}_${pkgver}.orig.tar.bz2"

cat <<-EOF
##########################################
Unpacking debian files
##########################################

EOF

# enter new package folder to work with Debian files
cd "$pkg_folder"

# (NOTICE: updated xpad.c when necessary)
# copy xpad.c over top the existing file on Github for updating
# Store this in the upstream git, rather than download here, or dpkg-source will complain 

echo -e "\n==> changelog"
# Change version, uploader, insert change log comments
sed -i "s|version_placeholder|$pkgname_$pkgver-$pkgrev~$pkgrel|g" debian/changelog
sed -i "s|uploader|$uploader|g" debian/changelog
sed -i "s|dist_rel|$pkgrel|g" debian/changelog

echo -e "\nOpening change log for details to be added...\n"
sleep 3s
nano debian/changelog

echo -e "\n==> control"
sed -i "s|pkgmaintainer|$pkgmaintainer|g" debian/control

echo -e "\n==> rules\n"
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

        ls  "$pkg_folder"
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
        ls -lah "$build_dir"
        echo ""
        echo "all good"
        echo ""

        while true; do
            read -rp "Do you wish to upload the source package?    " yn
            case $yn in
                [Yy]* ) dput ppa:mdeguzis/steamos-tools ${build_dir}/${pkgname}_${pkgver}-${pkgrev}~${pkgrel}_source.changes; break;;
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




