#!/bin/bash
#Script to configure Cisco Jabber 8.6.7 & 9.6 for deployment.

#If Lion or Mountain Lion, add the company WORKGROUP to the path
majorOSVersion=`sw_vers | awk '/ProductVersion/ { print $2 }' | awk -F"." '{ print $2 }'`
if [ $majorOSVersion -ge 7 ]
then
	adDomain=DOMAIN/
else
	adDomain=""
fi

#Ensure AD is functioning--try a test lookup
dscl localhost -read /Active\ Directory/${adDomain}All\ Domains/Users/$USER > /dev/null
adLookupExitStatus=$?
#Did the test lookup work?
if [ $adLookupExitStatus != 0 ]
then
	echo Failed AD test lookup
	exit 1
fi

#Runtime variables
jabberMajorVersion=`defaults read /Applications/Cisco\ Jabber.app/Contents/Info CFBundleShortVersionString | awk -F"." '{ print $1 }'`
configFile="$HOME/Library/Application Support/Cisco/Unified Communications/Jabber/CSF/Config/jabberLocalConfig.xml"
emailAddress=`dscl localhost -read "/Active Directory/${adDomain}All Domains/Users/$USER" mail | awk -F: '{print $3}' | tr -d ' '`

#Check to see if we need to delete Jabber preferences
DOMAINSetup=`defaults read com.cisco.Jabber DOMAINSetup 2>&1`
if [ ! "$DOMAINSetup" = 1 ]
then
	#Jabber preferences have never been touched by this script.  Kill Jabber and delete the
	#preferences so we have a clean slate

	#Quit Cisco Jabber if running
	if [ `ps -axwww | grep "Cisco Jabber" | grep -v grep | wc -l` -gt "0" ]
	then
		killall "Cisco Jabber"
	fi

	#Delete Jabber preferences
	if [ ! -f ~/Library/Preferences/com.cisco.Jabber.plist ]
	then
		# In testing found that some domain keys weren't being written on first login.
		# Assuming a race condition put in a touch to create the file and a sleep to 
		# wait for whatever was blocking the writes to pass
		touch ~/Library/Preferences/com.cisco.Jabber.plist
		sleep 10
	else
		defaults delete com.cisco.Jabber
	fi
	rm -rf ~/Library/Application\ Support/Cisco

fi


# Accept license agreement - Prevents initial EULA from appearing for each user
# Commented out to not have to upkeep the script to allow each new version to skip the EULA.
#defaults write com.cisco.Jabber ARXEndUserAcceptedVersionsKey -array -string "Version 8.6.7 (20127)" "Version 9.6.0 (173114)"

# Skips the first run assistant
defaults write com.cisco.Jabber ARXIsFirstLaunchKey -bool False

# Sets the mode to use WebEx Unified Presence 
defaults write com.cisco.Jabber ARXMode -integer 0

# Sets the SSO login site information
defaults write com.cisco.Jabber ARXSsoOrgKey -string "DOMAIN.com"

# Turns off automatic software update search
defaults write com.cisco.Jabber SUEnableAutomaticChecks -bool False

# Turns off auto-starting video on calls
defaults write ARXUserDefaultsStartCallsWithVideoKey -bool False

#Jabber client version 9.x has some extra configurations to make it user friendlier
# If computer has client version 8.x this file is not used
if [ ! -f "$configFile" ]
then
    # Make the config file path
    mkdir -p "`dirname "$configFile"`"

    # Write out the config information to the config file
    echo '<?xml version="1.0" encoding="UTF-8"?>' >> "$configFile"
    echo '<Jabber>' >> "$configFile"
    echo -n ' <userConfig name="LastLoadedUserProfile" value="' >> "$configFile"
    echo -n $emailAddress >> "$configFile"
    echo '"/>' >> "$configFile"
    echo -n ' <userConfig name="suggestedUsername" value="' >> "$configFile"
    echo -n $emailAddress >> "$configFile"
    echo '"/>' >> "$configFile"
    echo '</Jabber>' >> "$configFile"
fi        

#Write out a marker so the preferences are not completely deleted again
#Using an int because it would be easier to revise if this script needs to be revised
defaults write com.cisco.Jabber DOMAINSetup -int 1

# Restart cfprefsd not needed now that defaults is being used to manipulate plists
#killall cfprefsd

exit 0
