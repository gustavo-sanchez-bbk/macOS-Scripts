#!/bin/bash

####################################################################################################
#
#   swiftDialog sysdiagnose Progress
#   Original script Dan K Nelson
#   Modified by Gustavo Sanchez
#
#   Purpose: Help your users easily provide detailed logs to the IT Team
#   Optional: Users can upload their logs to Google if a directory is set in JAMF Parameter 5
#
####################################################################################################
#
# HISTORY
#
#
# Version 1.3.1, 17-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Updated `sed` regex (thanks, @Nick Koval!)
#   Updated `updateScriptLog` function (thanks, @tlark!)
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="1.3.1"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserHome=$( dscl . read /Users/"${loggedInUser}" NFSHomeDirectory | awk -F ": " '{print $2}' )
osVersion=$( sw_vers -productVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
dialogApp="/usr/local/bin/dialog"
dialogWelcomeLog=$( mktemp /var/tmp/dialogWelcomeLog.XXX )
dialogProgressLog=$( mktemp /var/tmp/dialogProgressLog.XXX )
dialogCompleteLog=$( mktemp /var/tmp/dialogCompleteLog.XXX )
sysdiagnoseExecutionLog=$( mktemp /var/tmp/sysdiagnoseExecutionLog.XXX )
sysdiagnoseProgressDirectory="/var/tmp/sysdiagnoseProgress"
serialNumber=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
timestamp=$( date '+%Y.%m.%d_%H-%M-%S' )
#Not necessary but if you have a ticket number in Jira you can add it to argument 4 in the JAMF Parameters
ticketNumber="$4"
#If the URL For the Sysdiagnose File Upload Form changes please update it in JAMF under Parameter 5 not here
googleFormLink="$5"
#Where are we going to store the log 
scriptLog="${6:-"/var/tmp/gustavosanchez.sysdiagnose.log"}"
#This is pretty crappy it really cant measure how big the file is going to be but if you want to give it an estimate for SwiftDialog to do the progress bar you can do it in Parameter 7 
estimatedTotalBytes="${7:-"1587046"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${loggedInUser}" || "${loggedInUser}" == "loginwindow" ]]; then
    updateScriptLog "No user logged-in; exiting."
    exit 0
else
    uid=$(id -u "${loggedInUser}")
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Send full System Diagnostics to IT. ${ticketNumber}"
message="### Capture & Upload System-wide logs  \n\nSysdiagnose gathers the following system diagnostic information which is helpful in investigating system performance issues:  \n\n- A spindump of the system  \n- Several seconds of _fs_usage_ ouput  \n- Several seconds of _top_ output  \n- Data about kernel zones  \n- Status of loaded kernel extensions  \n- Resident memory usage of user processes  \n- Recent system logs  \n- A System Profiler report  \n- Recent crash reports  \n- Disk usage information  \n- I/O Kit registry information  \n- Network status  \n\nPlease click **Continue** to proceed."
icon="https://euc1.ics.services.jamfcloud.com/icon/hash_4e65f97612527c93b1b999ca19af8f870e34a85c7c08512816bdddcc882975cd"
overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
button1text="Continue …"
button2text="Quit"
infobuttontext="Help"
infobuttonaction="https://yoururl.com=${infobuttontext}"
welcomeProgressText="Waiting; click Continue to proceed"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSysdiagnoseWelcome="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--overlayicon \"$overlayIcon\" \
--button1text \"$button1text\" \
--button2text \"$button2text\" \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--progress \
--progresstext \"$welcomeProgressText\" \
--moveable \
--titlefont size=22 \
--messagefont size=13 \
--width 700 \
--height 450 \
--commandfile \"$dialogWelcomeLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Progress Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Send full System Diagnostics to IT Team. ${ticketNumber}"
message="IT is now analysing the gremlins in your system …"
icon="https://euc1.ics.services.jamfcloud.com/icon/hash_42692a9a72d97da860c8a1335732c6a35df00e3bf9a2dc15b4d6a65ab2c98e6f"
progressProgressText="Initialising …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Progress Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSysdiagnoseProgress="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress \
--progresstext \"$progressProgressText\" \
--mini \
--moveable \
--commandfile \"$dialogProgressLog\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Send full system diagnostics to IT. ${ticketNumber}"
message="### Log gathering complete  \n\nPlease complete the following steps to provide your logs to  \n IT:  \n1. Click **Upload** to open Google Chrome to upload your logs  \n1. Login with your email address\n1. Add the file listed below from your Desktop  \n\n**sysdiagnose_${serialNumber}_${timestamp}.tar.gz**"
icon="https://euc1.ics.services.jamfcloud.com/icon/hash_1b6cb63d805abe800160aef6d3666e59c26f723f6a45184bfb275dfc56d78db5"
overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
uploadButton1text="Upload"
infobuttontext="IT-LOGS"
infobuttonaction="yoururl=${infobuttontext}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSysdiagnoseUpload="$dialogApp \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--overlayicon \"$overlayIcon\" \
--button1text \"$uploadButton1text\" \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--moveable \
--titlefont size=22 \
--messagefont size=13 \
--width 700 \
--height 450 \
--commandfile \"$dialogCompleteLog\" "



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Script Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# JAMF Display Message (for fallback in case swiftDialog fails to install)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function jamfDisplayMessage() {
    updateScriptLog "Jamf Display Message: ${1}"
    /usr/local/jamf/bin/jamf displayMessage -message "${1}" &
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (thanks, Adam!)
# https://github.com/acodega/dialog-scripts/blob/main/dialogCheckFunction.sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

    updateScriptLog "Dialog not found. Installing..."

    # Create temporary working directory
    workDirectory=$( basename "$0" )
    tempDirectory=$( mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
 
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /

    else

      jamfDisplayMessage "Dialog Team ID verification failed."
      exit 1

    fi
 
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  

  else

    updateScriptLog "swiftDialog version $(dialog --version) found; proceeding..."

  fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Run command as logged-in user (thanks, @scriptingosx!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function runAsUser() {

    updateScriptLog "Run \"$@\" as \"$uid\" … "
    launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# sysdiagnose with progress
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function sysdiagnoseWithProgress() {

    eval "$dialogSysdiagnoseProgress" &

    updateScriptLog "Starting sysdiagnose …"

    echo -ne '\n' | sysdiagnose -u -A sysdiagnose_"${serialNumber}"_"${timestamp}" -f "$sysdiagnoseProgressDirectory" -V / | cat > "$sysdiagnoseExecutionLog" &

    sleep 0.5

    updateProgressDialog "progress: 0"

    while [[ -n $(pgrep "sysdiagnose_helper") ]]; do

        currentTotal=$( du -HAdP "$sysdiagnoseProgressDirectory" | awk '{ print $1 }' )
        updateScriptLog "currentTotal: $currentTotal" # Uncomment to determine value for estimatedTotalBytes
        progressPercentage=$( echo "scale=2 ; ( $currentTotal / $estimatedTotalBytes ) *100 " | bc )
        updateProgressDialog "progress: ${progressPercentage}"

        sysdialogProgressText=$( tail -n1 "$sysdiagnoseExecutionLog" | sed -e 's|Executing container: ||g' -e 's|^[.)]|Processing …|g' -Ee 's|/?.*/[^/]*\.tmp||g' )
        updateProgressDialog "progresstext: ${sysdialogProgressText}"
        updateScriptLog "${sysdialogProgressText}"

    done

    updateProgressDialog "progress: 100"
    updateProgressDialog "progresstext: Complete!"

    sleep 5

    updateProgressDialog "quit: "

    updateScriptLog "Move sysdiagnose file to user's Desktop …"
    mv -v "$sysdiagnoseProgressDirectory"/sysdiagnose_"${serialNumber}"_"${timestamp}".tar.gz "${loggedInUserHome}"/Desktop/

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# sysdiagnose for older OSes
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function sysdiagnoseForOlderOSes() {

    jamfDisplayMessage "Please be patient while logs are gathered …"

    updateScriptLog "Run sysdiagnose for macOS ${osMajorVersion} …"
    echo -ne '\n' | sysdiagnose -u -A sysdiagnose_"${serialNumber}"_"${timestamp}" -f /var/tmp/ -V /

    updateScriptLog "Move output to user's Desktop …"
    mv -v /var/tmp/sysdiagnose_"${serialNumber}"_"${timestamp}".tar.gz "${loggedInUserHome}"/Desktop/

    # I/O Pause
    sleep 3

    updateScriptLog "Inform user …"
    message="Log Gathering Complete for Case No. $ticketNumber

Your computer logs have been saved
to your Desktop as:
sysdiagnose_${serialNumber}_${timestamp}.tar.gz

Please upload the file to IT Support:
$googleFormLink

"
    jamfDisplayMessage "${message}"

    # runAsUser "open -R ${loggedInUserHome}/Desktop/sysdiagnose_${serialNumber}_${timestamp}.tar.gz"
    open -R "${loggedInUserHome}/Desktop/sysdiagnose_${serialNumber}_${timestamp}.tar.gz"

    updateScriptLog "Saved as: sysdiagnose_${serialNumber}_${timestamp}.tar.gz"

    quitScript "0"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    updateScriptLog "Quitting …"
    updateProgressDialog "quit: "

    sleep 1
    updateScriptLog "Exiting …"

    # brutal hack - need to find a better way
    killall tail

    # Remove dialogWelcomeLog
    if [[ -e ${dialogWelcomeLog} ]]; then
        updateScriptLog "Removing ${dialogWelcomeLog} …"
        rm "${dialogWelcomeLog}"
    fi

    # Remove sysdiagnoseExecutionLog
    if [[ -e ${sysdiagnoseExecutionLog} ]]; then
        updateScriptLog "Removing ${sysdiagnoseExecutionLog} …"
        rm "${sysdiagnoseExecutionLog}"
    fi

    # Remove dialogProgressLog
    if [[ -e ${dialogProgressLog} ]]; then
        updateScriptLog "Removing ${dialogProgressLog} …"
        rm "${dialogProgressLog}"
    fi

    # Remove dialogCompleteLog
    if [[ -e ${dialogCompleteLog} ]]; then
        updateScriptLog "Removing ${dialogCompleteLog} …"
        rm "${dialogCompleteLog}"
    fi

    # Remove sysdiagnoseProgressDirectory
    if [[ -d ${sysdiagnoseProgressDirectory} ]]; then
        updateScriptLog "Removing ${sysdiagnoseProgressDirectory} …"
        rm -R "${sysdiagnoseProgressDirectory}"
    fi

    updateScriptLog "Goodbye!"
    exit "${1}"

}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Progress Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateProgressDialog() {
    sleep 0.4
    echo "${1}" >> "${dialogProgressLog}"
}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root; exiting."
  exit 1
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
    updateScriptLog "*** Created log file via script ***"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create sysdiagnose Temporary Directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -d "${sysdiagnoseProgressDirectory}" ]]; then
    mkdir -p "${sysdiagnoseProgressDirectory}"
else
    rm -Rf "${sysdiagnoseProgressDirectory}"
    mkdir -p "${sysdiagnoseProgressDirectory}"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logging preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "User-friendly sysdiagnose (${scriptVersion})"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Operating System
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${osMajorVersion}" -ge 11 ]] ; then
    echo "macOS ${osMajorVersion} installed; proceeding ..."
else
    echo "macOS ${osMajorVersion} installed; executing sysdiagnose sans progress …"
    sysdiagnoseForOlderOSes
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Welcome Dialog …"

eval "$dialogSysdiagnoseWelcome"

welcomeReturncode=$?

case ${welcomeReturncode} in

    0)  ## Process exit code 0 scenario here
        updateScriptLog "${loggedInUser} clicked ${button1text};"
        sysdiagnoseWithProgress
        ;;

    2)  ## Process exit code 2 scenario here
        updateScriptLog "${loggedInUser} clicked ${button2text};"
        quitScript "0"
        ;;

    3)  ## Process exit code 3 scenario here
        updateScriptLog "${loggedInUser} clicked ${infobuttontext};"
        ;;

    4)  ## Process exit code 4 scenario here
        updateScriptLog "${loggedInUser} allowed timer to expire;"
        quitScript "1"
        ;;

    *)  ## Catch all processing
        updateScriptLog "Something else happened; Exit code: ${welcomeReturncode};"
        quitScript "1"
        ;;

esac


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Create Upload Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Create Upload Dialog …"

eval "$dialogSysdiagnoseUpload"

uploadReturncode=$?

case ${uploadReturncode} in

    0)  ## Process exit code 0 scenario here
        updateScriptLog "${loggedInUser} clicked ${uploadButton1text};"

        updateScriptLog "Open upload link … "
        runAsUser open -a /Applications/Google\ Chrome.app/ $googleFormLink

        sleep 30

        updateScriptLog "Reveal sysdiagnose in Finder … "
        runAsUser open -R ${loggedInUserHome}/Desktop/sysdiagnose_${serialNumber}_${timestamp}.tar.gz

        quitScript "0"

        ;;

    2)  ## Process exit code 2 scenario here
        updateScriptLog "${loggedInUser} clicked ${button2text};"
        quitScript "0"
        ;;

    3)  ## Process exit code 3 scenario here
        updateScriptLog "${loggedInUser} clicked ${infobuttontext};"
        ;;

    4)  ## Process exit code 4 scenario here
        updateScriptLog "${loggedInUser} allowed timer to expire;"
        quitScript "1"
        ;;

    *)  ## Catch all processing
        updateScriptLog "Something else happened; Exit code: ${uploadReturncode};"
        quitScript "1"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

quitScript "0"