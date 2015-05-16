# ssh-rom-transfer-readme.md

### About
This script transfers ROMs / requested files over your local network using the `scp` Linux application.
 
### Usage

You can run the utility using the script file provided here:
```
./ssh-rom-transfer
```

Alternatively, and ideally, clone the repo for easy updates
```
git clone https://github.com/ProfessorKaos64/SteamOS-Tools
cd SteamOS-Tools
./ssh-rom-transfer
```

#####Prompts
You will be asked the following:

* Your remote username from your remote computer
* The hostname of the remote computer
* The remote folder you wish to view and transfer from
* A folder/file selection to choose from

After choosing a folder, you will be prompted for the remote computer's user password. Once transferred, the file(s)/folder(s)
will have their owners and permissions corrected for you.

### Please note

Submit all questions, comments, and pull requests to the issues and pull requests area of this git repository.
