#!/bin/bash

# Script: Grant Secure Token & Escrow Bootstrap Token
# Use: Deploy via Jamf Self Service or Policy to enable secure token and escrow bootstrap token.
# Requirements: Admin credentials with Secure Token, macOS 11 or later
# Author: [siddmazhar]
# Last Updated: [22-June-25]

# ----------------------------------------------------------
# 🖼️ Set icon for dialogs – use branded Self Service image if available
# ----------------------------------------------------------
selfServiceBrandIcon="/Users/$3/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"
if [[ -f $selfServiceBrandIcon ]]; then
    brandIcon="$selfServiceBrandIcon"
else
    brandIcon="$fileVaultIcon"
fi

# ----------------------------------------------------------
# 🔐 Check if the logged-in user has a Secure Token
# ----------------------------------------------------------
result="UNDEFINED"
MissingSecureTokenCheck() {
    userName=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')
    if [[ -n "${userName}" && "${userName}" != "root" ]]; then
        token_status=$(/usr/sbin/sysadminctl -secureTokenStatus "${userName}" 2>&1 | /usr/bin/grep -ic enabled)
        if [[ "$token_status" -eq 0 ]]; then
            result="NO"
        elif [[ "$token_status" -eq 1 ]]; then
            result="YES"
        fi
    fi
}
MissingSecureTokenCheck

# ----------------------------------------------------------
# 🛠️ If Secure Token is missing – prompt admin to grant it
# ----------------------------------------------------------
if [[ $result = "NO" ]]; then

    # Get list of admin users
    adminUsers=$(dscl . read /Groups/admin GroupMembership | cut -d " " -f 2-)

    for EachUser in $adminUsers; do
        TokenValue=$(sysadminctl -secureTokenStatus $EachUser 2>&1)
        if [[ $TokenValue == *"ENABLED"* ]]; then
            SecureTokenUsers+=($EachUser)
        fi
    done

    if [[ -z "${SecureTokenUsers[@]}" ]]; then
        osascript -e "display dialog \"There are no Secure Token admin users on this device.\" with title \"Grant Secure Token\" buttons {\"OK\"} default button 1 with icon POSIX file \"$brandIcon\""
        exit 0
    fi

    adminUser=$(osascript -e "set userList to the paragraphs of \"$(printf '%s\n' "${SecureTokenUsers[@]}")\""
                          -e 'return choose from list userList with prompt "Select an admin user you know the password for:"')

    adminPassword=$(osascript -e "display dialog \"Enter password for '$adminUser'\" default answer \"\" with title \"Grant Secure Token\" buttons {\"Cancel\", \"OK\"} default button 2 with icon POSIX file \"$brandIcon\" with hidden answer
set input to text returned of the result
return input")

    if [ "$?" != "0" ]; then
        echo "User cancelled."
        exit 0
    fi

    passCheck=$(dscl /Local/Default -authonly "${adminUser}" "${adminPassword}")
    if [ "$passCheck" != "" ]; then
        echo "Password verification failed."
        osascript -e "display dialog \"Password incorrect. Please try again.\" with title \"Grant Secure Token\" buttons {\"OK\"} default button 1 with icon POSIX file \"$brandIcon\""
        exit 1
    fi

    echo "Prompting current user for their password..."
    userPassword=$(osascript -e "display dialog \"Enter your password to receive a Secure Token\" default answer \"\" with title \"Grant Secure Token\" buttons {\"Cancel\", \"OK\"} default button 2 with icon POSIX file \"$brandIcon\" with hidden answer
set input to text returned of the result
return input")

    if [ "$?" != "0" ]; then
        echo "User cancelled."
        exit 0
    fi

    echo "Granting Secure Token to $userName..."
    sysadminctl -secureTokenOn "$userName" -password "$userPassword" -adminUser "$adminUser" -adminPassword "$adminPassword"

    echo "Checking for existing Bootstrap Token..."
    bootstrap=$(profiles status -type bootstraptoken)
    if [[ $bootstrap == *"escrowed to server: YES"* ]]; then
        echo "Bootstrap Token already escrowed with Jamf Pro."
    else
        echo "Escrowing Bootstrap Token now..."
        sudo profiles install -type bootstraptoken -user "$adminUser" -pass "$adminPassword"
    fi

elif [[ $result = "YES" ]]; then
    echo "User already has Secure Token. No action needed."
    osascript -e "display dialog \"$userName already has a Secure Token. No action needed.\" with title \"Secure Token\" buttons {\"OK\"} default button 1 with icon POSIX file \"$brandIcon\""
else
    echo "Could not determine Secure Token status."
    osascript -e "display dialog \"Could not determine Secure Token status.\" with title \"Secure Token\" buttons {\"OK\"} default button 1 with icon POSIX file \"$brandIcon\""
    exit 1
fi
