### Disclaimer

Please take time to ready the following!

#### General overview

Usage of these scripts is at your own risk! If you are at all concerned about the safety of your SteamOS installation, please have a recent or base root partition backup ready! This is typically captured when SteamOS is first installed. If you wish to update it, and feel ok doing so, please do so now.

If any of this is foreign, or greek to you, it may be best to not proceed. However, a proper root backup should be fine if you do harm to your system. Please be advised that the root partition recovery will not touch the `/home` user partition. Any files contained within `/home` will be preserved. Besides the root parition, please take care to backup any files you are concerned about.

####Notes regarding apt-pinning / apt-preferences 
Apt-pinning is implemented in the `add-debian-repos.sh` script to give Steam and SteamOS release types highest priority. Beneath this, Debian and Debian-Backports are given a much lower priority. For details on current pin levels, please reference [these](https://github.com/ProfessorKaos64/SteamOS-Tools/blob/master/add-debian-repos.sh#L111) lines of code. If the line number is off, the section is titled "# Create and add required text to preferences file". 

Apt-pin preferences are subject to change. Ideally, the testing branch will be tested properly before hand, and package policy checked with `apt-cache policy` as well. Please submit any suggestions or corrections anyone feels should be made as a pull request.

####Conclusion

I will not be responsible for damage done to your SteamOS installation. Please heed these warnings very well.
Enter file contents here
