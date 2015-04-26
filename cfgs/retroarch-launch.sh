#!/bin/bash

# these short commands will swap the configuration file basedon the current user
current_cfg=$(grep "Exec=retroarch" $HOME/.config/retroarch/retroarch.cfg)
new_cfg="retroarch --config $HOME/.config/retroarch/retroarch.cfg"

# perform swap
sudo sed -i 's|$current_cfgd|$new_cfg|g' "$HOME/.config/retroarch/retroarch.cfg"
