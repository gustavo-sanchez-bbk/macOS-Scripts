#!/bin/bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	     									    	  #
#	This script will remove all versions of NoMAD/NoMAD Login.	  #
#	Before running this script unscope the Configuration Profile deploying the	  #
#	.plist. If NoMAD is installed it will log out the user and reboot.  #				
#	     									    	  #							   
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	     									    	  #
#	25th July 2022  Gustavo Sanchez   					   	  #
#	     									    	  #	 									   
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                                 
# Removed Python here to use scutil cause it won't work with newer versions of macOS - Hashtag it just works, yes

consoleuser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ {print $3}')

echo "Current user is $consoleuser"

# get the UID for the user
uid=`/usr/bin/id -u "$consoleuser"`

###########################################
######	Checking and Removing NoMAD  ######
###########################################

#Creates variables for NoMAD Locations
echo "Checking for Nomad Menu"
nloc="/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist"
nlocusers="/Users/$consoleuser/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist"
nagent="/Library/LaunchAgents/com.trusourcelabs.NoMAD.agent.plist"
napp="/Applications/NoMAD.app"
nplist="/Library/Managed\ Preferences/com.trusourcelabs.NoMAD.plist"
nshare="/Library/Managed\ Preferences/menu.nomad.shares.plist"
nprefplist="/Library/Preferences/com.trusourcelabs.NoMAD.plist"
nprefshare="/Library/Preferences/menu.nomad.shares.plist"
nuserplist="/Users/$consoleuser/Library/Preferences/com.trusourcelabs.NoMAD.plist"
nusershare="/Users/$consoleuser/Library/Preferences/menu.nomad.shares.plist"
nusermanagedpref="/Library/Managed\ Preferences/$consoleuser/com.trusourcelabs.NoMAD.plist"
nusermanagedshares="/Library/Managed\ Preferences/$consoleuser/menu.nomad.shares.plist"


#Check for NoMAD
if [ -f "$nloc" ] || [ -d "$napp" ] || [ -f "$nplist" ] || [ -f "$nshare" ] || [ -f "$nprefplist" ] || [ -f "$nprefshare" ] || [ -f "$nuserplist" ] || [ -f "$nusershare" ] || [ -f "$nagent" ] || [ -f "$nusermanagedpref" ] || [ -f "$nusermanagedshares" ] || [ -f "$nlocusers" ];
then
	echo "NoMAD Menu was found"
	
#Removes NoMAD LaunchAgent if found
	if [ -f "$nloc" ]; 
	then
		/bin/launchctl bootout gui/"$uid" "$nloc"
		/bin/rm "$nloc"
		echo "NoMAD LaunchAgent has been removed from the Computer"
	else
		echo "NoMAD LaunchAgent not found"
	fi

#Removes Users Launch Agent if found	
	if [ -f "$nlocusers" ];
	then
		/bin/rm "$nlocusers"
		echo "Removed the NoMAD Users Launch Agent"
	else
		echo "NoMAD User Launch Agent not found"
	fi

#Removes NoMAD Agent if found
	if [ -f "$nagent" ]; 
	then
		/bin/launchctl bootout gui/"$uid" "$nloc"
		/bin/rm "$nagent"
		echo "NoMAD Agent has been removed from the Computer"
	else
		echo "NoMAD Agent not found"
	fi
	
#Removes NoMAD Application if found
	if [ -d "$napp" ]; 
	then
		/bin/rm -rf "$napp"
		echo "Removed NoMAD Application"
	else
		echo "NoMAD Application not found"
	fi
#Removes NoMAD .plist if found
	if [ -f "$nplist" ];
	then
		/bin/rm "$nplist"
		echo "Removed the NoMAD .plist"
	else
		echo "NoMAD .plist not found"
	fi
#Removes NoMAD Share .plist if found	
	if [ -f "$nshare" ];
	then
		/bin/rm "$nshare"
		echo "Removed the NoMAD share .plist"
	else
		echo "NoMAD Share .plist not found"
	fi
#Removes Preferences NoMAD .plist if found	
	if [ -f "$nprefplist" ];
	then
		/bin/rm "$nprefplist"
		echo "Removed the User Preferences NoMAD .plist"
	else
		echo "User Preferences NoMAD .plist not found"
	fi
#Removes Preferences NoMAD Share .plist if found	
	if [ -f "$nprefshare" ];
	then
		/bin/rm "$nprefshare"
		echo "Removed the Preferences NoMAD Share .plist"
	else
		echo "Preferences NoMAD Share .plist not found"
	fi
#Removes User Preferences NoMAD .plist if found	
	if [ -f "$nuserplist" ];
	then
		/bin/rm "$nuserplist"
		echo "Removed the User Preferences NoMAD .plist"
	else
		echo "User Preferences NoMAD .plist not found"
	fi
#Removes User Preferences NoMAD Share if found	
	if [ -f "$nusershare" ];
	then
		/bin/rm "$nusershare"
		echo "Removed the User Preferences NoMAD Share"
	else
		echo "User Preferences NoMAD Share not found"
	fi
#Removes NoMAD User Managed Preferences
	if [ -f "$nusermanagedpref" ];
	then
		/bin/rm "$nusermanagedpref"
		echo "Removed the NoMAD share .plist"
	else
		echo "NoMAD User Managed Preferences not found"
	fi
#Removes NoMAD User Managed Shares
	if [ -f "$nusermanagedshares" ];
	then
		/bin/rm "$nusermanagedshares"
		echo "Removed the NoMAD share .plist"
	else
		echo "NoMAD User Managed Shares not found"
	fi

#NoMAD is not found on the computer
else
	echo "NoMAD not found on the Computer"


echo "Completed. I will reboot your Mac. Toss a coin to your IT Team"
fi
