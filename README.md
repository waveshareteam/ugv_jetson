![GitHub top language](https://img.shields.io/github/languages/top/waveshareteam/ugv_jetson) ![GitHub language count](https://img.shields.io/github/languages/count/waveshareteam/ugv_jetson)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/waveshareteam/ugv_jetson)
![GitHub repo size](https://img.shields.io/github/repo-size/waveshareteam/ugv_jetson) ![GitHub](https://img.shields.io/github/license/waveshareteam/ugv_jetson) ![GitHub last commit](https://img.shields.io/github/last-commit/waveshareteam/ugv_jetson)

# Waveshare UGV Robots
This is a Jetson Orin Nano & Jetson Orin NX example for the [Waveshare](https://www.waveshare.com/) UGV robots: **WAVE ROVER**, **UGV Rover**, **UGV Beast**, **RaspRover**, **UGV01**, **UGV02**.  

![](./media/UGV-Rover-details-23.jpg)

## Basic Description
The Waveshare UGV robots utilize both an upper computer and a lower computer. This repository contains the program running on the upper computer, which is typically a Jetson Orin Nano or a Jetson Orin NX in this setup.  

The program running on the lower computer is either named [ugv_base_ros](https://github.com/effectsmachine/ugv_base_ros.git) or [ugv_base_general](https://github.com/effectsmachine/ugv_base_general.git) depending on the type of robot driver being used.  

The upper computer communicates with the lower computer (the robot's driver based on ESP32) by sending JSON commands via GPIO UART. The host controller, which employs a Jetson Orin Nano or a Jetson Orin NX, handles AI vision and strategy planning, while the sub-controller, utilizing an ESP32, manages motion control and sensor data processing. This setup ensures efficient collaboration and enhanced performance.

## Features
- Real-time video based on WebRTC
- Interactive tutorial based on JupyterLab
- Pan-tilt camera control
- Robotic arm control
- Cross-platform web application base on Flask
- Auto targeting (OpenCV)
- Object Recognition (OpenCV)
- Gesture Recognition (MediaPipe)
- Face detection (OpenCV & MediaPipe)
- Motion detection (OpenCV)
- Line tracking base on vision (OpenCV)
- Color Recognition (OpenCV)
- Multi-threaded CV processing
- Audio interactive
- Shortcut key control
- Photo taking
- Video Recording

## Quick Install
You need to install [Jetson Orin Nano Developer Kit](https://www.waveshare.com/jetson-orin-nano-dev-kit.htm) on your robot if you are using **WAVE ROVER**, **UGV01** or **UGV02**.  

This app is already installed in the **UGV Rover Jetson Orin AI Kit**, **UGV Beast Jetson Orin AI Kit** and **RaspRover Jetson Orin AI Kit**.  

You can use this tutorial to upgrade your robot's upper computer program.  

You can use this tutorial to install this program on a pure Ubuntu(22.04) on Jetson.  


### Download the repo from github

You can clone this repository from Waveshare's GitHub to your local machine.

    git clone https://github.com/waveshareteam/ugv_jetson.git
### Grant execution permission to the installation script
    cd ugv_jetson/
    sudo chmod +x setup.sh
    sudo chmod +x autorun.sh
### Install app (it'll take a while before finish)
    sudo unminimize
    sudo ./setup.sh
### JupyterLab Setup
    python3 create_jupyter_service.py
    sudo mv ugv_jupyter.service /etc/systemd/system/ugv_jupyter.service
    sudo systemctl enable ugv_jupyter
    sudo systemctl start ugv_jupyter
### Volume and Pulseaudio for Multi-user Setup
    pactl set-sink-volume alsa_output.usb-Solid_State_System_Co._Ltd._USB_PnP_Audio_Device_000000000000-00.analog-stereo 100%
    sudo cp pulseaudio.service /etc/systemd/system/pulseaudio.service
    sudo systemctl --system enable --now pulseaudio.service
    sudo systemctl --system status pulseaudio.service
### Service for Jtop
    sudo systemctl enable jtop.service
### Autorun Setup
    ./autorun.sh
### AccessPopup Installation
    cd AccessPopup
    sudo chmod +x installconfig.sh
    sudo ./installconfig.sh
    *Input 1: Install AccessPopup
    *Press any key to exit
    *Input 9: Exit installconfig.sh
### Reboot Device
    sudo reboot

After powering on the robot, Jetson will automatically establish a hotspot, and the OLED screen will display a series of system initialization messages:  

![](./media/RaspRover-LED-screen.png)
- The first line `E` displays the IP address of the Ethernet port, which allows remote access to the Raspberry Pi. If it shows No Ethernet, it indicates that the Raspberry Pi is not connected to an Ethernet cable.
- The second line `W` indicates the robot's wireless mode. In Access Point (AP) mode, the robot automatically sets up a hotspot with the default IP address `192.168.50.5`. In Station (STA) mode, the Raspberry Pi connects to a known WiFi network and displays the IP address for remote access.
- The third line `F/J` specifies the Ethernet port numbers. Port `5000` provides access to the robot control Web UI, while port `8888` grants access to the JupyterLab interface.
- The fourth line `STA` indicates that the WiFi is in Station (STA) mode. The time value represents the duration of robot usage. The dBm value indicates the signal strength RSSI in STA mode.  


You can access the robot web app using a mobile phone or PC. Simply open your browser and enter `[IP]:5000` (for example, `192.168.10.50:5000`) in the URL bar to control the robot.  

To access JupyterLab, use `[IP]:8888` (for example, `192.168.10.50:8888`).  

If the robot is not connected to a known WiFi network, it will automatically set up a hotspot named "`AccessPopup`" with the password `1234567890`. You can then use a mobile phone or PC to connect to this hotspot. Once connected, open your browser and enter `192.168.50.5:5000` in the URL bar to control the robot.  

To ensure compatibility with various types of robots running on Raspberry Pi, we utilize a config.yaml file to specify the particular robot being used. You can configure the robot by entering the following command:

    s 22

In this command, the s directive denotes a robot-type setting. The first digit, `2`, signifies that the robot is a `UGV Rover`, with `1` representing `RaspRover` and `3` indicating `UGV Beast`. The second digit, also `2`, specifies the module as `Camera PT`, where `0` denotes `Nothing` and `1` signifies `RoArm-M2`.  

# License
ugv_jetson for the Jetson Orin Nano or Jetson Orin NX: an open source robotics platform for the Jetson Developer Kit.
Copyright (C) 2024 [Waveshare](https://www.waveshare.com/)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
