#!/bin/bash

# python -m venv --system-site-packages ugv-env
# sudo usermod -aG dialout $USER
# pip install pyserial flask flask_socketio aiortc
# pip install opencv-python imutils mediapipe imageio
# pip install pygame pyttsx3 jupyterlab jupyterlab-widgets jupyterlab-pygments jupyter

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo."
    echo "Use 'sudo ./setup.sh' instead of './setup.sh'"
    echo "Exiting..."
    exit 1
fi

# Default value for using other source
use_index=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -i|--index)
      use_index=true
      shift
      ;;
    *)
      # Unknown option
      echo "Usage: $0 [-i | --index] (to use other source)"
      exit 1
      ;;
  esac
done

echo "Updating package list..."
sudo apt update

# Install required software
echo "# Install required software."
sudo apt update
sudo apt upgrade -y
sudo apt install -y libopenblas-dev libatlas3-base libcamera-dev python3-opencv portaudio19-dev
sudo apt install -y util-linux procps hostapd iproute2 iw haveged dnsmasq iptables espeak
# sudo apt install -y python3.10-venv

# disable serial login
sudo systemctl stop nvgetty
sudo systemctl disable nvgetty
sudo udevadm trigger

# install jupyterlab
sudo apt install -y nodejs npm
sudo pip install jupyter jupyterlab
sudo pip3 install -U jetson-stats
sudo -H pip3 install -U jetson-stats

sudo apt install -y python3-venv python3-pip build-essential python3-dev


echo "# Create a Python virtual environment."
# Create a Python virtual environment 
cd $PWD
python -m venv --system-site-packages ugv-env

echo "# Activate a Python virtual environment."

echo "# Install dependencies from requirements.txt"
# Install dependencies from requirements.txt
if $use_index; then
  sudo -H -u $USER bash -c 'source $PWD/ugv-env/bin/activate && pip install --upgrade setuptools pip && pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt && deactivate'
else
  sudo -H -u $USER bash -c 'source $PWD/ugv-env/bin/activate && pip install --upgrade setuptools pip && pip install -r requirements.txt && deactivate'
fi

echo "# Add current user to group so it can use serial."
sudo usermod -aG dialout $USER

# Audio Config
# echo "# Audio Config."
# sudo cp -v -f /home/$(logname)/ugv_jetson/asound.conf /etc/asound.conf

echo "Setup completed. Please to reboot your Jetson for the changes to take effect."

echo "Use the command below to run app.py onboot."

echo "sudo chmod +x autorun.sh"

echo "./autorun.sh"
