#!/bin/sh

# Uninstall FortiClient.sh

# This script will completely uninstall FortiClient and all supporting components
# Remove comments from lines 16-21 to completely nuke it from orbit - leave them if reinstalling which solves a majority of issues

# Gustavo Sanchez 2022

pkill FortiClientAgent
launchctl unload /Library/LaunchDaemons/com.fortinet*

rm -Rfv /Applications/FortiClient.app
rm -Rfv /Applications/FortiClientUninstaller.app
rm -Rfv /Library/Application\ Support/Fortinet
rm -Rfv /Library/Internet\ Plug-Ins/FortiClient_SSLVPN_Plugin.bundle


rm -Rfv '/Library/LaunchDaemons/com.fortinet.forticlient.vpn.plist'
rm -Rfv '/Library/LaunchDaemons/com.fortinet.forticlient.wf.plist'
rm -Rfv '/Library/LaunchDaemons/com.fortinet.forticlient.fmon.plist'
rm -Rfv '/Library/LaunchDaemons/com.fortinet.forticlient.epctrl.plist'
rm -Rfv '/Library/LaunchDaemons/com.fortinet.forticlient.appfw.plist'
rm -Rfv '/Library/LaunchDaemons/com.fortinet.forticlient.fssoagent_launchdaemon.plist'

#Continue with the below
localAccounts=$(dscl . list /Users UniqueID | awk '$2 > 500 { print $1 }')

for user in $localAccounts ;
do
  rm -Rfv /Users/"$user"/Library/Application\ Support/Fortinet/
done