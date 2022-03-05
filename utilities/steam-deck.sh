#!/bin/bash
# Description: Install/uninstall gamepad UI from Steam Deck

cat<<-EOF
=============================================
Steam deck gamepad UI tester
=============================================

EOF

OPTION=$1

CLIENT_BETA_CONFIG="${HOME}/.local/share/Steam/package/beta"
DECK_VER="steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d"
DECK_CONF="${HOME}/.config/environment.d/deckui.conf"
AMD=$(lspci -v | grep VGA | grep -E 'AMD|ATI')

# Adjustable
RES_H="1080"
RES_W="1920"

if [[ -z ${OPTION} ]]; then
    echo "Missingi argument! One of: install, uninstall."
    exit 1
fi

echo -e "${OPTION}ing the Steam Deck EXPERIENCE on your desktop. Heh.\n"

mkdir -p ~/.config/environment.d

if [[ ${CLIENT_BETA_CONFIG} ]]; then
    echo "Backing up existing ${CLIENT_BETA_CONFIG} to ${CLIENT_BETA_CONFIG}.old"
    sudo cp ${CLIENT_BETA_CONFIG} ${CLIENT_BETA_CONFIG}.orig
fi

# "publicbeta" is the original beta config if added previously
if [[ ${OPTION} == "install" ]]; then
    sudo bash -c "echo ${DECK_VER} > ${CLIENT_BETA_CONFIG}"
else
    if [[ -f ${CLIENT_BETA_CONFIG}.orig ]]; then
        sudo bash -c "echo publicbeta > ${CLIENT_BETA_CONFIG}"
    else
        rm -f ${CLIENT_BETA_CONFIG}
    fi
fi

if [[ ${OPTION} == "install" ]]; then
cat <<EOF >> ${DECK_CONF}
GAMESCOPECMD="gamescope -W ${RES_W} -H ${RES_H} --steam -f"
STEAMCMD="steam -steamos -gamepadui"
EOF
else
    rm -f ${DECK_CONF}
fi


if [[ -n ${AMD} ]]; then
    echo "AMD GPU found, using gamescope"
    sudo systemctl stop lightdm
    sudo systemctl start gamescope@tty1
else
    echo "Warning: Did not see an AMD GPU in use, falling back to lightdm only..."
    sudo systemctl restart lightdm
 fi
 
 echo "Done!"
DECK_VER="steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d"
DECK_CONF="${HOME}/.config/environment.d/deckui.conf"
AMD=$(lspci -v | grep VGA | grep -E 'AMD|ATI')

# Adjustable
RES_H="1080"
RES_W="1920"

if [[ -z ${OPTION} ]]; then
    echo "Missingi argument! One of: install, uninstall."
    exit 1
fi

echo "${OPTION}ing the Steam Deck EXPERIENCE on your desktop. Heh."

mkdir -p ~/.config/environment.d

if [[ ${CLIENT_BETA_CONFIG} ]]; then
    echo "Backing up existing ${CLIENT_BETA_CONFIG} to ${CLIENT_BETA_CONFIG}.old"
    sudo cp ${CLIENT_BETA_CONFIG} ${CLIENT_BETA_CONFIG}.orig
fi

# "publicbeta" is the original beta config if added previously
if [[ ${OPTION} == "install" ]]; then
   sudo bash -c "echo ${DECK_VER} > ${CLIENT_BETA_CONFIG}"
else
    if [[ -f ${CLIENT_BETA_CONFIG}.orig ]]; then
        sudo bash -c "echo publicbeta > ${CLIENT_BETA_CONFIG}"
    else
        rm -f ${CLIENT_BETA_CONFIG}
    fi
fi

if [[ ${OPTION} == "install" ]]; then
cat <<EOF >> ${DECK_CONF}
GAMESCOPECMD="gamescope -W ${RES_W} -H ${RES_H} --steam -f"
STEAMCMD="steam -steamos -gamepadui"
EOF
else
    rm -f ${DECK_CONF}
fi


if [[ -n ${AMD} ]]; then
    echo "AMD GPU found, using gamescope"
    sudo systemctl stop lightdm
    sudo systemctl start gamescope@tty1
else
    echo "Warning: Did not see an AMD GPU in use, falling back to lightdm only..."
    sudo systemctl restart lightdm
 fi
 
 echo "Done!"
