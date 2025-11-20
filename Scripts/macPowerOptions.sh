#!/bin/zsh

# This script is intended to be used only on a mac mini since it will set it to never sleep and recover after pw failure
# Copyright Gustavo Sanchez 2022

# Set the power options
sudo pmset sleep 0 displaysleep 0 powernap 0 autorestart 1