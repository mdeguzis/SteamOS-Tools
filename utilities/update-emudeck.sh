#!/bin/bash
# Requres X11 fowarding
#
# To get X11 forwarding working over SSH, you'll need three things in place:
# 
#     Your client must be set up to forward X11.
#     Your server must be set up to allow X11 forwarding.
#     Your server must be able to set up X11 authentication.
# 
#     On your server, make sure /etc/ssh/sshd_config contains:
# 
#     X11Forwarding yes
#     X11DisplayOffset 10
# 
#     You may need to SIGHUP sshd so it picks up these changes.
# 
#     cat /var/run/sshd.pid | xargs kill -1
# 
#     On your server, make sure you have xauth installed.
# 
#     belden@skretting:~$ which xauth
#     /usr/bin/xauth
# 
#     If you do not have xauth installed, you will run into the empty DISPLAY environment variable problem.
# 
#     On your client, connect to your server. Be certain to tell ssh to allow X11 forwarding. I prefer
# 
#     belden@skretting:~$ ssh -X blyman@the-server
# 

# Flatpaks
bash ${HOME}/.config/EmuDeck/backend/tools/flatpakupdate/flatpakupdate.sh

# Binaries
bash ${HOME}/.config/EmuDeck/backend/tools/binupdate/binupdate.sh
