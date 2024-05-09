import os, psutil, time
import subprocess, re, netifaces
import threading
from jtop import jtop

curpath = os.path.realpath(__file__)
thisPath = os.path.dirname(curpath)

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

        self.net_interface = "wlan0"
        self.wlan_ip = "None"
        self.eth0_ip = "None"
        self.wifi_mode = "None"

        self.update_interval = 2

        super(SystemInfo, self).__init__()
        self.__flag = threading.Event()
        self.__flag.clear()

    def get_folder_size(self, folder_path):
        total_size = 0
        for dirpath, dirnames, filenames in os.walk(folder_path):
            for filename in filenames:
                file_path = os.path.join(dirpath, filename)
                total_size += os.path.getsize(file_path)
        # Convert total_size to MB
        size_in_mb = total_size / (1024 * 1024)
        return round(size_in_mb, 2)

    def update_folder_size(self):
        self.pictures_size = self.get_folder_size(self.this_path + '/templates/pictures')
        self.videos_size = self.get_folder_size(self.this_path + '/templates/videos')

    def update_folder(self, input_path):
        self.this_path = input_path
        threading.Thread(target=self.update_folder_size, daemon=True).start()

    def get_info_jtop(self):
        with jtop() as jetson:
            if jetson.ok():
                self.cpu_temp = round(jetson.stats['Temp cpu'], 2)
                self.ram = round(jetson.memory['RAM']['used']/jetson.memory['RAM']['tot']*100, 2)
                self.cpu_load = jetson.stats['CPU1']

    def get_ip_address(self, interface):
        try:
            interface_info = netifaces.ifaddresses(interface)
            ipv4_info = interface_info.get(netifaces.AF_INET, [{}])
            return ipv4_info[0].get('addr')
        except ValueError:
            print(f"Interface {interface} not found.")
            return None
        except IndexError:
            print(f"No IPv4 address assigned to {interface}.")
            return None

    def get_wifi_mode(self):
        if self.wlan_ip == '192.168.50.5':
            return "AP"
        else:
            return "STA"

    def get_signal_strength(self):
        return 0

    def change_net_interface(self, new_interface):
        self.net_interface = new_interface

    def pause(self):
        self.__flag.clear()

    def resume(self):
        self.__flag.set()

    def run(self):
        self.eth0_ip = self.get_ip_address('eth0')
        self.wlan_ip = self.get_ip_address(self.net_interface)
        self.wifi_mode = self.get_wifi_mode()
        self.wifi_rssi = self.get_signal_strength()
        while True:
            self.get_info_jtop()
            self.wifi_rssi = self.get_signal_strength()
            time.sleep(0.5)
            self.wifi_mode = self.get_wifi_mode()
            time.sleep(0.5)
            self.wlan_ip = self.get_ip_address(self.net_interface)
            time.sleep(0.5)
            self.eth0_ip = self.get_ip_address('eth0')
            time.sleep(0.5)
            self.__flag.wait()






if __name__ == "__main__":
    si = SystemInfo()
    # si.update_folder(thisPath)
    si.start()
    si.resume()
    while True:
        # print([si.get_cpu_temperature, si.pictures_size, si.videos_size, si.cpu_load, si.cpu_temp,
        #     si.ram, si.wifi_rssi, si.wifi_mode])
        # print(si.cpu_temp)
        # si.get_memory_percent()

        si.get_signal_strength()

        # with jtop() as jetson:
        #     if jetson.ok():
        #         print(jetson.stats['CPU1'])
        
        time.sleep(3)