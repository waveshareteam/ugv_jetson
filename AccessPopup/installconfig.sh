#!/bin/bash
ver="1.01: 15th April 2026"
#Copyright Graeme Richards - RaspberryConnect.com
#Released under the GPL3 Licence (https://www.gnu.org/licenses/gpl-3.0.en.html)

#Installation and configuration script for the AccessPopup script, that switches between
#a Wifi Access Point or connects to a Wifi Network as required

osver=($(cat /etc/issue))
cpath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/"
wdev0="wlan0"

script_path="/usr/local/bin/"
scriptname="accesspopup"
conf_path="/etc/"
conf_file="accesspopup.conf"
web_path="/usr/local/bin/acpu_web"
webfile_acpu="/usr/local/bin/acpu_web/acpu_get_std.py"
webfile_app="/usr/local/bin/acpu_web/pages/app.py"
active_ap="n"
active=""
nw_profile=()

#service
sysd_path="/etc/systemd/system/"
service=AccessPopup.service
timer=AccessPopup.timer
webback=acpu_web.service
webappsock=acpu_web_app.socket
webapp=acpu_web_app.service
sudoers_file="/etc/sudoers.d/acpu"

#Text Format
YEL='\e[38;2;255;255;0m'
GRE='\e[38;0;255;0;0m'
DEF='\e[m'
BOL='\e[1m'


nm="${osver[2]}"
if [ -z "${nm//[0-9]}" ] && [ "${osver[0]}" != 'Arch' ] ;then
	if [ "${osver[2]}" -eq 11 ]; then #OS Bullseye
		echo "OS Version" "${osver[2]}"
		echo "This script only works on PIOS 11 Bullseye if Network Manager has been enabled"
		echo "in raspi-config."
		echo "For other distributions Network Manager is required."
		read -p "Press a key to continue"
	elif [ "${osver[2]}" -lt 11 ];then #older OS
		echo "The version of PiOS is too old for the $scriptname script"
		echo "Version 11 'Bullseye' with Network Manager enabled in raspi-config is the minimum requirement"
		echo "A version for your OS is available at RaspberryConnect.com using dhcpcd instead."
		echo "www.raspberryconnect.com/projects/65-raspberrypi-hotspot-accesspoints/183-raspberry-pi-automatic-hotspot-and-static-hotspot-installer"
		read -p "Press any key to continue"
		exit 1
	fi
fi

readlink /sbin/init | grep systemd >/dev/null 2>&1
if [ "$?" -gt 0 ] ;then
	echo "systemd is not available."
	echo "This script uses SystemD services. Unable to continue."
	read -p "Press a key to continue"
	exit 1
fi


systemctl is-active --quiet NetworkManager.service
if [ $? -ne 0 ];then
	echo "NetworkManager is not available."
	echo "This script requires NetworkManager but it is not active."
	echo "Unable to continue"
	read -p "Press a key to continue"
	exit 1
fi

add_service()
{
if ! systemctl list-unit-files --all | grep $service ;then
cat > "${sysd_path}${service}" <<EOF
[Unit]
Description=Automatically generates an Access Point when a valid SSID is not in range
After=multi-user.target
Requires=network-online.target
[Service]
Type=simple
ExecStart=${script_path}${scriptname}
[Install]
WantedBy=multi-user.target
EOF
systemctl unmask $service
fi
}

add_timer_service()
{
if ! systemctl list-unit-files --all | grep $timer ;then
cat > "${sysd_path}${timer}" <<EOF
[Unit]
Description=${scriptname} network checks every 2 mins

[Timer]
OnBootSec=0min
OnCalendar=*:0/2

[Install]
WantedBy=timers.target
EOF
systemctl unmask $timer
systemctl enable $timer >/dev/null 2>&1
systemctl daemon-reload
fi
}

add_web_back_service()
{
if ! systemctl list-unit-files --all | grep $webback ;then
	cat > "${sysd_path}${webback}" <<EOF
[Unit]
Description=AccessPopup Webpage background actions script
After=network.target

[Service]
Type=simple

# Run as the restricted user
User=acpu
Group=acpu

# Run Backend Script
ExecStart=/usr/local/bin/acpu_web/venv/bin/python3 /usr/local/bin/acpu_web/acpu_get_std.py

# Restart on failure
Restart=on-failure
RestartSec=5
TimeoutStopSec=10
KillMode=control-group

#Working dir
WorkingDirectory=/usr/local/bin

#Security
ProtectSystem=full
ReadWritePaths=/etc/accesspopup.conf
ReadOnlyPaths=/usr/local/bin/acpu_web

[Install]
WantedBy=multi-user.target

EOF
systemctl daemon-reload
systemctl enable $webback >/dev/null 2>&1
fi
}

add_web_app_service()
{
if ! systemctl list-unit-files --all | grep $webapp ;then
	cat > "${sysd_path}${webapp}" <<EOF
[Unit]
Description=ACPU Web Server for AccessPopup
Requires=acpu_web_app.socket
After=network.target
Wants=acpu_web.service
After=acpu_web.service

[Service]
User=acpu
Group=acpu

WorkingDirectory=/usr/local/bin/acpu_web/pages
ExecStart=/usr/local/bin/acpu_web/venv/bin/uvicorn app:app --fd 3

Restart=on-failure
RestartSec=5

Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF
fi
}


add_web_app_socket()
{
if ! systemctl list-unit-files --all | grep $webappsock ;then
	cat > "${sysd_path}${webappsock}" <<EOF
[Unit]
Description=Socket for AccessPopup Webpage actions script

[Socket]
ListenStream=0.0.0.0:8052

[Install]
WantedBy=sockets.target
EOF
systemctl daemon-reload
systemctl enable $webappsock
fi
}



webcheck()
{
if [ ! -f "$script_path$scriptname" ]; then
	echo "The Accesspopup script is not installed. Please install AccessPopup (Option 1) and then try again."
	echo "Press enter to continue"
	read x
	menu
fi
 echo "Web Interface Setup"
 #does systemctl acpu_web_app exist - no - install websetup
if ! systemctl list-unit-files --all | grep "$webback" || [ ! -d "$web_path" ] >/dev/null 2>&1; then
	echo "The Web Interface not currently Installed, Installing files"
	install_web
elif systemctl -all list-unit-files "$webback" | grep "$webback enabled" >/dev/null 2>&1;then
	echo "Disabling the Web Interface"
	disable_web
	echo "The Web app has been disabled"
	read -p "press any key to continue"
else
	echo "Enabling the Web Interface"
	enable_web
	echo "The Web app has been enabled"
	read -p "press any key to continue"
fi
}

chk_cmd() {
	local cmds=("$@")
    set -uo pipefail

    for cmd_str in "${cmds[@]}"; do
        if ! bash -c "$cmd_str" ; then
			echo "There is an issue while installing the webfiles."
			echo "Unable to complete the web setup. Removing any installed files."
            uninstall_web
            return 1
        fi
    done
}

install_web()
{
	local pm="$(packageman)"
	local depend=("python3-venv" "python3-pip")

	if [ ! -f "$script_path$scriptname" ]; then
		echo "The Accesspopup script is not installed. Please install AccessPopup (Option 1) and then try again."
		read -p "Press any key to continue"
		menu
	fi
	py="$(python3 --version)"
	if [ $? -gt 0 ] ;then
		echo "Python3 is required for the web page feature but it is unavailable"
		echo "Unable to install the webpage feature"
		read -p "Press any key to continue"
		menu
	else
		if [ "$pm" = 'apt' ];then
			for i in "${depend[@]}"; do
				dpkg -s "$i" >/dev/null 2>&1
				if [ $? -gt 0 ]; then
					apt install "$i"
					if [ $? -gt 0 ] ;then
						echo "Unable to install dependency ${depend[@]}"
						echo "The Webpage features cannot be installed."
						echo "This may be because there is no internet access or the package is unavailable"
						read -p "Press any key to continue"
						menu
					fi
				fi
			done
		fi
	fi


	install_list=(
		"mkdir \"$web_path\""
		"cp -rf \"${cpath}acpu_web/.\" \"$web_path\""
		"python3 -m venv \"$web_path/venv\""
		"\"$web_path/venv/bin/pip\" install -r \"$web_path/requirements.txt\" && \"$web_path/venv/bin/pip\" check"
		"cp \"${cpath}acpu_web/acpu_get_std.py\" \"$web_path\""
		"chmod 755 \"$web_path/acpu_get_std.py\""
		"chmod 755 \"$web_path/pages/app.py\""
	)

	if [ ! -d "$web_path" ] ; then #web_path doesn't exist
		chk_cmd "${install_list[@]}"
		if [ $? = 0 ];then
			if add_permissions ;then
				echo "Add services"
				add_web_back_service #add background actions service
				add_web_app_service #add web app service
				add_web_app_socket #add web app socket
				systemctl daemon-reload
				systemctl start $webback
				systemctl start $webappsock
			else
				echo "Unable to set sudoers permissions"
				echo "Unable to complete the setup of the Web files."
				echo "The Web feature files will be removed"
				read -p "Press any key to continue"
				uninstall_web
				menu
			fi
		else
			menu
		fi
	else #web_path exists, check other files
		echo "script Path is $cpath"
		echo "Checking that the required files are in place"
		if comm -23 <(cd ${cpath}acpu_web/ && find . -type f | sort) <(cd $web_path && find . -type f | sort) | grep . ; then
			echo "Some files from ${cpath}acpu_web/ are missing in $web_path"
			echo "re-installing files"

			cp "${cpath}acpu_get_std.py" "$web_path"
			chmod +x "${web_path}/acpu_get_std.py"
			add_web_back_service #add actions service
			add_web_app_service #add web app service
			add_web_app_socket #add web app socket
			systemctl daemon-reload
			systemctl start $webback
			systemctl start $webappsock
		fi
	fi
	echo ""
	echo -e $YEL"The web app has been installed."
	echo "In a web browser use http://localhost:8052 on this device or"
	echo -e "from another device use the http://ip_address:8052 or the http://hostname:8052"
	echo -e "From devices connected to the Access Point use http://192.168.50.5:8052" $DEF
	read -p "Press any key to continue"
}

disable_web()
{
#check if services are running, and disable them
if systemctl -all list-unit-files "$webback" | grep "${webback} enabled" >/dev/null 2>&1 ;then
	echo "The Web App is currently enabled, stopping and disabling Web Services"
	systemctl stop "$webappsock" >/dev/null 2>&1
	systemctl stop "$webapp" >/dev/null 2>&1
	systemctl stop "$webback" >/dev/null 2>&1
	systemctl disable "$webappsock" >/dev/null 2>&1
	systemctl disable "$webback" >/dev/null 2>&1
	systemctl daemon-reload >/dev/null 2>&1

fi
}

enable_web()
{
#enable web services if they exist
w="$(systemctl -all list-unit-files "$webback")"
if [ $? -gt 0 ] ;then #not installed
	echo "Web files do not exist. The Web app will be installed."
	install_web
elif systemctl -all list-unit-files "$webback" | grep "${webback} disabled" >/dev/null 2>&1 ;then
	echo "Enabeling AccessPopup Web app"
	systemctl enable "$webback" >/dev/null 2>&1
	systemctl enable "$webappsock" >/dev/null 2>&1
	systemctl start "$webback" >/dev/null 2>&1
	systemctl start "$webappsock" >/dev/null 2>&1
fi
}

#Function what is the current active wifi
active_wifi()
{
	act="$(nmcli -t -f TYPE,NAME,DEVICE,TYPE con show --active | grep "$wdev0")" #List of active devices
	act="$(awk 1 ORS=':' <(echo "$act"))" #Replaces LF with : Delimeter
	readarray -d ':' -t active_name < <(printf "%s" "$act") #Change to array output
	if [ ! -z "$active_name" ]; then
		active="${active_name[1]}"
	else
		active=""
	fi
}

is_active_ap()
{
active_ap="n"
if [ ! -z "$active" ] ; then
	mode="$(nmcli con show "$active" | grep 'wireless.mode')"
	readarray -d ':' -t mode < <(printf "%s" "$mode")
	if [ ! -z mode ]; then
		mode2="$(echo "${mode[1]}" | sed 's/[[:blank:]]//g')"
		if [ "$mode2" = "ap" ]; then
			active_ap="y"
		fi
	fi
fi
}

switch()
{
	active_wifi
	is_active_ap
	if [ "$active_ap" = "y" ]; then #Yes active profile is an AP
		echo "Attempting to switch to WiFi Network"
		"${script_path}${scriptname}"
	else
		echo "Switching to AP"
		"${script_path}${scriptname}" "-a"
	fi
}

packageman()
{
if command -v "apt" >/dev/null 2>&1; then
	echo "apt"
elif command -v "dnf" >/dev/null 2>&1; then
	echo "dnf"
elif command -v "pacman" >/dev/null 2>&1; then
	echo "pacman"
else
	return 1
fi
}

install_general()
{
local pm="$(packageman)"
local depend1=("iw" "dnsmasq-base") #Debian
local depend2=("iw" "dnsmasq") #Fedora, Arch
local hostapd_avail=0

if [ -f "./$scriptname" ]; then
	#Debian
	if [ "$pm" = 'apt' ];then
		for i in "${depend1[@]}"; do
			dpkg -s "$i" >/dev/null 2>&1
			if [ $? -gt 0 ]; then
				apt install "$i"
				if [ $? -gt 0 ] ;then
					echo "Unable to install dependency ${depend1[@]}"
					echo "AccessPopup cannot be installed."
					echo "This may be because there is no internet access or the package is unavailable"
					echo "press enter to continue"
					read xit
					menu
				fi
			fi
		done
		dpkg -s hostapd >/dev/null 2>&1
		if [ $? -eq 0 ];then
			hostapd_avail=1
		fi

	fi
	#Fedora
	if [ "$pm" = 'dnf' ];then
		for i in "${depend2[@]}"; do
			if [ $? -gt 0 ]; then
				dnf install "$i"
				if [ $? -gt 0 ] ;then
					echo "Unable to install dependency ${depend2[@]}"
					echo "AccessPopup cannot be installed."
					echo " This may be because there is no internet access or the package is unavailable"
					echo "press enter to continue"
					read xit
					menu
				fi
			fi
		done
		rpm -qi hostapd >/dev/null 2>&1
		if [ $? -eq 0 ];then
			hostapd_avail=1
		fi

	fi
	#Arch
	if [ "$pm" = 'pacman' ];then
		for i in "${depend2[@]}" ; do
			pacman -Qi "$i" >/dev/null 2>&1
			if [ $? -gt 0 ]; then
				pacman -S "$i"
				if [ $? -gt 0 ] ;then
					echo "Unable to install dependency ${depend2[@]}"
					echo "AccessPopup cannot be installed."
					echo " This may be because there is no internet access or the package is unavailable"
					echo "press enter to continue"
					read xit
					menu
				fi
			fi
		done
		pacman -Qi hostapd >/dev/null 2>&1
		if [ $? -eq 0 ];then
			hostapd_avail=1
		fi

	fi
	systemctl is-enabled dnsmasq >/dev/null 2>&1
	if [ $? -eq 0 ] ;then
		echo "dnsmasq is enabled at start up. It will be disabled."
		systemctl disable dnsmasq >/dev/null 2>&1
		systemctl stop dnsmasq >/dev/null 2>&1
	fi

	if [ "$hostapd_avail" -eq 1 ] ;then
		systemctl is-enabled hostapd >/dev/null 2>&1
		if [ $? -eq 0 ] ;then
			echo "Hostapd is installed and enabled."
			echo "Hostapd is not required and will conflict with a NetworkManager accesspoint"
			echo "Please disable or uninstall hostapd if it is not required and try again"
			echo "To disable hostapd use: sudo systemctl disable hostapd"
			exit 1
		else
			echo "Hostapd is installed but not enabled at start up"
			echo "Hostapd is not required and will conflict with a NetworkManager Access Point"
			echo "If there is any issues connecting with the AccessPoint used in AccessPopup then"
			echo "please uninstall hostapd"
			read -p "Press a key to continue"
		fi
	fi

	if [ $wdev0 != "wlan0" ] ;then
		echo "Updating $conf_file with device name $wdev0"
		sed -i "s/wdev0=.*/wdev0='$wdev0'/" "./$conf_file"
	fi


	cp "./$scriptname" "$script_path"
	cp "./$conf_file" "${conf_path}${conf_file}"
	chmod +x "${script_path}${scriptname}"
	add_service
	add_timer_service
	systemctl start $timer
	"${script_path}${scriptname}"
	chmod +x ./nw_setup_offline.sh
	echo -e "\nAccessPopup has been installed"
	read -p "Press any key to continue"
else
	echo "$scriptname is not in the same location as this installer"
	echo "Unable to continue"
	read -p "press any key to continue"
	menu
fi

}

ap_ssid_change()
{
	if [ -f "${conf_path}${conf_file}" ] >/dev/null 2>&1; then
		echo -e "The current ssid and password for the AP are:"
		ss="$( grep -F 'ap_ssid=' $conf_path$conf_file )"
		echo "SSID:${ss:8}"
		pw="$( grep -F 'ap_pw=' ${conf_path}${conf_file} )"
		echo "Password:${pw:6}"
		prof="$( grep -F 'ap_profile_name=' ${script_path}${scriptname} )"
		echo -e $YEL"Enter the new SSID"$DEF
		echo "Press enter to keep the existing SSID"
		read newss
		if [ ! -z "$newss" ]; then
			sed -i "s/ap_ssid=.*/ap_ssid='$newss'/" "${conf_path}${conf_file}"
		fi
		echo -e $YEL"Enter the new Password"$DEF
		echo "The password must be at least 8 characters"
		echo "Press enter to keep the existing Password"
		read newpw
		if [ ! -z "Snewpw" ] && [ ${#newpw} -ge 8 ]; then
			sed -i "s/ap_pw=.*/ap_pw='$newpw'/" "${conf_path}${conf_file}"
		fi
		echo "The Access Points SSID and Password are:"
		ss="$( grep -F 'ap_ssid=' ${conf_path}${conf_file} )"
		pw="$( grep -F 'ap_pw=' ${conf_path}${conf_file} )"
		echo "SSID:${ss:8}"
		echo "Password: ${pw:6}"
		#remove AP profile
		pro="$(nmcli -t -f NAME con show | grep ${prof:17:-1} )"
		if [ ! -z "$pro" ]; then
			nmcli con delete "$pro" >/dev/null 2>&1
			nmcli con reload
		fi
		read -p "press any key to continue"
	else
		echo "$conf_file is not available."
		echo "Please install the AccessPopup script first"
		read -p "press any key to continue"
		menu
	fi
}

ap_change_ip()
{
	#IP network address
	if [ -f "${conf_path}${conf_file}" ] >/dev/null 2>&1; then
		echo "The current AccessPopup IP address is:"
		ip="$( grep -F 'ap_ip=' ${conf_path}${conf_file} )"
		echo -e $YEL"${ip:7:-1}"$DEF
		r="0"
		until [[ "$r" -eq 3 ]]; do
			echo -e "\nChoose the IP Network. The first two parts of the IP address"
			echo "1) 192.168."
			echo "2) 10.0."
			echo "3) Exit"
			read r
			if [ ! -z "$r" ]; then
				case $r in
					1)
						ipnw="192.168."
						r=3
						;;
					2)
						ipnw="10.0."
						r=3
						;;
					3)
						ipnw="0" ; clear; menu ;;
					*)
						echo -e $BOL$YEL"\nInvalid option"$DEF
						;;
					esac
				fi
			done
		#IP host 1 values
		if [[ ! $ipnw = "0" ]]; then
			r2=0
			until [ "$r2" -eq 1 ]; do
				echo -e "\n${BOL}Enter the first host number $ipnw###${DEF}"
				echo "Valid numbers are between 0 and 255"
				echo -e "The number must not match the third position of other networks connected to your"
				echo "device starting with $ipnw, such as an Ethernet ip or second wifi network ip"
				echo "Enter 999 to Cancel"
				read iph1
				if [[ $iph1 =~ ^[0-9]+$ ]]; then
					if [ $iph1 = 999 ]; then
						iph1=""
						r2=1
					elif [ $iph1 -lt 0 ] || [ $iph1 -gt 255 ]; then
						echo -e ${BOL}"\nNot a valid number\n"${DEF}
						r2=0
					else
						#Valid entry, next menu
						r2=1
					fi
				else
					r2=0
				fi
			done
		fi
		#IP host 2 values
		if [ ! -z $ipnw ] && [ ! -z $iph1 ]; then
			r3=0
			until [ "$r3" -eq 1 ]; do
				echo -e ${BOL}"\nEnter the second host number $ipnw$iph1.###"${DEF}
				echo "Valid numbers are between 0 and 253"
				echo "Enter 999 to Cancel"
				read iph2
				if [[ $iph2 =~ ^[0-9]+$ ]]; then
					if [ $iph2 -eq 999 ]; then
						iph2=""
						r3=1
					elif [ $iph2 -lt 0 ] || [ $iph2 -gt 253 ]; then
						echo -e ${BOL}"\nNot a valid number\n"${DEF}
						r3=0
					else
						#Valid entry, next menu
						r3=1
					fi
				else
					r3=0
				fi
			done
		fi
		if [ ! -z "$r3" ];then
			echo -e ${BOL}"\nUpdating the Access Point to IP address to:"${DEF}
			ipa="$ipnw$iph1.$iph2"
			ipg="$ipnw$iph1.254"
			echo -e ${YEL}$ipa${DEF}
			sed -i "s/ap_ip=.*/ap_ip='$ipa\\/24'/" "${conf_path}${conf_file}"
			sed -i "s/ap_gate=.*/ap_gate='$ipg'/" "${conf_path}${conf_file}"

			prof="$( grep -F 'ap_profile_name=' ${script_path}${scriptname} )"
			pro="$(nmcli -t -f NAME con show | grep ${prof:17:-1} )"
			if [ ! -z "$pro" ]; then
				nmcli con delete "$pro" >/dev/null 2>&1
			fi
			echo -e "\ncomplete"
			read -p "press any key to continue"
		fi
	else
		echo "$conf_file is not available."
		echo "Please install the AccessPopup script first. Option 1"
		read -p "press any key to continue"
		menu
	fi
}


saved_profiles()
{
ap_profile=()
nw_profile=()
n="$(nmcli -t -f TYPE,NAME,ACTIVE con show)" #Capture Output
n="$(awk 1 ORS=':' <(echo "$n"))" #Replaces LF with : Delimeter
readarray -d ':' -t profiles < <(printf "%s" "$n") #Change to array output
if [ ! -z profiles ]; then
	for (( c=0; c<=${#profiles[@]}; c+=3 )) #array of profiles
	do
		if [ ! -z "${profiles[$c+1]}" ] ; then
			mode="$(nmcli con show "${profiles[$c+1]}" | grep 'wireless.mode')" #show mode infrastructure, AP
			readarray -d ':' -t mode < <(printf "%s" "$mode")
			mode2="$(echo "${mode[1]}" | sed 's/[[:blank:]]//g')"
			if [ "$mode2" = "infrastructure" ]; then
				nw_profile+=("${profiles[$c+1]}")
			fi
		fi
	done
fi
}

reactivate()
{
	if [ ! -f "$script_path$scriptname" ]; then
		echo "The Accesspopup script is not installed. Please install AccessPopup (Option 1) and then try again."
		echo "Press enter to continue"
		read x
		menu
	fi
	echo -e $YEL$BOL"Wifi re-activation options"$DEF
	echo "When this device has it's wifi disabled, AccessPopup will re-activate it"
	echo "and then connect to a wifi network or generate an Access Point"
	echo "This will happen every 2 minutes."
	echo "If Wifi enable/disable is managed elsewhere on the system"
	echo "then wifi re-activation can be disabled in AccessPopup."
	re="$( grep -F 're_enable_wifi=' $conf_path$conf_file )"
	echo ""
	echo -e $BOL"Current Status: $re"$DEF
	echo ""
	echo -e "Enter $YEL n $DEF to disable wifi reactivation and $YEL y $DEF to enable re-activation"
	echo "press enter to keep the current setting"
	read r
	if [ ! -z "$r" ]; then
		if [ $r = 'y' ]; then
			sed -i "s/re_enable_wifi=.*/re_enable_wifi='y'/" "${conf_path}${conf_file}"
		elif [ $r = 'n' ]; then
			sed -i "s/re_enable_wifi=.*/re_enable_wifi='n'/" "${conf_path}${conf_file}"
		fi
	fi
	re="$( grep -F 're_enable_wifi=' ${conf_path}${conf_file} )"
	echo "The status is set to: $re"
	read -p "press a key to continue"
}

setupssid()
{
	echo -e $YEL$BOL"Add or Edit a Wifi Network"$DEF
	echo "Add a new WiFi network or change the password for an existing one that is in range"
	echo "The nearby WiFi networks will be shown below shortly:"
	ct=0; j=0 ; lp=0
	wfselect=()

	until [ $lp -eq 1 ] #wait for wifi if busy, usb wifi is slower.
	do
		IFS=$'\n:$\t' localwifi=($((iw dev $wdev0 scan ap-force | grep -E "SSID:") 2>&1)) >/dev/null 2>&1
		#if wifi device errors recheck
		if (($j >= 5)); then #if busy 5 times exit to menu
			echo "WiFi Device Unavailable, cannot scan for wifi devices at this time"
			j=99
			read -p "press a key to continue"
			break
		elif echo "${localwifi[1]}" | grep "No such device (-19)" >/dev/null 2>&1; then
			echo "No Device found,trying again"
			j=$((j + 1))
			sleep 2
		elif echo "${localwifi[1]}" | grep "Network is down (-100)" >/dev/null 2>&1 ; then
			echo "Network Not available, trying again"
			j=$((j + 1))
			sleep 2
		elif echo "${localwifi[1]}" | grep "Read-only file system (-30)" >/dev/null 2>&1 ; then
			echo "Temporary Read only file system, trying again"
			j=$((j + 1))
			sleep 2
		elif echo "${localwifi[1]}" | grep "Invalid exchange (-52)" >/dev/null 2>&1 ; then
			echo "Temporary unavailable, trying again"
			j=$((j + 1))
			sleep 2
		elif echo "${localwifi[1]}" | grep "temporarily unavailable (-11)" >/dev/null 2>&1 ; then
			echo "Temporary unavailable, trying again"
			j=$((j + 1))
			sleep 2
		elif echo "${localwifi[1]}" | grep "not supported (-95)" >/dev/null 2>&1 ; then
			ap_no_scan_options
			j=99
		elif echo "${localwifi[1]}" | grep -v "Device or resource busy (-16)"  >/dev/null 2>&1 ; then
			lp=1
		else #see if device not busy in 2 seconds
			echo "WiFi Device unavailable checking again"
			j=$((j + 1))
			sleep 2
		fi
	done
	if [ $j -eq 99 ]; then
		menu
	fi
	#Wifi Connections found - continue
	for x in "${localwifi[@]}"
	do
		if [ $x != "SSID" ]; then #list available local wifi networks
			if [ -n ${x/ /} ];then
				if [[ -n ${x/ /} ]] && [[ ! ${x/ /} =~ "x00" ]] ;then #remove hidden ssids
					ct=$((ct + 1))
					echo "$ct  ${x/ /}"
					wfselect+=("${x/ /}")
				fi
			fi
		fi
	done
	ct=$((ct + 1))
	echo  "$ct To Cancel"
	wfselect+=("Cancel")
	if [ "${#wfselect[@]}" -eq 1 ] ;then
		echo "Unable to detect local WiFi Networks. Maybe there is a temporary issue with the WiFi"
		echo "Try again in a minute"
		read -p "press enter to continue"
		menu
	fi
	echo -e "\nDuplicate SSID's are different antennas for the same network. i.e 2.4Ghz and 5ghz"
	echo -e "Select either. The correct one will be used when connecting\n"
	echo "Enter selection:"
	read wf
	if [[ $wf =~ ^[0-9]+$ ]]; then
		if [ $wf -ge 0 ] && [ $wf -le $ct ]; then
			updatessid "${wfselect[$wf-1]}"
		else
			echo -e $YEL"\nNot a Valid entry"$DEF
			setupssid
		fi
	else
		echo -e $YEL"\nNot a Valid entry"$DEF
		setupssid
	fi
	read -p "press enter to continue"
}

updatessid()
{
	d=0
	echo "$1"
	echo ""
	if [ "$1" = "Cancel" ] || [ "$1" = "" ] ; then
		clear
		menu
	fi
	saved_profiles
	for x in "${nw_profile[@]}"
	do
		idssid=$(nmcli -t con show "$x" | grep "wireless.ssid")
		#echo "The SSID for profile is ${idssid:21}"
		if [ "${idssid:21}" = "$1" ]; then
			#edit password
			echo "Enter the new password for PROFILE: $x SSID: $1"
			echo "This must be at least 8 characters."
			read ssidpw
			if [ ! -z "$ssidpw" ] && [ ${#ssidpw} -ge 8 ] ;then
				nmcli connection modify "$x" wifi-sec.psk "$ssidpw" >/dev/null 2>&1
				echo "Attempting to connect to $x"
				nmcli device wifi connect "$x" >/dev/null 2>&1
				stat=$?
				if [ $stat -eq 0 ] ; then
					echo "Connection successful"
					echo -e "\nThe Password for profile $x is"
					npw="$(nmcli -t -s con show "$x" | grep 'wireless-security.psk:' )"
					echo ${npw:29}
					d=1
					break
				else
					echo "The connection to $x Failed because of the change to the Password"
					echo "The profile for $x has been deleted. Please try again"
					nmcli connection delete "$x" >/dev/null 2>&1
					nmcli connection reload >/dev/null 2>&1
					d=2
				fi
			else
				echo "A password was not entered or is less than 8 characters"
				echo "The password has not been changed"
				d=2
			fi
		fi
	done

	if [ $d -eq 0 ]; then #no existing profile for selection, create a new one.
		echo -e $YEL"Enter the Password for the Selected Wifi Network"$DEF
		echo "This must be at least 8 characters"
		echo "Selected SSID: $1"
		echo -e "\nEnter password for the Wifi Network"
		read chgpw
		echo "Attempting to connect to the new Wifi Network"
		if [ ! -z "$chgpw" ] && [ "${#chgpw}" -ge 8 ] ;then
			#create new profile with details
			nmcli device wifi connect "$1" password "$chgpw" >/dev/null 2>&1
			stat=$?
			if [ $stat -eq 0 ] ; then
				echo "Profile Created"
				echo "$1"
				pw="$( nmcli -t -s con show $1 | grep 'wireless-security.psk:' )"
				echo ${pw:29}
				nmcli connection reload
			else
				echo "The connection to $1 Failed."
				echo "The new profile has not been saved"
				nmcli connection delete "$1" >/dev/null 2>&1
				nmcli connection reload >/dev/null 2>&1
			fi
		else
			echo "A password was not entered or is less than 8 characters"
			echo "The password has not been changed"
		fi
	fi
}

#Function Change Hostname
namehost()
{
		hn="$(nmcli general hostname)"
		echo -e $YEL"System Hostname is: $hn"$DEF
		echo "Enter a new hostname or"
		read -p "just press enter to keep existing hostname"
		if [ ! -z $r ]; then
			nmcli general hostname "$r"
			echo "The hostname has been changed"
			echo "You will need to restart the computer to complete the changes."
		fi
		hn="$(nmcli general hostname)"
		echo "Current Hostname is: $hn"
		read -p "press a key to continue"
}

ap_no_scan_options()
{
	local new_nw; local new_pw
	echo -e $YEL"\nThis device is unable to check for nearby Wifi Networks while the accesspoint is active."$DEF
	echo -e "$BOL Option 1: $DEF If you are using a screen on this device then use $BOL 1 $DEF to stop the Access Point and continue\n"
	echo -e "$BOL Option 2: $DEF If you are connected remotely such as ssh or vnc use $BOl 2 $DEF, then you can enter the network ssid and password manually."
	echo "Your connection to this device will then be disconnected while an attempt is made to connect to the new wifi network."
	echo "You will need to connect to the new network to continue"
	echo -e "\nIf there is any issues with the entered details such as; $BOL \nWifi network not in range\npassword incorrect\ngeneral connection failure $DEF"
	echo "Then the details will be deleted and the Access Point will be restarted"
	echo "You will need to reconnect to the Access Point again to continue if this happens."
	echo -e "\nType 1 or 2 to continue or just press enter to return to the min menu"
	read r
	if [ $r -eq 1 ]; then
		nmcli connection down $active
		setupssid
	elif [ $r -eq 2 ]; then
		echo -e $YEL"Enter the Wifi Network name (SSID) to be connected to:"$DEF
		echo "or just press enter to cancel"
		read n
		if [ -z "$n" ]; then
			menu
		else
			new_nw="$n"
			echo -e $YEL"Enter the password for $new_nw" $DEF
			echo "or just press enter to cancel"
			read n
			if [ -z "$n" ]; then
				menu
			else
				new_pw="$n"
				echo -e "\nA connection will be attempted to $new_nw"
				echo "Your connection with this device will be closed."
				echo "If there is a connection issue with $new_nw then the Access Point"
				echo "will be restarted. So if you cannot find this device on $new_nw"
				echo "then check for the AccessPopup wifi Access Point to connect to."
				echo "Please allow at least 30 seconds for this device to appear on $new_nw or the AP"
				echo "Press Enter to continue"
				read r
				nmcli connection down $active
				nohup ./nw_setup_offline.sh -s "$new_nw" -p "$new_pw" >/dev/null 2>&1 &
				menu
			fi
		fi

	else
		menu
	fi

}

devices()
{
	local devs=()
	local sorted_pairs=()
	for dev in /sys/class/net/*; do
		dev=$(basename "$dev")
		dev_path=$(readlink -f "/sys/class/net/$dev/device")
		if [[ -d "/sys/class/net/$dev/wireless" ]]; then
			if echo "$dev_path" | grep 'usb' >/dev/null 2>&1; then
				devs+=("wx ${dev}")
			else
				devs+=("wi ${dev}")
			fi
		fi
	done

	if [ -z "$devs" ]; then #no wifi device found
		echo ""
		echo "No Wifi device found."
		echo "The default of wlan0 will be used. AccessPopup will not work correctly if this is incorrect."
		echo "Manually update /etc/accesspopup.conf with the correct wifi device name when it is available"
		echo
		read -p "press any key to continue"
	else
		while IFS= read -r line; do
			sorted_pairs+=("$line")
		done < <(
			for pair in "${devs[@]}"; do
			printf "%s\n" "$pair"
			done | sort -k1,1   # Sorts by key
		)
		for i in "${sorted_pairs[@]}"; do
			read key val <<< "$i"
			[[ "$wdev0" = "wlan0" && ( "$key" == "wi" || "$key" == "wx" ) ]] && wdev0="$val"
		done
	fi
}

create_user()
{
# Create a dedicated system user without login shell
if ! id -u acpu >/dev/null 2>&1; then
    echo "Creating acpu system user..."
    useradd -r -s /usr/sbin/nologin -d /nonexistent acpu
fi
}

add_permissions()
{
# Create sudoers file with restricted privileges

echo "acpu ALL=(ALL) NOPASSWD: /usr/bin/nmcli, /usr/sbin/iw, /usr/bin/tee, /etc/accesspopup.conf, /usr/local/bin/accesspopup" > "$sudoers_file"
chmod 440 "$sudoers_file"

if visudo -cf "$sudoers_file"; then
    echo "Sudoers file validated successfully."
    #add acpu user
	if ! id acpu >/dev/null 2>&1; then
		useradd --system --no-create-home --shell /usr/sbin/nologin acpu
	fi
	return 0
else
    echo "Error: invalid sudoers file, removing..."
    rm -f "$sudoers_file"
    uninstall_web
    return 1
fi
}

webport()
{
	if [ ! -f "$sysd_path$webappsock" ]; then
		echo "The Web Page feature is not installed. Unable to change the port"
		echo "Press enter to continue"
		read x
		menu
	fi
	wp="$( grep -F ListenStream= ${sysd_path}${webappsock} )"
	ls="ListenStream=0.0.0.0:"
	if [ $? = 0 ];then
	echo -e $YEL"Raspberryconnect.com"
	echo "AccessPopup installation and setup"
	echo -e "Wep App Port Number"$DEF
	echo "Change the wep app web port from http://ipaddress:${wp:21}"
	echo "Enter the new port number"
	echo "or Press enter to keep the existing port number"
	read port
		if [ ! -z "$port" ]; then
			sed -i "s/ListenStream=.*/${ls}${port}/" "${sysd_path}${webappsock}"
			wp="$( grep -F ListenStream= ${sysd_path}${webappsock} )"
			echo "Web port changed to ${wp:21}"
			echo ""
			echo "Resetting Web Services."
			systemctl daemon-reload
			if systemctl -all list-unit-files "$webback" | grep "$webback enabled" >/dev/null 2>&1;then
				echo "Resetting the Web App to update changes"
				disable_web
				enable_web
			fi
			read -p "Press a key to continue"
		fi
	fi
}

uninstall()
{
	echo "Uninstalling $scriptname"
	#Remove Timer service
	if systemctl -all list-unit-files $timer | grep $timer ;then
		systemctl unmask $timer
		systemctl disable $timer
		rm /etc/systemd/system/$timer
		systemctl daemon-reload
	fi
	if systemctl -all list-unit-files $service | grep $service ;then
		systemctl unmask $service
		systemctl disable $service
		rm /etc/systemd/system/$service
	fi
	#Remove AP and NM profile
	if [ -f "${script_path}${scriptname}" ]; then
		profap="$( grep -F ap_profile_name= ${conf_path}${conf_file} )"
		nmcli con delete "${profap:17:-1}" >/dev/null 2>&1
		nmcli con reload
		rm "${script_path}${scriptname}"
		rm "${conf_path}${conf_file}"
	fi
	echo "Uninstalled AccessPopup Files"
	uninstall_web
}

uninstall_web()
{
	#Remove webfiles if exist
	if [ -d $web_path ]; then
		rm -r $web_path
	fi
	#remove systemd services
	if systemctl -all list-unit-files $webback | grep $webback ;then
		systemctl stop $webappsock
		systemctl stop $webapp
		systemctl stop $webback
		systemctl disable $webappsock
		systemctl disable $webback
		systemctl daemon-reload
		rm /etc/systemd/system/$webapp
		rm /etc/systemd/system/$webappsock
		rm /etc/systemd/system/$webback
	fi
	#remove visudo file
	if [ -f $sudoers_file ]; then
		rm -r $sudoers_file >/dev/null 2>&1
	fi
	#remove acpu user
	if id acpu ; then
		delgroup acpu >/dev/null 2>&1
		deluser acpu >/dev/null 2>&1

	fi
	echo "Uninstalled Web Files"
	read -p "Press any key to continue"
}

go()
{
	opt="$1"
	if [ "$opt" = "INS" ] ;then
		if ls "${script_path}${scriptname}" >/dev/null 2>&1; then
			echo "$scriptname is already installed"
			read -p "Press a key to continue"
		else
			echo "Installing Script"
			install_general
		fi
	elif [ "$opt" = "SSI" ] ;then
		#"Change the Access Points SSID and Password"
		ap_ssid_change
	elif [ "$opt" = "NWK" ] ;then
		setupssid
	elif [ "$opt" = "SWI" ] ;then
		echo -e $YEL"Switching between WiFi Network and WiFi Access Point."$DEF
		if [ -f "$script_path$scriptname" ]; then
			switch
		else
			echo "$scriptname is not currently installed."
			echo "Please install it first"
			read -p "Press a key to continue"
		fi
	elif [ "$opt" = "IPA" ] ;then
		echo -e "${BOL}Set IP address for AP${DEF}"
		ap_change_ip
	elif [ "$opt" = "UNI" ] ;then
		if ls "${script_path}${scriptname}" >/dev/null 2>&1 ; then
			uninstall
		else
			echo "$scriptname is not installed"
			read -p "Press a key to continue"
		fi
	elif [ "$opt" = "RUN" ] ;then
		if [ -f "${script_path}${scriptname}" ]; then
			echo "Running ${scriptname} now"
			"${script_path}${scriptname}"
			read -p "Press a key to continue"
		else
			echo "$scriptname is not available."
			echo "Please install the AccessPopup first with Option 1"
			read -p "Press a key to continue"
		fi
	elif [ "$opt" = "HST" ] ;then
		namehost
	elif [ "$opt" = "DIS" ] ;then
		reactivate
	elif [ "$opt" = "WEB" ] ;then
		webcheck
	elif [ "$opt" = "MU2" ] ;then
		menu_more
	elif  [ "$opt" = "WPO" ] ;then
		webport
	fi
	clear
	menu
}

menu()
{
#selection menu
clear
until [ "$select" = "9" ]; do #set number to qty of menu options
	active_wifi
	apver="$( grep -F '#version' ${scriptname} )"
	curip=$(nmcli -t con show "$active" | grep IP4.ADDRESS)
	readarray -d ':' -t ipid < <(printf "%s" "$curip")
	showip="$(echo "${ipid[1]}" | sed 's/[[:blank:]]//g')"

	echo -e $YEL"Raspberryconnect.com"
	echo "AccessPopup installation and setup"
	echo -e "Version $ver  Installs AccessPopup ver ${apver:9}"$DEF
	echo "Connects to your home network when you are home or a nearby know wifi network."
	echo "If no known wifi network is found then an Access Point is automatically activated"
	echo -e "until a known network is back in range\n"
	echo "Using wifi device $wdev0"
	if [ -z "$active" ]; then
		echo "Not currently using a Wifi profile"
	else
		echo "Currently using WiFi profile: $active"
		if [ ! -z $showip ]; then
			echo "Current WiFi IP address is: ${showip::-3}"
		fi
		hn="$(nmcli general hostname)"
		echo "System Hostname is: $hn"
	fi
	echo ""
	echo " 1 = Install AccessPopup Script"
	echo " 2 = Change the AccessPopups SSID or Password"
	echo " 3 = Change the AccessPopups IP Address"
	echo " 4 = Live Switch between: Known WIFI Network <> Access Point"
	echo " 5 = Setup a New WiFi Network or change the password to an existing Wifi Network"
	echo " 6 = Change Hostname"
	echo " 7 = Run $scriptname now. It will decide between a suitable WiFi network or AP."
	echo " 8 = Additional Menu"
	echo " 9 = Exit"
	echo ""
	echo "The Wifi status will be checked every 2 minutes. Switching will happen when a"
	echo "valid wifi network comes in and out of range."
	echo "use option 4 or the command: sudo $scriptname -a"
	echo "to activate a permanent access point, until the next reboot"
	echo "or when just sudo $scriptname is used."
	echo -e -n "\nSelect an Option:"
	read select
	case $select in
	1) clear ; go "INS" ;; #Install AccessPopup
	2) clear ; go "SSI" ;; #Set the AP SSID and Password
	3) clear ; go "IPA" ;; #Set the Access Points IP Address
	4) clear ; go "SWI" ;; #Live Switch: NW <> AP
	5) clear ; go "NWK" ;; #Connect to New WiFi Network
	6) clear ; go "HST" ;; #Change Hostname
	7) clear ; go "RUN" ;; #Run the AccessPopup script now
	8) clear ; go "MU2" ;; #Additional Menu
	9) clear ; exit ;;
	*) clear; echo -e "Please select again\n";;
	esac
done
}

menu_more()
{
	#Additional menu
	clear
	until [ "$select" = "5" ]; do #set number to qty of menu options
	echo -e $YEL"Raspberryconnect.com"
	echo "AccessPopup installation and setup"
	echo -e "Additional Options"$DEF
	echo ""
	echo " 1 = Web Interface - enable & disable switch"
	echo " 2 = Change the Webport. default 8052"
	echo " 3 = When Wifi is Disabled: Automatically re-activate Y/N"
	echo " 4 = Uninstall $scriptname and Web app"
	echo " 5 = Back to the Main menu"
	echo -e -n "\nSelect an Option:"
	read select
	case $select in
	1) clear ; go "WEB" ;; #Web Interface enable disable
	2) clear ; go "WPO" ;; #Web Port number
	3) clear ; go "DIS" ;; #Wifi reactivation options
	4) clear ; go "UNI" ;; #Uninstall AccessPopup
	5) clear ; menu ;;
	*) Clear ; echo -e "Please select again\n";;
	esac
done
}
devices
menu
