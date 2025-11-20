#!/bin/bash

# Cisco AMP / Secure Endpoint Installer. Pulls directly from the console.
# Script by Gustavo Sanchez 

if [ "$EUID" -ne 0 ]
  then echo "$0 must be run with root privileges."
  exit 1
fi

# Check your GUID for downloads.
# Be aware that there are specific GUID for different groups, Protect, Audit, Triage, etc. 
# Looks like CISCO changes these values everytime you renew the product - so make sure you have the correct GUID
GUID=XXXXX-XXXX-XXXX-XXX-XXXXXXXXX

ciscoAMPPath="/Applications/Cisco AMP/AMP for Endpoints Connector.app/Contents/Info.plist"
# EU URL here, with GUID in path.
redirectingURL="https://console.eu.amp.cisco.com/install_packages/$GUID/download?product=MacProduct"
localInstallerVolume="/Volumes/ampmac_connector"
localInstallerPackage="ciscoampmac_connector.pkg"
tmpFolder="/private/tmp/cisco-amp-installer"

checkAndGetURLs()
{
  dmgURL=$(curl --head "$redirectingURL" | grep -i "Location:" | awk '{print $2}')
  if [[ -z $dmgURL ]]
    then
      echo "Unable to retrieve DMG url. Exiting..."
      exit 1
  fi

  echo "DMG URL found. Continuing..."

  dmgFile=$(basename "$(echo $dmgURL | awk -F '?' '{print $1}')")
  dmgName=$(echo "${dmgFile%.*}")
}

downloadInstaller()
{
  mkdir -p "$tmpFolder"
  echo "Downloading $dmgFile..."
  /usr/bin/curl -L -s "$redirectingURL" -o "$tmpFolder"/"$dmgFile" --location-trusted
}

installPackage()
{
  if [[ -e "$tmpFolder"/"$dmgFile" ]]; then
    hdiutil attach "$tmpFolder"/"$dmgFile" -nobrowse -quiet
    if [[ -e "$localInstallerVolume"/"$localInstallerPackage" ]]; then
      echo "$localInstallerPackage found. Installing..."
      /usr/sbin/installer -pkg "$localInstallerVolume"/"$localInstallerPackage" -target /
      if [[ $(echo $?) -gt 0  ]]; then
        echo "Installer encountered error. Exiting..."
        hdiutil detach "$localInstallerVolume"
        rm -f "$tmpFolder"/"$dmgFile"
        exit 1
      else
        echo "Successfully installed "$localInstallerPackage". Exiting..."
        hdiutil detach "$localInstallerVolume"
        rm -f "$tmpFolder"/"$dmgFile"
        exit 0
      fi
    fi
  else
    echo "$dmgFile failed to download. Exiting..."
    exit 1
  fi
}

echo "Getting URLs"
checkAndGetURLs
echo "dmgFile = $dmgFile"
echo "dmgName = $dmgName"
echo

echo "Downloading installer dmg file."
downloadInstaller
echo 

echo "Installing package"
installPackage
