#!/bin/bash

# default xdg directories
xdg-user-dirs-update

# enable systemctl services
systemctl --user daemon-reload
systemctl --user enable easyeffects
systemctl --user enable polkit
# avahi
sudo systemctl enable avahi-daemon

# update the shell
sudo ln -sfT dash /usr/bin/sh
sudo chsh -s /bin/zsh ${USER}

# syncplay
pip install service_identity
