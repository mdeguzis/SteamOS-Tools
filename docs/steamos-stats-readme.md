<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [steamos-stats.sh](#steamos-statssh)
    - [About](#about)
    - [What currently works](#what-currently-works)
    - [Usage](#usage)
    - [Additional arguments](#additional-arguments)
    - [Volglperf](#volglperf)
        - [Be Warned:](#be-warned)
    - [Please note](#please-note)
    - [For more information on Voglperf](#for-more-information-on-voglperf)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# steamos-stats.sh

### About
This script monitors various statistics of your SteamOS installation over SSH. The utility script will detect and auto-install any missing binaries or software. For the time being, only Nvidia cards are supported (due to me not owning an AMD card). Inviduals are welcome to submit working AMD commands for the GPU, or request me add them for testing.

**Screenshot**  
You can view what the current version looks like [here](https://plus.google.com/u/0/+MikeyD64?tab=mX#+MikeyD64/posts/L1vKuPt6xJp?pid=6130569276589664466&oid=110956822431822104338).

### What currently works
* Auto installation of required tools
  * ssh
  * git
  * voglperf
  * sysstat (sar, free, iostat)
  * nvidia-smi
* CPU temperatures stats
* CPU load stats
* GPU temperature stats
* GPU load sats
 
### Usage

Install and run the utility using the script file provided here:
```
./steamos.stats.sh -driver [gpu-driver]
```

Alternatively, and ideally, clone the repo for easy updates
```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
./steamos-stats.sh -driver [gpu-driver]
```
Substitute [gpu-driver] with the chipset you are currently using. The current choices are `intel`, `fglrx`, and `nvidia`. Please note that `nvidia` is currently only supported (testing for others underway). If you do not specify a graphics driver, the script assumes you are using an Nvidia graphics card.

### Additional arguments

steamos-stats also accepts the following additional arugments (voglperf testing is underway)
```
./steamos.stats.sh -gpu [chipset] -gameid [gameid]
```
Substitute [gameid] with the numerical gameid for the game you wish to launch with voglperf stats. This function is currently under developement!

### Volglperf

Volgperf stats implementation is underway (FPS via this script, for one). Please be aware, it seems 32 bit games have [issues](https://github.com/ValveSoftware/voglperf/issues/7#issuecomment-44964590) with Voglperf. Users have reported that linking LibGL, then modifying the cmake file to build the 32 bit version of voglperf (in addition to the default build), worked for them. For the time being, you can still toggle an FPS overlay with `steamcompmgr`, using an Xbox 360 gamepad (LB+RB+Guide), thanks to the auto-installed VaporOS 2 controller bindings.

```
sudo ln -s /usr/lib/i386-linux-gnu/mesa/libGL.so.1 /usr/lib/i386-linux-gnu/libGL.so
```

Then build voglperf 32-bit:

```
cd voglperf
make voglperf32
```

#####Be Warned:
Copying libGL.so to /usr/lib/i386-linux-gnu will cause dota2 and other source games to segfault. For this reason alone, vogelperf will not be enabled in `steamos-stats` until this is resolved or a fix can be found. 

To undo this, unlink the file:
```
rm /usr/lib/i386-linux-gnu/libGL.*
```

### Please note

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository.
 
### For more information on Voglperf
Please see: https://github.com/ValveSoftware/voglperf
