#!/bin/sh

# Change session type
dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.Accounts /org/freedesktop/Accounts/User1001 org.freedesktop.Accounts.User.SetXSession string:gnome

# Kill steam in order to quit current session
killall -9 steam
