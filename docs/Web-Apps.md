# Web Apps

**Summary**
===
Be advised this is a work in progress. Netflix will launch via `google-chrome-stable` and connect to netflix in `--kiosk` mode. A default users config directory for Google chrome is copied over, so that the "unexpected shutdown" message is avoided (since for now, you must use the center Xbox 360 controller / PS3 controller to exit.). I am currently working on creating some snap in script code to add Hulu, Youtube, and so forth. I need to gather the images and test those sites first though.

**Cleanly exiting Chrome** 
===
This is a bit tricky for now. I play on mapping something to an Xbox 360 controller. In the meantime, `CTRL+SHIFT+W` will close the current window.

**Custom Shortcuts**
===
The extension [Shortcut Manager](https://chrome.google.com/webstore/detail/shortcut-manager/mgjjeipcdnnjhgodgjpfkffcejoljijf) will allow you to add your own custom shortcuts. Open any `/usr/bin/NAME-Launcher.sh` file and remove the `--kiosk` temporarily. Launch the web app and add this extension. Details for the exetension are in the link. This is beneficial if your air mouse or remote does not have a CTRL key like mine.

**Extensions that provide controller support*
===
Please keep in mind that the majority, if not all, of these extensions are only tested with an official Xbox 360 controller. Please see the extension page documentation for more.

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
The script, on initial launch, the script will display relevant warnings and also ask you to add the Debian repository(s) if not detected first. You will need these added for installing Google Chrome, so please add them if advised to do so.  

**NEW**
===
You will be allowed to select a few "preset" web urls for the web app. You can choose custom to enter your own.

Note:  
One nice device to have, until I can figure out some gamepad input to control the arrow keys, is to buy a nice Air Mouse like [this device](http://www.amazon.com/Aerb-Wireless-Keyboard-Multifunctional-3-Gsensor/dp/B00K768DHY/ref=sr_1_1?ie=UTF8&qid=1432255815&sr=8-1&keywords=air+mouse) on Amazon. I personally have this device and can attest it works great on SteamOS / Plex / Kodi, as well as general purpose tasks.


**Adding the Netflix launcher to Chrome**
===
Return to Steam Big Picture Mode and click on your library. Choose the "+" sign and "Add non-Steam game to my library." Locate "Netflix" and hit ok/A on your controller.

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
