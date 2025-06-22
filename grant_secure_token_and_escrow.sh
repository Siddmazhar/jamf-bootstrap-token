#!/bin/bash

# Author: siddmazhar
# Last Updated: 23-June-2025
# Purpose: Grant Secure Token + Escrow Bootstrap Token using hardcoded admin

# ----------------------------------------------------------
# 🖼️ Dialog Branding Icon
# ----------------------------------------------------------
selfServiceBrandIcon="/Users/$3/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"
brandIcon="$fileVaultIcon"
[[ -f "$selfServiceBrandIcon" ]] && brandIcon="$selfServiceBrandIcon"

# ----------------------------------------------------------
# 👤 Get logged-in user
# ----------------------------------------------------------
userName=$(ls -l /dev/console | awk '{ print $3 }')
if [[ "$userName" == "root" || -z "$userName" ]]; then
    echo "❌ No user session detected."
    exit 1
fi

# ----------------------------------------------------------
# 🔐 Check if user already has Secure Token
# ----------------------------------------------------------
tokenStatus=$(sysadminctl -secureTokenStatus "$userName" 2>&1)

if [[ "$tokenStatus" == *"ENABLED"* ]]; then
    echo "✅ $userName already has Secure Token."

    # Check and escrow bootstrap token
    btStatus=$(profiles status -type bootstraptoken 2>&1)
    if [[ "$btStatus" == *"escrowed to server: YES"* ]]; then
        echo "✅ Bootstrap Token already escrowed."
    else
        echo "📦 Escrowing Bootstrap Token..."
        profiles install -type bootstraptoken
    fi

    exit 0
fi

# ----------------------------------------------------------
# 🔒 If no Secure Token, prompt for passwords and grant
# ----------------------------------------------------------
echo "⚠️ $userName does NOT have Secure Token. Prompting for credentials..."

adminUser="admin"

# Prompt for admin password
adminPassword=$(osascript -e "display dialog \"Enter password for admin user: $adminUser\" default answer \"\" with title \"Admin Authentication\" buttons {\"Cancel\", \"OK\"} default button 2 with hidden answer with icon POSIX file \"$brandIcon\"" \
                          -e "text returned of result")
[[ -z "$adminPassword" ]] && echo "❌ Admin password not entered." && exit 1

# Prompt for user password
userPassword=$(osascript -e "display dialog \"Enter your login password to enable Secure Token\" default answer \"\" with title \"User Authentication\" buttons {\"Cancel\", \"OK\"} default button 2 with hidden answer with icon POSIX file \"$brandIcon\"" \
                         -e "text returned of result")
[[ -z "$userPassword" ]] && echo "❌ User password not entered." && exit 1

# Grant Secure Token
echo "Granting Secure Token to $userName..."

grantOutput=$(sysadminctl -secureTokenOn "$userName" -password "$userPassword" -adminUser "$adminUser" -adminPassword "$adminPassword" 2>&1)
echo "$grantOutput"

if [[ "$grantOutput" == *"Done"* || "$grantOutput" == *"secure token was granted"* ]]; then
    echo "✅ Secure Token granted successfully."

    # Escrow Bootstrap Token
    echo "📦 Escrowing Bootstrap Token..."
    profiles install -type bootstraptoken -user "$adminUser" -pass "$adminPassword"

    # Final check
    btCheck=$(profiles status -type bootstraptoken)
    if [[ "$btCheck" == *"escrowed to server: YES"* ]]; then
        echo "✅ Bootstrap Token escrowed successfully."
    else
        echo "❌ Bootstrap Token escrow failed."
    fi
else
    osascript -e "display dialog \"Secure Token grant failed. Check passwords or try again.\" with title \"Grant Failed\" buttons {\"OK\"} default button 1 with icon POSIX file \"$brandIcon\""
    echo "❌ Secure Token grant failed. Output: $grantOutput"
    exit 1
fi
