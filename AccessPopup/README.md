## Automated Switching - Access Point or WiFi Network

A WiFi Access Point that is automatically created when the WiFi signal is lost but reconnects to the WiFi network when it is back in range, so that a WiFi connection is always available.
For portable devices such as a Raspberry Pi and Linux Laptops that use Network Manager. Useful for both headerless and desktop setups.


With the Raspberry Pi being so portable it is always useful to have a wifi connection. When the wifi signal has been lost due to a weak signal, it can be a bit of a nightmare trying to get access to a device without a screen.

This Script will monitor the wifi connection and make sure you are connected to a known Wifi network when the signal is good or it will create a WiFi Access Point, so you will always have a wifi connection available to the device.  It will also allow you to flip to an Access Point with a simple command and back to a WiFi network on demand.

**Originally developed for the Raspberry Pi it has been expanded to run on most Linux devices that use Network Manager.**

The Access Point will allow a direct Wifi connection to the Pi from a Phone, Tablet, Laptop for use with ssh, VNC desktop sharing, a local web server, etc.

Every 2 minutes the AccessPopup script will check the local wifi network signals. If a known one comes back into range, then a connection is made to the wifi network and the Access Point is stopped *.

This is useful for Devices that may be running sensors, cameras or other monitoring software in your Garden, Greenhouse, Shed or Garage that may be where the WiFi signal is weak. You will always be able to get a connection over wifi and is ideal for headerless setups. 


## Compatibility:
The AccessPopup script should also work on any **Debian, Fedora or Arch Linux** device or variants of these distros, (**Single Board Computer, Laptop or CyberDeck**) that use Network Manager and SystemD. Python is also required for the optional web page controls.

A Raspberry Pi 64 bit computer (Pi5, 500, Pi4, 400, Pi3/+, Zero2) PIOS 12 Bookworm or newer is required as older versions don't use Network Manager.

The Rpi Zero W is too slow to work reliably with this on PiOS 13 Trixie so using 12 Bookworm is recommended. The Rpi Zero 2 works fine on PiOS Trixie.
Using a Rpi Zero W 32bit OS, the Access Point connects fine with Windows 11 and Linux but on Android (tested on 15) it does not connect with “password incorrect” error. This seems to be Androids stricter connection settings.  

For older Raspberry Pi OS's there is a similar script called Autohotspot available on RaspberryConnect.com which uses dhcpcd instead of NetworkManager. Also available on this GitHub account.


## Installation and Use:
**Latest versions:**
accesspopup 0.9, 22nd March 2026
installconfig.sh 1.01, 15th April 2026

#### Previous_Version of InstallConfig.sh:
If you have a version older than version 1 installed then uninstall AccessPopup before installing version 1 or newer, as there is a different configuration from version 1.

### Installation:

If you have the GIT command installed on your system then use

``` git clone https://github.com/RaspberryConnect/AccessPopup.git ```

Otherwise while still on GitHub use the “Code” button and choose Download.zip
This will download AccessPopup-main.zip
UnZip the files using the Desktop option or the command 
``` unzip AccessPopup-main.zip ```

Rename the AccessPopup-main folder to AccessPopup
``` mv AccessPopup-main AccessPopup ```

Next cd to the AccessPopup folder.
``` cd AccessPopup ```

To run the Installer script

``` sudo chmod +x ./installconfig.sh ```

``` sudo ./installconfig.sh ```

Change the password with option 2

The menu options below will be presented. Use option 1 to install the AccessPopup scripts.
This will automatically start monitoring the wifi connection every 2 minutes. It will also check the wifi at startup and then at every 2 minute intervals.

### Setting a Constant Access Point:
Sometimes it is useful to be able to use the AccessPoint even though the device is in range of a known WiFi network.
This can be done by opening a terminal window and entering the command:
``` sudo accesspopup -a ```

to go back to normal use, just run the script without the -a argument.
``` sudo accesspopup ```

alternately use option 4 "Live Switch..." on this installer script.

## Menu Options:
<img width="502" height="362" alt="Install_Menu" src="https://github.com/user-attachments/assets/a79d1713-cd20-4f54-9662-55c1c330af70" />

### 1 = Install AccessPopup Script
Installs the AccessPopup script and starts the 2 minute checks

### 2 = Change the AccessPopups SSID or Password
The access points wifi name (ssid) is AccessPopup and the password is 1234567890.
Use this option to change either or both. At least change the terrible password.

### 3 = Change the AccessPopups IP Address
The Access Points IP address is 192.168.50.5. Use this option to choose a new IP address, based on 10.0.#.# or 192.168.#.#
This is the ip address that is used when using ssh, VNC or a webserver while another device is connected to the Access Point"

### 4 = Live Switch between: Network WiFi <> Access Point
Switch on demand. Set the device to an Access Point until the next reboot or switch back to a known WiFi Network in range.

### 5 = Setup a New WiFi Network or change the password to an existing Wifi Network
Scan for local WiFi networks and connect to a new one or change the password to an existing profile.

### 6 = Change Hostname
Change the system Hostname, so a connection can be made by name instead of an IP address (Wifi network Connection only).

### 7 = Run AccessPopup now. 
The AccessPopup script will decide between a known WiFi network or an AP if one is not in range.

### 8 = Additional Menu options:

### 8-1 = Web Interface - enable & disable switch
Installs the Web interface if not previously installed. Then used to enable or disable the web page controls.
Webpage controls are available at http://ip-address:8052 http://hostname:8052 on a wifi network or http://192.168.50.6:8052 for the Access Point.

### 8-2 = Change the Webport
Change the webport from 8052 to a port of your choice.

### 8-3 = When Wifi is Disabled: Automatically re-activate Y/N
The AccessPopup script will enable the devices Wifi if it is disabled when it runs every 2 minutes.
If WiFi availability is managed elsewhere on the device then this will disable WiFi activation when AccessPopup is run.

### 8-4 = Uninstall accesspopup and Web app
Removes the AccessPopup files and the Web Interface if it has been installed.

### 8-5 = Exit back to previous menu

### 9 = Exit
Exit the installer back to the cmd prompt

 
## Using the Access Point:

**“ACPU_Device” = Device Running the AccessPopup Script**

**“Phone” = WiFi Device connected to the ACPU_Device**

For the rest of this guide I will refer to the device running the Linux AccessPopup script as the **“ACPU_Device”** so this will be the Raspberry Pi or other Single Board Computer or a Linux Laptop.
The device connecting to the ACPU_Device over Wifi, either directly to the Access Point or via another Wifi Network as a **“Phone”**. This can be any wifi capable device.

When the Access Point has been activated, the SSID “AccessPopup” will be broadcast. Using a Phone scan, for new wifi devices in the area, and select “AccessPopup”.

You will be prompted to enter the password.
If you have not already changed it, the un-secure default password will be 1234567890.

The Phone will now be connected to the Access Point.

**SSH, VNC, Web Server**
Now that a connection to the Access Point has been made, if you are using SSH, VNC or accessing a web server on the Access Point then use:

``` ssh: username@192.168.50.5 ``` so if your user is called “me”, then use
``` ssh me@192.168.50.5 ```

VNC remote desktop: enter the server as ``` 192.168.50.5 ```

Web server: if there is a web server running on the Access Point, it can be used by entering ``` http://192.168.50.5/ ``` into a web browser.

The Hostname can be used to replace the ip address only when the ACPU_Device is connected to a WiFi network.

If the ACPU_Device has the Access Point active and an Ethernet connection to the internet is available, then the Phone will also have internet access.

## Using AccessPopup in a terminal window: 
The AccessPopup script is set to run automatically every 2 minutes, but it can be run manually to switch to the Access Point.

In a terminal window enter:
``` sudo accesspopup -a ```

The access point will be activated, and the timer will be stopped so it doesn't try to connect to a Wifi network again in 2 minutes.

To re-connect to a nearby known wifi network either run the script without -a or reboot. 
``` sudo accesspopup ```

This will attempt to connect to a known local wifi network and re-activate the 2 minute timer.

If a wifi network connection can't be made, it will activate the Access Point again and continue to monitor the connections every 2 minutes.
 
  
## Considerations and behaviour:
### The Access Point disconnects every 2 minutes.

If a WiFi network is setup but the password is not correct, then the connection will fail. Once there is an attempt to connect to a WiFi network, it is added to the list of known networks by Network Manager.
When an Access Point is active, every 2 minutes it will be deactivated to connect to the bad WiFi network when it is in range. This will disrupt any connections to the Access Point.
The Access Point will be re-enabled once the connection to the Wifi network has failed.
If you experience this, then correct the password with option 5 or the Desktop gui option. Otherwise delete the bad Wifi network entry.

### \* The Access Point is in use but does not switch to a known Wifi Network that is in range.
If the Access Point is active and the Phone is connected to it when a known WiFi network is in range, it will not switch to keep the connection with the phone and not interrupt anything you may be doing. Once the Phone disconnects from the Access Point and the 2 minutes are up the ACPU_Device will switch to the known wifi network.

### Ethernet connection to the ACPU_Device

If an Ethernet cable is connected to the ACPU_Device and the Access Point is available, any device connected to the Access Point can ssh/vnc/ping etc the other devices also connected to the access point and the network the Ethernet is connected to. This includes the internet, if it is available.
This does not work the other way. No device on the Ethernet's network can connect ssh/vnc/ping etc to the devices connected to the access point. The Ethernet network can access the ACPU_Device, as it is on both networks.

### Using a Second WiFi Device

When a second Wifi device is connected to the ACPU_Device such as a USB Wifi dongle, no device connected to the access point can ssh/vnc/ping etc the network that the second Wifi device is connected to. Devices connected to the Access Point can only access the internet or other networks through a connected Ethernet cable.
To do this through a second wifi device requires additional configuration which is not in the scope of this setup.

### Loss of Connection when a Switch happens

Any connection to the ACPU_Device from the Phone will be disconnected when the ACPU_Device switches from a Wifi Network connection to an Access Point and back. 

If you are using SSH, then programs such as TMUX will keep your session running while a connection from the Phone to the ACPU_Device is made on the new network.

VNC will reconnect if you are using a Hostname as the server connection. If you have connected with an IP address, then you will need the new IP address from the wifi network the ACPU_Device has connected to.

### Loss of Wifi the Connection:
If the wifi disconnected, then wait a couple of minutes and the Access Point will be created or a reconnection to a known Wifi network will be made. 

### Hostapd not compatible

If hostapd is active on the ACPU_Device then the Network Manager Access Point will fail as there will be a conflict. Either disable hostapd with:

``` sudo systemctl stop hostapd ```

and

``` sudo systemctl disable hostapd ```

or uninstall hostapd

### Multiple Devices with AccessPopup installed:
If you have more then one device with AccessPopup installed then change the SSID with option 2. This is so you can tell which device has the Access Point active. Otherwise they will all be called “AccessPopup” and you won’t know which device to connect to. The IP address does not need to be changed as they will each be independent connections.

### Visibility of Access Point connected devices
All devices connected to the Access point can ping and connect to each other using their IP address as well as the device running AccessPopup (ACPU_Device).

If an Ethernet connection to the internet is available on the ACPU_Device then all devices connected to the Access Point will have internet access and can also ping and connect to the devices on the Ethernet network. Unless Firewall restrictions are in place.

The devices on the Ethernet network can ping and connect to the ACPU_Device but they cannot ping or connect to the devices connected to the Access Point.
If you wish to connect in this way then connect to the ACPU_Device first via ssh or VNC and then connect to the required device via the IP address. 

### Dependencies
The AccessPopup script requires various packages to be available on the Linux system. They will also be installed if they are not available other than Network Manager and SystemD.
1. Network Manager 
1. SystemD
1. IW
1. dnsmasq-base (Debian)
1. dnsmasq (Fedora, Arch – should be disabled in SystemD).

For the optional Web Interface, Python with a Virtual-Env and PIP will be required. If Python is not already on the system then the Web Interface will not be installed.
Pip and a virtual env will be installed if Python is available but they are not installed. 



## Web Interface (Optional):
Install, Enable and Disable the web interface with menu option 8-1.

**Guide Reference:**
**“ACPU_Device” = Device Running the AccessPopup Script**
**“Phone” = WiFi Device connected to the ACPU_Device**

When activated the web interface is available at http://ip_address:8052 or on a WiFi network http://hostname:8052. On the ACPU_Device you can also use http://localhost:8052 or http://127.0.0.1:8052

There is a user Guide on the Web Interface for convenient information.

Because the AccessPopup script and functions on the Web Interface are about switching between Wifi Networks the Web Interface pages will be disconnected from the ACPU_Device with some features.
So you will need to make sure the ACPU_Device and Phone are on the same WiFi network at all times for it to be used.
<br><img width="200" height="40" alt="guide_home_img_buttons" src="https://github.com/user-attachments/assets/1f6973e6-3582-44d9-a4e0-5dbbd920752c" /><br>
**Please Note:** If you use the “Switch to AP” button or have used the command ``` sudo accesspopup -a ``` the ACPU_Device will be in a permanent Access Point mode.

<br><img width="200" height="167" alt="change_accesspopup_details" src="https://github.com/user-attachments/assets/0a3228bf-8b2d-4793-801e-174083a666d0" /><br>

Then if you use the option to change the Access Points password or SSID, the Network Manager profile for “AccessPopup” will be deleted so that the new details can be used. The AccessPopup script will return to the Timer mode and check the connection every 2 minutes. 
This is because the Access Point will be shutdown to make the changes and if there is no known WiFi network in range there will be no WiFi access to the ACPU_Device.

**Please Note Again:** because the features of the Web Interface are for modifying the network setup. Even though multiple devices can view the pages at any one time. Only one connection should make changes at a time to avoid causing issues.

### Home Page:
<img width="452" height="410" alt="ACPU_Web_HomePage_sml" src="https://github.com/user-attachments/assets/e1a2ce78-3531-4fe1-8369-848c131d1e00" />

This page show details about the network devices.
Wifi network, device and IP address.
If Ethernet is connected then the IP address will be shown

Refresh this page to get the current connection details when making changes.

The “Switch to AP” will force the ACPU_Device to an Access Point and stop the 2 minute timer.

The “Restart NW Checks” button. Will restart the 2 minute Timer and connect to a Wifi network if one is in range.
This will only work on a ACPU_Device with a screen. As the Phone will be connected to the Access Point the switch to a Wifi Network is not available. Use the “Edit WiFi Profiles” page to connect to a selected Wifi Network.
 
### Edit Wifi Profiles
<img width="455" height="232" alt="ACPU_Web_Edit_Wifi_Profile_sml" src="https://github.com/user-attachments/assets/a2f13805-8739-4de0-9314-caac975b7f31" />

This page lists the known wifi networks setup on the ACPU_Device.
If there are no Networks listed then none are available. Use the page “Add New Wifi Network” to create a new profile.

Select the required network from the list.
**“Edit Selected Password”** – This will allow you to update the password for a previously save Wifi Network.
It will then be connected to. If there is an issue while connecting, such as an incorrect network name, then it will be deleted. 

**“Connect to Selected”** – Connect to the selected network.
If “Switch to AP” on the home page has been used so the Timer is disabled, using this option will re-enable the 2 minute timer.

**”Delete selected:”** Delete the stored profile. 
If the currently connected profile is deleted then an attempt will be made to connect to another nearby network by Network Manager. 
If there is no suitable connection available you may have no wifi until the next 2 minute timer is complete. AccessPopup will then create an Access Point if required.

#### AccessPopup Profile:
<img width="454" height="227" alt="ACPU_Web_Edit_ACPU_Profile_sml" src="https://github.com/user-attachments/assets/d84ed484-6980-49b0-b060-f8982318672c" />

Here you can change the AccessPopups SSID so other Wifi devices see the Wifi Name of your choice. This is also useful when there are multiple devices with AccessPopup running, so you can identify which device has its Access Point active.
The Password can also be change here. If the default insecure password is still available then it's a good opportunity to change it.

You can change either or both settings. **Please Note:** If the ACPU_Device is in a permanent Access Point mode with the "Switch to AP" button or the ``` accesspopup -a ``` command, then it will be returned to a switching 2 minute timer.
This is because the profile will be deleted so the ACPU_Device will be left with no wifi connection, if there is no Wifi network is in range."

## Add New Wifi Network
<img width="455" height="331" alt="ACPU_Web_add_new_network_sml" src="https://github.com/user-attachments/assets/8119861a-e003-4663-80ba-e764a441405c" />

Select the **Refresh List** button to see a list of nearby wifi networks you can choose to create a new connection for. Please allow the scan to complete before clicking elsewhere.
This can take 30 seconds or so for the list to appear.

If any of the Wifi networks that are configured on the ACPU_Device are in range then they will be shown underneath the selectable list. These can be connected to on the "Edit Wifi Profiles" page.

When you have selected a new network from the list and clicked "Add Selected", you will be asked to enter the password.
When "Connect to Selected Network" is clicked, an attempt will be made to connect to the new network.
If the Connection is successful, the page will timeout as the Phone will now need to connect to the same selected network to reconnect to the Server to continue to use the Web App.

If the connection is not successful, such as the incorrect password, then the new profile will be deleted. The ACPU_Deice will either connect to another known Wifi Network or if none are available the Access Point will be started. So you will need to locate what the ACPU_Device has done to continue.

**Please Note:** some laptop wifi devices are not able to scan for nearby networks if they have an Access Point active. 
If this is the case then you will be asked to manually enter the new networks SSID and Password instead of selecting the SSID from the list. 
The Access Point will then be stopped and the ACPU_Device will attempt to connect to the entered WiFi network. Any issues such as an incorrect password will cause the profile to be deleted and the ACPU_Device will connected to a known Wifi network or generates the Access Point.

## Devices warning of No Internet
<img width="200" height="270" alt="no_internet_warning" src="https://github.com/user-attachments/assets/1dfe29ad-853e-423e-900b-b870202ca5c8" />

When a Phone, Laptop, Tablet first connects to the AccessPopup access point it may warn you that there is no Internet connection and ask if you want to continue with the connection or just for this session.
The access point won't have internet access unless the ACPU_Device has an Ethernet cable connected, which is also connected to the internet. So choose "Always Connect".

## General Connection Issues
A Wifi connection can be affected by many factors outside what this script is doing, such as;

1. interference
1. too many wifi signals on the same channel
1. a low battery on the device
1. too many devices connected to the device for the available power supply meaning there is little power to run wifi reliably

The AccessPopup script does not make the connection to network devices, it only monitors the active Network Manager profile and de-activates and activates profiles as required. 
Network Manager creates and manages the connections and permissions between devices. If you suspect that AccessPopup script is causing an issue please uninstall AccessPopup and try to replicate the problem you are having.
If the issue only occurs while the AccessPopup script is running then please contact me with as much detail about your system and the issue you have and I will be happy to look into this further.

Issues of poor connection, slow data can be due to a device and not the AccessPopup script especially when the Access Point is not active.
While the Access Point is active; if there are connection issues that you do not experience with other Access Point setups then I will be happy to investigate further.

If the web app become unresponsive but you know the ACPU_Device and Phone are on the same network, then there may be an issue. You can restart the web server by using the installconfig script. Use option 8-1 “Web Interface - enable & disable switch” to disable the Web App and then again to re-enable the Web App.

## Support
AccessPopup has been developed by a single developer. If you find this useful and you would like to show your support then I would appreciate any promotion on social media or a donations towards the cost of development and web hosting or even just a comment on RaspberryConnect.com to say how you are using the AccessPopup as it is always interesting to hear how this project is being used. Ultimately I hope you find it useful.  
A Donation can be made with the Sponsor button at the top of this repository, or on the article on the home page at RaspberryConnect.com.
  



