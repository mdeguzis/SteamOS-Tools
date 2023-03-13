
## Summary

You can change the target to something else, but the script is made to sync screenshots to Google Photos using [rclone](https://rclone.org/docs/) 
(which will be automatically installed). I tried a lot of rclone options, but none for the current version seem to support flattening the screenshots 
(no directories created in Google Photos, just add screenshots), so there is hacky workaround that symlinks to the files for sync and watches/mutates 
when new screenshots are added. If you just sync the screenshots folder of choice, you'll end up with a different Google Photos directory per folder within...

The default timer for the symlinker watcher is 60 seconds, but you can adjust this yourself. Logs are printed to the following locations:

```
/tmp/sync-screenshots-linker.log
/tmp/sync-screenshots.log
```

Setting up your gphoto target: https://foosel.net/til/how-to-automatically-sync-screenshots-from-the-steamdeck-to-google-photos/

## Installation:
```
./sync-screenshots.sh install
```

Run once (the systemd unit files will run this automatically):
```
./sync-screenshots.sh run
```

