#!/bin/bash

# ONLY Intended if you get this message below, common on
# systems with conflicting system libraries (e.g. ChromeOS chroot).

# See: https://wiki.archlinux.org/index.php/Steam/Troubleshooting

find ~/.steam/root/ \( -name "libgcc_s.so*" -o -name "libstdc++.so*" \
-o -name "libxcb.so*" -o -name "libgpg-error.so*" \) -print -delete

# This must be done after Steam updates, as it will likely break again.
