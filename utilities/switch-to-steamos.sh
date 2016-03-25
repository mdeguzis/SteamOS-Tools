#!/bin/sh

# Change session type
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User1001 org.freedesktop.Accounts.User.SetXSession string:steamos

# Kill steam instance so gnome-session-quit will work properly
killall -9 steam
sleep 2

# Log steam user out of Gnome. End session.
gnome-session-quit --no-prompt
