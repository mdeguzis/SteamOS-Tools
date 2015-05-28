# Web Apps

**Summary**
===
Be advised this is a work in progress. Netflix will launch via `google-chrome-stable` and connect to netflix in `--kiosk` mode. A default users config directory for Google chrome is copied over, so that the "unexpected shutdown" message is avoided (since for now, you must use the center Xbox 360 controller / PS3 controller to exit.). I am currently working on creating some snap in script code to add Hulu, Youtube, and so forth. I need to gather the images and test those sites first though.

**Controls** 
===
This assumes you have enabled mouse control for the web app in question for supported gamepads listed during the script.

####Gamepad 
* Left Joystick (Up/Down/Left/Right) - Move mouse cursor
* Right Joystick (Up/Down/Left/Right) - Scroll wheel
* A/LB - Mouse left button
* B/RB - Mouse right button
* Dpad (left/right) - backward or forward page navigation
* Back button - Exit web app

####Keyoard
* `CTRL+W` will close the current tab (recommended).
* `CTRL+SHIFT+W` will close the current window.

**Custom Shortcuts**
===
The extension [Shortcut Manager](https://chrome.google.com/webstore/detail/shortcut-manager/mgjjeipcdnnjhgodgjpfkffcejoljijf) will allow you to add your own custom shortcuts. Open any `/usr/bin/NAME-Launcher.sh` file and remove the `--kiosk` temporarily. Launch the web app and add this extension. Details for the exetension are in the link. This is beneficial if your air mouse or remote does not have a CTRL key like mine.

**Extensions that provide controller support**
===
Please keep in mind that the majority, if not all, of these extensions are only tested with an official Xbox 360 controller. Please see the extension page documentation for more. These extensions also may not work as intended.
* [Plex Web](https://chrome.google.com/webstore/detail/gamepad-for-plex-web/haoeganpancihdffhohfeeeejpbahlld)
* [Netflix](https://chrome.google.com/webstore/detail/netflix-controller-suppor/flakmgbknagcohphpoogebajjbmlmngh)

**Pre-requisites**
===
* Some Linux knowledge
* Access to desktop mode of SteamOS (Settings > Interface)
* Password for the `desktop` user set. (Fire up a terminal window and enter `passwd` to gain access to sudo

**To install**
===
    sudo apt-get install git
    git clone https://github.com/ProfessorKaos64/SteamOS-Tools
    cd SteamOS-Tools
    ./desktop-software.sh install webapp

**The Process**
===
The script, on initial launch, the script will display relevant warnings and also ask you to add the Debian repository(s) if not detected first. You will need these added for installing Google Chrome, so please add them if advised to do so. You will be allowed to select a few "preset" web urls for the web app. You can choose custom to enter your own.

Note:  
One nice device to have, until I can figure out some gamepad input to control the arrow keys, is to buy a nice Air Mouse like [this device](http://www.amazon.com/Aerb-Wireless-Keyboard-Multifunctional-3-Gsensor/dp/B00K768DHY/ref=sr_1_1?ie=UTF8&qid=1432255815&sr=8-1&keywords=air+mouse) on Amazon. I personally have this device and can attest it works great on SteamOS / Plex / Kodi, as well as general purpose tasks.


**Adding the Netflix launcher to Chrome**
===
Return to Steam Big Picture Mode and click on your library. Choose the "+" sign and "Add non-Steam game to my library." Locate "Netflix" and hit ok/A on your controller.

**Additional artowork / Steam banner images**
===
If you wish to add images / banners for your own custom URLs or web apps you add, you can checkout these resources:

* [/r/Steamgrid](http://www.reddit.com/r/steamgrid)
* The ['extra-artwork'](https://github.com/ProfessorKaos64/SteamOS-Tools/tree/master/cfgs/extra-artwork) folder within this GitHub repository. Extra artwork / banners can be added upon reques.
* [Google image search](https://www.google.com/search?q=steam&biw=1366&bih=644&tbm=isch&source=lnt&tbs=isz:ex,iszw:460,iszh:215) with the 460x215 image dimension specification.


**Troubleshooting** 
===
There are rare occasions where antimicro does not release its process when you are done with a web app. If cases such as this, use the center button on your gamepad to select the "Exit Game" option from the Steam overlay. If extreme cases, a reboot will do the trick if all else fails.

**Summary**
===
If you have any questions, comments, or criticisms, please submit an issues ticket on GitHub.

**Please, do yourself a favor and read the disclaimer file, and readme docs under the docs/ folder in main git folder**

**Thanks**
===
Thanks to Shark, Ryochan7, and Dubigrasu of the Steam Universe forums for the launcher help.

**Updates**
===
1. Changed install command to support modular method that supports multiple websites.
2. Added ability to choose a few preset web urls and also to specify your own.
