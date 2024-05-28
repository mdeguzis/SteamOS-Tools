#!/bin/bash

set -e

echo "[INFO] Configuring SSH X forwarding"

# On your server, make sure /etc/ssh/sshd_config contains:
if ! grep -q "X11Forwarding yes" "/etc/ssh/sshd_config"; then
	sudo bash -c 'echo "X11Forwarding yes" >> /etc/ssh/sshd_config'
fi
if ! grep -q "X11DisplayOffset 10" "/etc/ssh/sshd_config"; then
	sudo bash -c 'echo "X11DisplayOffset 10" >> /etc/ssh/sshd_config'
fi

sudo bash -c 'cat /var/run/sshd.pid | xargs kill -1'

if [[ ! -f "/usr/bin/xauth" ]]; then
	echo "[INFO] xauth missing, please run install-software.sh from utilties/"
fi

echo "[INFO] Done!"
exit 0
