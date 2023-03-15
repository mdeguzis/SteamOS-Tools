#!/bin/bash

cur=$PWD

# If you didn't install the "base-devel" group,
# we'll need those.
sudo pacman -S binutils make gcc fakeroot pkg-config --noconfirm --needed

if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d)
    echo "Working in temp dir: ${tmp}"
    cd $tmp

    # cower no longer found, skip?
    for pkg in auracle-git yay; do
	echo -e "\n===== Installing $pkg ======\n"
	sleep 4s
	git clone https://aur.archlinux.org/${pkg}.git
	cd ${pkg}
	if ! makepkg --needed --noconfirm --skippgpcheck -sri; then
		echo "Failed to install ${pkg}"
		exit 1
	fi
	cd $tmp
    done

    if ! command -v yay >/dev/null; then
        >&2 echo "Yay wasn't successfully installed"
	cd $cur
        exit 1
    fi
fi
cd $cur

