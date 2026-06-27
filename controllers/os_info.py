import os, time
import subprocess, re, netifaces
import threading
from jtop import jtop

curpath = os.path.realpath(__file__)
thisPath = os.path.dirname(curpath)

ACCESSPOPUP_STATUS = "/run/accesspopup-status"
AP_PROFILE = "AccessPopup"


class SystemInfo(threading.Thread):
    """docstring for SystemInfo"""
    def __init__(self):
        self.this_path = None

        self.pictures_size = 0
        self.videos_size = 0
        self.cpu_load = 0
        self.cpu_temp = 0
        self.ram = 0
        self.wifi_rssi = 0

        self.eth_interface = "enP8p1s0"
        self.wlan_interface = "wlP1p1s0"
        self.ap_ip = "192.168.50.5"
        self.wlan_ip = None
        self.eth0_ip = None
        self.wifi_mode = "None"

        self.update_interval = 1
        self._load_ap_ip()

        super(SystemInfo, self).__init__()
        self.__flag = threading.Event()
        self.__flag.set()

    def _load_ap_ip(self):
        conf = "/etc/accesspopup.conf"
        if not os.path.isfile(conf):
            return
        try:
            with open(conf, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("ap_ip="):
                        val = line.split("=", 1)[1].strip().strip("'\"")
                        self.ap_ip = val.split("/")[0]
                        break
        except OSError as e:
            print(f"SystemInfo: could not read {conf}: {e}")

    def _read_accesspopup_status(self):
        if not os.path.isfile(ACCESSPOPUP_STATUS):
            return None
        try:
            data = {}
            with open(ACCESSPOPUP_STATUS, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or "=" not in line:
                        continue
                    key, val = line.split("=", 1)
                    data[key.strip()] = val.strip()
            return data or None
        except OSError as e:
            print(f"SystemInfo: could not read {ACCESSPOPUP_STATUS}: {e}")
            return None

    def get_folder_size(self, folder_path):
        total_size = 0
        for dirpath, dirnames, filenames in os.walk(folder_path):
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                total_size += os.path.getsize(file_path)
        size_in_mb = total_size / (1024 * 1024)
        return round(size_in_mb, 2)

    def update_folder_size(self):
        self.pictures_size = self.get_folder_size(self.this_path + '/templates/pictures')
        self.videos_size = self.get_folder_size(self.this_path + '/templates/videos')

    def update_folder(self, input_path):
        self.this_path = input_path
        threading.Thread(target=self.update_folder_size, daemon=True).start()

    def get_ip_address(self, interface):
        try:
            interface_info = netifaces.ifaddresses(interface)
            ipv4_info = interface_info.get(netifaces.AF_INET, [{}])
            return ipv4_info[0].get('addr')
        except (ValueError, IndexError):
            return None

    def _ip_from_nmcli_device(self, interface):
        try:
            out = subprocess.run(
                ['nmcli', '-t', '-f', 'IP4.ADDRESS', 'device', 'show', interface],
                capture_output=True, text=True, timeout=5
            )
            if out.returncode != 0:
                return None
            for line in out.stdout.splitlines():
                if line.startswith('IP4.ADDRESS'):
                    addr = line.split(':', 1)[1].strip()
                    if addr:
                        return addr.split('/')[0]
        except (subprocess.SubprocessError, OSError):
            pass
        return None

    def _ip_from_ip_cmd(self, interface):
        try:
            out = subprocess.run(
                ['ip', '-4', '-o', 'addr', 'show', 'dev', interface],
                capture_output=True, text=True, timeout=3
            )
            if out.returncode != 0:
                return None
            for line in out.stdout.splitlines():
                parts = line.split()
                if len(parts) >= 4 and parts[2] == 'inet':
                    return parts[3].split('/')[0]
        except (subprocess.SubprocessError, OSError):
            pass
        return None

    def _device_ipv4(self, interface):
        for getter in (self._ip_from_nmcli_device, self._ip_from_ip_cmd, self.get_ip_address):
            ip = getter(interface)
            if ip:
                return ip
        return None

    def _active_wifi_connection(self):
        try:
            out = subprocess.run(
                ['nmcli', '-t', '-f', 'GENERAL.CONNECTION', 'device', 'show', self.wlan_interface],
                capture_output=True, text=True, timeout=5
            )
            if out.returncode != 0:
                return None
            for line in out.stdout.splitlines():
                if line.startswith('GENERAL.CONNECTION:'):
                    conn = line.split(':', 1)[1].strip()
                    if conn and conn != '--':
                        return conn
        except (subprocess.SubprocessError, OSError):
            pass
        return None

    def get_wifi_mode(self):
        conn = self._active_wifi_connection()
        if conn == AP_PROFILE:
            return "AP"
        if conn:
            return "STA"

        status = self._read_accesspopup_status()
        if status and status.get("wifi_mode") in ("AP", "STA"):
            return status["wifi_mode"]

        ip = self._ip_from_nmcli_device(self.wlan_interface)
        if ip == self.ap_ip:
            return "AP"
        if ip:
            return "STA"
        return "None"

    def get_wlan_ip(self):
        return self._device_ipv4(self.wlan_interface)

    def get_eth_ip(self):
        return self._device_ipv4(self.eth_interface)

    def get_signal_strength(self):
        if self.wifi_mode == "AP":
            return 0
        try:
            link = subprocess.run(
                ['iw', 'dev', self.wlan_interface, 'link'],
                capture_output=True, text=True, timeout=3
            )
            if link.returncode == 0:
                match = re.search(r'signal:\s*(-?\d+)', link.stdout)
                if match:
                    return int(match.group(1))
        except (subprocess.SubprocessError, OSError):
            pass
        return 0

    def update_network_info(self):
        status = self._read_accesspopup_status()
        if status and status.get("wdev0"):
            self.wlan_interface = status["wdev0"]

        status_ip = status.get("wifi_ip") if status else None
        status_mode = status.get("wifi_mode") if status else None

        self.wifi_mode = self.get_wifi_mode()
        if self.wifi_mode == "None" and status_mode in ("AP", "STA"):
            self.wifi_mode = status_mode

        device_ip = self.get_wlan_ip()

        if self.wifi_mode == "AP":
            self.wlan_ip = device_ip or status_ip or self.ap_ip
        else:
            self.wlan_ip = device_ip or status_ip

        if not self.wlan_ip and status_mode == "AP":
            self.wlan_ip = status_ip or self.ap_ip

        self.eth0_ip = self.get_eth_ip()
        self.wifi_rssi = self.get_signal_strength()

    def change_net_interface(self, new_interface):
        self.wlan_interface = new_interface

    def pause(self):
        self.__flag.clear()

    def resume(self):
        self.__flag.set()

    def _wait_interval(self):
        if not self.__flag.wait(timeout=self.update_interval):
            while not self.__flag.is_set():
                self.__flag.wait()

    def run(self):
        while True:
            self.update_network_info()
            try:
                with jtop() as jetson:
                    while jetson.ok():
                        try:
                            self.cpu_temp = round(jetson.stats.get('Temp cpu', 0), 2)
                            self.cpu_load = jetson.stats.get('CPU1', 0)
                            self.ram = round(
                                jetson.memory['RAM']['used'] /
                                jetson.memory['RAM']['tot'] * 100, 2
                            )
                        except Exception as e:
                            print("SystemInfo jtop error:", e)

                        self._wait_interval()
                        self.update_network_info()
            except Exception as e:
                print("SystemInfo jtop unavailable:", e)
                self._wait_interval()


if __name__ == "__main__":
    si = SystemInfo()
    si.start()
    while True:
        si.update_network_info()
        print(f"mode={si.wifi_mode} ip={si.wlan_ip} conn={si._active_wifi_connection()}")
        time.sleep(2)
