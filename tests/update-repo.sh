#!/bin/bash
# Description: test repo update for one repo only
update_repo() {
    sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/$1.list" \
		-o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
}

update_repo steamos-tools

