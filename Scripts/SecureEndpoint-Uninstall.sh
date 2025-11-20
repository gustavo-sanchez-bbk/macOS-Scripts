#!/bin/bash

#This script will completely remove Cisco AMP (Secure Endpoint) and all its components from Mac, including System / Kernel Extensions

# Function to check macOS version
function get_macos_version() {
    sw_vers -productVersion | awk -F '.' '{print $1"."$2}'
}

# Unload services
/bin/launchctl unload /Library/LaunchAgents/com.cisco.amp.agent.plist

# Check if the menulet is still running
echo "If the menulet is still running, click on it and select 'Quit Secure Endpoint connector'."

sudo /bin/launchctl unload /Library/LaunchDaemons/com.cisco.amp.daemon.plist
sudo /bin/launchctl list com.cisco.amp.daemon

sudo /bin/launchctl unload /Library/LaunchDaemons/com.cisco.amp.updater.plist
sudo /bin/launchctl list com.cisco.amp.updater

# Get macOS version
macos_version=$(get_macos_version)

# Commands for macOS versions 10.15 and older
#if [[ "$macos_version" == "10.15" || "$macos_version" < "10.15" ]]; then
 #   sudo /sbin/kextunload -b com.cisco.amp.fileop
#    sudo /sbin/kextunload -b com.cisco.amp.nke
#    sudo /usr/sbin/kextstat -l | grep com.cisco.amp
#    sudo rm -rf "/Applications/Cisco Secure Endpoints"
  #  sudo rm -rf /Library/Extensions/ampfileop.kext
  #  sudo rm -rf /Library/Extensions/ampnetworkflow.kext
#fi

# Commands for macOS versions 11 and newer
if [[ "$macos_version" == "11" || "$macos_version" > "11" ]]; then
    /Applications/Cisco\ Secure\ Endpoint/Secure\ Endpoint\ Service.app/Contents/MacOS/Secure\ Endpoint\ Service deactivate endpoint_security
    /Applications/Cisco\ Secure\ Endpoint/Secure\ Endpoint\ Service.app/Contents/MacOS/Secure\ Endpoint\ Service deactivate content_filter
    systemextensionsctl list | grep com.cisco.endpoint.svc
fi

# Remove files and directories common to all versions
sudo rm -rf "/Library/Application Support/Cisco/Secure Endpoint"
sudo rm -rf /opt/cisco/amp/
sudo rm -f /Library/Logs/Cisco/amp*
sudo rm -f /var/run/ampdaemon.pid
sudo rm -f /Library/LaunchAgents/com.cisco.amp.agent.plist
sudo rm -f /Library/LaunchDaemons/com.cisco.amp.daemon.plist
sudo rm -f /Library/LaunchDaemons/com.cisco.amp.updater.plist

# Forget packages
for pkg in com.cisco.amp.agent com.cisco.amp.daemon com.cisco.amp.kextsigned com.cisco.amp.kextunsigned com.cisco.amp.support com.sourcefire.amp.agent com.sourcefire.amp.daemon com.sourcefire.amp.kextsigned com.sourcefire.amp.kextunsigned com.sourcefire.amp.support; do
    sudo pkgutil --forget "$pkg"
done

# Remove user-specific files
for user_dir in /Users/*; do
    rm -f "$user_dir/Library/Preferences/SourceFire-Inc.FireAMP-Mac.plist"
    rm -f "$user_dir/Library/Preferences/Cisco-Inc.AMP-for-Endpoints-Connector.plist"
done

echo "Uninstall procedure completed."
