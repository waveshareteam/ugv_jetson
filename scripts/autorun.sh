#!/bin/bash
if [ -n "$SUDO_USER" ] || [ -n "$SUDO_UID" ]; then
    echo "This script was executed with sudo."
    echo "Use './autorun.sh' instead of 'sudo ./autorun.sh'"
    exit 1
fi

USER_NAME=$(logname)
USER_HOME=$(eval echo "~$USER_NAME")
SYSTEMD_DIR="$USER_HOME/.config/systemd/user"

APP_PATH="$USER_HOME/ugv_jetson/app.py"
PYTHON_BIN="$USER_HOME/ugv_jetson/ugv-env/bin/python"

mkdir -p "$SYSTEMD_DIR"

APP_SERVICE="$SYSTEMD_DIR/ugv-app.service"
cat > "$APP_SERVICE" <<EOL
[Unit]
Description=UGV Python App
After=sound.target pipewire.service
Wants=pipewire.service

[Service]
ExecStart=/bin/bash -c 'USER_HOME=$(getent passwd %u | cut -d: -f6); \
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu/tegra; \
export PATH=$USER_HOME/ugv_jetson/ugv-env/bin:/usr/local/cuda/bin:$PATH; \
exec $USER_HOME/ugv_jetson/ugv-env/bin/python -u $USER_HOME/ugv_jetson/app.py >> $USER_HOME/ugv_jetson/ugv-app.log 2>&1'
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/%U
Environment="LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu/tegra"
Environment="PATH=/home/jetson/ugv_jetson/ugv-env/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
WorkingDirectory=$USER_HOME/ugv_jetson

[Install]
WantedBy=default.target
EOL

JUPYTER_SERVICE="$SYSTEMD_DIR/ugv-jupyter.service"
cat > "$JUPYTER_SERVICE" <<EOL
[Unit]
Description=UGV Jupyter Notebook

[Service]
ExecStart=/bin/bash -c "$USER_HOME/ugv_jetson/scripts/start_jupyter.sh >> $USER_HOME/ugv_jetson/ugv-jupyter.log 2>&1"
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/%U
WorkingDirectory=$USER_HOME

[Install]
WantedBy=default.target
EOL

systemctl --user daemon-reload
systemctl --user enable ugv-app.service
systemctl --user enable ugv-jupyter.service
sudo loginctl enable-linger $USER_NAME

export PATH=$HOME/.local/bin:$PATH
source "$USER_HOME/ugv_jetson/ugv-env/bin/activate"
CONFIG_FILE="$USER_HOME/.jupyter/jupyter_notebook_config.py"
if [ ! -f "$CONFIG_FILE" ]; then
    jupyter notebook --generate-config
fi

grep -q "c.NotebookApp.token" "$CONFIG_FILE" || echo "c.NotebookApp.token = ''" >> "$CONFIG_FILE"
grep -q "c.NotebookApp.password" "$CONFIG_FILE" || echo "c.NotebookApp.password = ''" >> "$CONFIG_FILE"

echo "Setup complete. You can start services with:"
echo "systemctl --user start ugv-app.service"
echo "systemctl --user start ugv-jupyter.service"
echo "Logs: journalctl --user -u ugv-app.service -f"
echo "      journalctl --user -u ugv-jupyter.service -f"


read -p "Do you want to install ROARM Web App service? [y/N]: " INSTALL_ROARM
INSTALL_ROARM=${INSTALL_ROARM:-N}  

if [[ "$INSTALL_ROARM" =~ ^[Yy]$ ]]; then
    echo "Installing ROARM Web App service..."

    ROARM_SERVICE="$SYSTEMD_DIR/roarm_web_app.service"
    cat > "$ROARM_SERVICE" <<EOL
[Unit]
Description=ROARM Web App
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c "$USER_HOME/roarm_web_app/start_roarm.sh >> $USER_HOME/roarm_web_app/roarm_web_app.log 2>&1"
WorkingDirectory=$USER_HOME/roarm_web_app
Restart=always
RestartSec=5
StartLimitBurst=5
StartLimitIntervalSec=500
KillMode=process
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/bin:/usr/local/bin

[Install]
WantedBy=default.target
EOL

    systemctl --user daemon-reload
    systemctl --user enable roarm_web_app.service

    echo "ROARM Web App service installed and enabled."
    echo "You can start it with: systemctl --user start roarm_web_app.service"
fi