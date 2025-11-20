#!/bin/bash

# This script will use the Apple Airport framework to gather a quick log for troubleshooting network issues
# Output will be stored in user's home folder with todays date

REPFILE=${USER}-network-report-$( date +%Y-%m-%d_%H-%M )
AIRPORT='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'

# Is this a mac?
if ! uname -a | grep -q 'Darwin'; then
  echo "This isn't a mac. Aborting." 
  exit 1
fi

echo "Generating network report to $REPFILE - This will take around 30-60 seconds and output a file. Please hold."

echo -e "Network report for $(networksetup -getcomputername) on $(date)\n\n" > $REPFILE

echo -e "## Networksetup\n" >> $REPFILE
echo "Hardware Ports" >> $REPFILE
networksetup -listallhardwareports >> $REPFILE
echo "Network Services" >> $REPFILE
networksetup -listallnetworkservices >> $REPFILE
echo "Wi-Fi" >> $REPFILE
networksetup -getinfo "Wi-Fi" >> $REPFILE
echo "Wi-Fi DHCP" >> $REPFILE
ipconfig getpacket en0 >> $REPFILE

if [ -x ${AIRPORT} ]; then
  echo -e "## Wi-Fi Scan\n" >> $REPFILE
  $AIRPORT -s >> $REPFILE
  echo -e "## Wi-Fi Status\n" >> $REPFILE
  $AIRPORT -I >> $REPFILE
else
  echo -e "## Skipping airport run. Command not found." >> $REPFILE
fi

echo -e "## General\n" >> $REPFILE
echo "Interfaces" >> $REPFILE
netstat -i >> $REPFILE
ifconfig >> $REPFILE
echo "DNS" >> $REPFILE
scutil --dns >> $REPFILE
echo "Connections" >> $REPFILE
netstat -finet >> $REPFILE

echo -e "## Routes\n" >> $REPFILE
netstat -r -finet >> $REPFILE

echo -e "## AirPort logs\n" >> $REPFILE
log show --predicate '(processImagePath contains "kernel") && (eventMessage contains "AirPort")' --style syslog --last 2d >> $REPFILE 2>/dev/null

echo "Done."
ls -l $REPFILE