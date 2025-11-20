#!/bin/bash

#quick and dirty experimental script to remove old keychain entries, create a new location and connect to a new WiFi

#The need for this script grew when our company changed names and so did the SSID

#This script assumes that the WiFi adapter is set up as en0 (usually is unless the Mac is connected with Ethernet adapter priority) 
#Gustavo Sanchez 

#Delete the old keychain entries first, change your_old_ssid for the actual value and guest network if you have one. 
#Copy paste from line 14 if you wish to add more entries to delete

security delete-generic-password -D "AirPort network password" your_old_ssid /Library/Keychains/System.keychain
security delete-generic-password -D "AirPort network password" your_old_ssid_guest /Library/Keychains/System.keychain


#Let me turn it off and then on again :) 

networksetup -setairportpower en0 off 

# Wait 5 seconds 
sleep 5

#Turn it on again
networksetup -setairportpower en0 on 

 
# Enter the name of the new wifi SSID
SSID="YourNewSSID"

# Create a new network location called "New Location" but feel free to change New Location to any value you want
networksetup -createlocation "New-Location" populate

# Switch to the new location
networksetup -switchtolocation "New-Location" populate

# Connect to the Wi-Fi network
networksetup -setairportnetwork en0 $SSID

# Check if the connection was successful
connected_ssid=$(networksetup -getairportnetwork en0 | awk -F': ' '{print $2}')

if [ "$connected_ssid" == "$SSID" ]; then
    echo "Connected to $SSID"
else
    echo "Failed to connect to $SSID"
fi