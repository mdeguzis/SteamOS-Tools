#!/bin/bash

~/homebrew/plugins/decky-cloud-save/rclone copy --filter-from ~/homebrew/settings/decky-cloud-save/sync_paths_filter.txt / backend:decky-cloud-save --copy-links --verbose --verbose
