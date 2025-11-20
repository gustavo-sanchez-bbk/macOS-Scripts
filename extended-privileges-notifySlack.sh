#!/bin/bash


#This script is made by Santa so we keep a track of whos been bad and whos been good. A lump of coal for those who renew privileges when not needed 

#Note - this script cannot run by itself. It is used in conjunction with our Privileges configuration profile for Extended Testers in JAMF (Group ID XXX - Privileges - Extended Testing)
#This is separate from the initial group, though we may need to be merging this once we move all ACSO to Privileges 2.X as some features are not supported in 1.X 


#Variables 
privilegesPath="/#"
SLACK_WEBHOOK_URL="#"  

#Construct the message with OSA script
buttonPressed=$(/usr/bin/osascript << EOF
tell application "System Events"
    try
        activate
        display dialog "Your administrator privileges are about to expire. Do you want to renew them?" with \
        icon (get first file of folder "${privilegesPath%%/}/Contents/Resources" whose name extension is "icns") \
        buttons {"Revoke", "Renew"} default button 2 giving up after 60
        return (button returned of the result)
    end try
end tell
EOF
)

#Gather the user details. Useful when pitchforking. 
username=$(stat -f%Su /dev/console)
machine_name=$(scutil --get ComputerName)

#If user still needs rights then invoke the Privileges CLI to stay as root
if [[ "$buttonPressed" = "Renew" ]]; then
    # Renew admin rights
    "${privilegesPath%%/}/Contents/MacOS/PrivilegesCLI" -a

    # Send Slack message
    payload=$(cat <<EOF
{
  "text": ":white_check_mark: *Admin Rights were renewed (long duration)*\n*User:* $username\n*Machine:* $machine_name\n"
}
EOF
    )

    curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"

#Otherwise if user doesn't need them lets revoke. 
elif [[ "$buttonPressed" = "Revoke" ]]; then
    
    "${privilegesPath%%/}/Contents/MacOS/PrivilegesCLI" -r

    #Construct the message for slack in neat JSON
    payload=$(cat <<EOF
{
  "text": ":no_entry: *Admin Rights Revoked*\n*User:* $username\n*Machine:* $machine_name"
}
EOF
    )

    curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
fi

exit 0
