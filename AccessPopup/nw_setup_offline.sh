#!/bin/bash
#version 0.1
#date 31 May 2025
#Script for use by installconfig.sh by RaspberryConnect.com as part of AccessPopup 
#Adds a Network Manager profile from the supplied ssid and password.
#This script will be run in the background from the web app when the user chooses to add a new Wifi network
#from another wifi device as the connection will be closed with the webserver before the setup is compete.


ssid=""
pwd=""

usage() {
  echo "Usage: $0 -s <ssid> -p <password>"
  exit 1
}

while getopts "s:p:" opt; do
  case $opt in
    s)
      ssid="$OPTARG"
      ;;
    p)
      pwd="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$ssid" ] || [ -z "$pwd" ]; then
  exit
fi

echo "Attempting to connect to the new Wifi Network"
if [ ! -z "$ssid" ] && [ "${#pwd}" -ge 8 ] ;then
	#create new profile with details
	nmcli device wifi connect "$ssid" password "$pwd" >/dev/null 2>&1
	stat=$?
	if [ $stat -eq 0 ] ; then
		echo "Profile Created"
		echo "$ssid"
		pw="$( nmcli -t -s con show $ssid | grep 'wireless-security.psk:' )"
		echo ${pw:29}
		nmcli connection reload
	else
		echo "The connection to $ssid Failed."
		echo "The new profile has not been saved"
		nmcli connection delete "$ssid" >/dev/null 2>&1
		nmcli connection reload >/dev/null 2>&1
	fi
else
	echo "Password is less than 8 characters, unable to continue"
fi
