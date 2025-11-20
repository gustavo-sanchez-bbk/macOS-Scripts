#!/bin/zsh

# This script is intended to be used only on a mac m1
# Copyright Gustavo Sanchez

#This script will install JAVA for Mac M1's

curl https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_macos-aarch64_bin.tar.gz --output /tmp/openjdk-17.0.1_macos-aarch64_bin.tar.gz
sudo mv /tmp/openjdk-17.0.1_macos-aarch64_bin.tar.gz /Library/Java/JavaVirtualMachines/
cd /Library/Java/JavaVirtualMachines/
sudo tar -xzf openjdk-17.0.1_macos-aarch64_bin.tar.gz
sudo rm openjdk-17.0.1_macos-aarch64_bin.tar.gz