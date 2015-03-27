# steamos-stats.sh

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
 
### How it works

Install using the script file provided here:
`./steamos.stats.sh`

Alternatively, and ideally, clone the repo for easy updates
```
git clone https://github.com/ProfessorKaos64/SteamOS
cd SteamOS
./steamos-stats.sh
```

### Volglperf

Volgperf stats implementation is underway (FPS via this script, for one). When completed, the optional argument to launch your game with FPS stags from Voglperf will be:
```
./steamos-stats.sh <APPID>
```

Where in, <APPID> is the game's ID number from https://steamdb.info/linux/

### Please note

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository
 here
 
### For more information on Voglperf
Please see: https://github.com/ValveSoftware/voglperf
