#!/bin/bash
# This is some secure program that uses security.

sleep 35
until pgrep -lf 'rungameid'; do
sleep 25
done
while pgrep -lf 'steamapps'; do
sleep 10
done
killall feh &
returntosteam.sh
