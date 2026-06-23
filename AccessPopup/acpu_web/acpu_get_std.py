#!venv/bin/python3.11
#AccessPopup Webpage Features; 16th April 2026
#Systemd Activation

#Copyright Graeme Richards. RaspberryConnect.com

#Interacts with nmcli to get the status of the networks and update network manager settings.

import subprocess
import usb.core
import usb.util
import sys
import time
import os
import tempfile, shutil
import socket
import threading
import json
import signal

clients = {}  # addr -> conn
server_socket = None
running = True

class NMprofiles:
	"""Gets Network Manager Profile details for Wifi and Eth"""
	def __init__(self):
		self.wifi_profiles=[]
		self.eth_profiles=[]
		self.prof_error=None
		self.profiles=None #ordered list
		self.prof_rtncode=None
		self.__wifi_prof_collector()

	def __get_profiles(self):
		"""Get profile details from nmcli"""
		nm = subprocess.run(['sudo','nmcli','-t','-f','AUTOCONNECT-PRIORITY,TYPE,NAME,ACTIVE,DEVICE','connection'], capture_output=True, text=True, timeout=10)
		if nm.returncode == 0:
			self.prof_error = None
			nmp = nm.stdout.splitlines()
			nmp.sort(reverse=True) #profiles in priority order for connection if more than one in range
			self.profiles = nmp
		else:
			del self.wifi_profiles[:]
			del self.eth_profiles[:]
			self.prof_error = nm.stderr
			self.prof_rtncode = nm.returncode

	def __wifi_prof_collector(self):
		"""Build Wifi profile Details"""
		self.__get_profiles()
		if self.profiles:
			self.wifi_profiles.clear()
			wp = [line  for line in self.profiles if "wireless" in line ] #get wireless profiles
			wp = [i.split(':') for i in wp]
			for extra in wp:
				extra={'type':'wifi','name':extra[2],'autocon':extra[0],'active':extra[3],'device':extra[4]} #profile initial features
				self.wifi_profiles.append(extra)
			for extra in self.wifi_profiles:
				m = self.__profile_details(extra['name'],'w') #capture further details about the profile
				extra.update(m) #join details to profile dict
			self.__eth_prof_collector()
			
	def __eth_prof_collector(self):
		"""Build Ethernet Profile"""
		if self.profiles:
			self.eth_profiles.clear()
			ep = [line  for line in self.profiles if "ethernet" in line ] #get lan profiles
			ep = [i.split(':') for i in ep]
			for e in ep:
				e={'type':'eth','name':e[2],'autocon':e[0],'active':e[3],'devname':e[4]}
				self.eth_profiles.append(e)
			for e in self.eth_profiles:
				m = self.__profile_details(e['name'],'e')
				e.update(m) #join details to profile dict
	
	def __profile_details(self,prof,dev):
		"""Get further profile details"""
		if dev == "w": #further details for Wifi profiles
			ref=('802-11-wireless.ssid:','802-11-wireless.mode:','802-11-wireless.seen-bssids:','ipv4.addresses:','IP4.ADDRESS[1]:','connection.interface-name:') #profiles IP addr, connected IP addr
			refalt={'802-11-wireless.ssid':'ssid','802-11-wireless.mode':'mode','802-11-wireless.seen-bssids':'bssid','ipv4.addresses':'profip','IP4.ADDRESS[1]':'conip','connection.interface-name':'prof-device'}
		elif dev == 'e': #further details for ethernet profiles
			ref=('GENERAL.DEVICES:','GENERAL.STATE:','IP4.ADDRESS[1]:','DHCP4.OPTION[2]:','bridge-port.priority:')
			refalt={'GENERAL.DEVICES':'devname','GENERAL.STATE':'state','IP4.ADDRESS[1]':'conip','DHCP4.OPTION[2]':'macid','bridge-port.priority:':'is_bridge'}	
		det=subprocess.run(['sudo','nmcli','connection','show',prof], capture_output=True, text=True)
		if det.returncode == 0:
			det=det.stdout.splitlines()
			d={}
			for line in det:
				if any(item in line for item in ref):
					x = line.split(':',1)
					if "DHCP4.OPTION[2]:" in line: #eth macid in a different string format
						x[1] = x[1][-20:]
					d[refalt[x[0]]] = x[1].strip()
			return d
	
	def __is_profiles_ready(self):
		if not self.wifi_profiles or not self.eth_profiles:
			self.update()
					
	def update(self):
		"""This will refresh the profiles information"""
		self.__wifi_prof_collector()
		return 0
		#ethernet is checked along with this wifi update
	
	def get_wifi_profiles(self):
		"""Gives the wifi profile details in a list"""
		self.__is_profiles_ready()
		return self.wifi_profiles
			
	def get_eth_profiles(self):
		"""Gives the eth profiles details in a list"""
		self.__is_profiles_ready()
		return self.eth_profiles
		
	def eth_active(self):
		"""List just Ethernet devices that are active"""
		active_list=[]
		for i in self.eth_profiles:
			if i["active"] == "yes":
				active_list.append([i["name"],i["device"]])
				if "macid" in i:
					active_list[0].append(i["macid"])
				else:
					active_list.append("NoMac")
		return active_list
		
	def wifi_active(self,device):
		"""Get the active Wifi Profiles for a given wifi device"""
		active_list=[]
		for i in self.wifi_profiles:
			if i["active"] == "yes" and device == i["device"]:
				active_list.append([i["name"],i["device"],i["ssid"],i["bssid"],i["mode"],i["conip"]])
		return active_list

	def wifi_prof_list(self):
		"""List's the wifi profile names for local network scan comparison"""
		l=[]
		for i in range(len(self.wifi_profiles)):
			if self.wifi_profiles[i]["mode"] == "infrastructure":
				l.append(self.wifi_profiles[i]["name"])
		return l

	def wifi_prof_ssid_list(self):
		"""List the wifi profile SSID's for local network scan"""
		l=[]
		for i in range(len(self.wifi_profiles)):
			if self.wifi_profiles[i]["mode"] == "infrastructure":
				l.append(self.wifi_profiles[i]["ssid"])
		return l
		
	def ap_prof_list(self):
		"""list of AccessPoint profiles"""
		l=[]
		for i in range(len(self.wifi_profiles)):
			if self.wifi_profiles[i]["mode"] == "ap":
				l.append([self.wifi_profiles[i]["name"],self.wifi_profiles[i]["ssid"],self.wifi_profiles[i]["device"],self.wifi_profiles[i]["prof-device"]])
		return l

	def ap_ssid_list(self):
		"""list of AccessPoint profiles"""
		l=[]
		for i in range(len(self.wifi_profiles)):
			if self.wifi_profiles[i]["mode"] == "ap":
				l.append(self.wifi_profiles[i]["ssid"])
		return l

def scanwifi(def_wifi):
	"""get ssid's in range"""
	bss = []
	for w in range(3):
			#scans mutiple times as local SSIDs don't all appears on first scans. Mutiple scans capture additional networks. 
			iwdata = subprocess.run(['sudo','iw','dev',def_wifi,'scan', 'ap-force'], capture_output=True, text=True)
			found_ssid = [line.removeprefix('\tSSID: ') for line in iwdata.stdout.splitlines() if 'SSID:' in line and 'x00' not in line]
			found = [*found_ssid]
			time.sleep(2)
	if found:
		return undup_list(found)
	else:
		return ["iwerror " + iwdata.stderr]
		
def undup_list(self):
	"""Remove Duplicates from List"""
	return list(dict.fromkeys(self))
	
def get_hostname():
	hst = subprocess.run(['sudo','nmcli','general','hostname'],capture_output=True, text=True, timeout=10)
	if hst.returncode == 0:
		return hst.stdout
	else:
		return "Hostname not available"

def create_new_profile(args):
	#Args should be tuple - profile name, password
	if args[0] == 'AP':
		subprocess.run(['sudo','nmcli','connection','down','AccessPopup'])
	x = subprocess.run(['sudo','nmcli' ,'device','wifi','connect',args[0],'password',args[1]])
	if x.returncode == 0:
		subprocess.run(['sudo','nmcli','connection','reload'])
		return 0
	else:
		subprocess.run(['sudo','nmcli','connection','delete',args[0]])
		subprocess.run(['sudo','nmcli','connection','reload'])
		start_nw()
		return 1
	
def delete_profile(profile):
	profs = NMstat.get_wifi_profiles()
	if not any(profile == item["name"] for item in profs):
		return 1 #Profile not found
	result = subprocess.run(['sudo','nmcli', 'connection', 'delete', profile], capture_output=True, text=True)
	if result.returncode != 0:
		print(f"Failed to delete profile '{profile}': {result.stderr.strip()}")
		return 1  # deletion failed
	subprocess.run(['sudo','nmcli','connection','reload'])
	if profile == "AccessPopup": #safety incase AccessPopup is the only profile on the system, so at least some Wifi is available
		start_nw()
	return 0

def edit_nw_profile(self):
	r=0
	x = subprocess.run(['sudo','nmcli','connection','modify',self[0],'wifi-sec.psk',self[1]])
	if x.returncode != 0:
		#password failed, delete profile
		subprocess.run(['sudo','nmcli', 'connection', 'delete', self[0]])
		start_nw()
		r = 1
	subprocess.run(['sudo','nmcli','connection','reload'])
	return r


def edit_accesspopup(self):
	# Edits config in accesspopup.conf
	file_p = self[2]
	new_line = f"{self[0]}'{self[1]}'\n"

	tmp_file_path = None
	try:
		with tempfile.NamedTemporaryFile('w', delete=False) as tmp_file:
			with open(file_p, 'r') as original_file:
				for line in original_file:
					if line.strip().startswith(self[0]):
						tmp_file.write(new_line)
					else:
						tmp_file.write(line)
			tmp_file_path = tmp_file.name

		with open(tmp_file_path, 'rb') as f:
			result = subprocess.run(
				['sudo', 'tee', file_p],
				stdin=f,
				check=False,
				capture_output=True
			)

		if result.returncode != 0:
			return 1

	finally:
		# Clean up the temporary file if it was created
		if tmp_file_path and os.path.exists(tmp_file_path):
			os.remove(tmp_file_path)
	return 0
    
def get_ap_details(self):
    file_p = self
    s = ""
    p = ""
    with open(file_p, 'r') as f:
        for line in f: 
            if line.strip()[:8] == "ap_ssid=":
                s = line[9:-2]
            if line.strip()[:6] == "ap_pw=":
                p = line[7:-2]
    return (s,p)

def start_ap():
	r = 0
	x = subprocess.run(['sudo', '/usr/local/bin/accesspopup','-a'])
	if x.returncode != 0:
		r = 1
	return r
	
def start_nw():
	r = 0
	x = subprocess.run(['sudo','/usr/local/bin/accesspopup'])
	if x.returncode != 0:
		r = 1
	return r
	
def start_selected_nw(prof):
	r = 0
	x = subprocess.run(['sudo','nmcli','connection','up',prof])
	if x.returncode != 0:
		if x == 4:
			delete_profile(prof)
			start_nw()
		elif x == 10:
			start_nw()
		r = 1
	start_nw()
	return r
	
def get_device_names():
	"""All Network device names available """
	d_list = []
	d=subprocess.run(['sudo','nmcli','-t','-f','GENERAL.DEVICE','device','show'],capture_output=True, text=True, timeout=5)
	if d.returncode == 0:
		d1 = d.stdout.splitlines()
		for i in range(len(d1)):
			if d1[i][15:] not in ("lo",""):
				d_list.append(d1[i][15:])
	return d_list

#Messaging
class Messaging:
	def __init__(self):
		self.msg_in = None
		self.msg_out = None
		self.msg_ready = threading.Event()
		
	def send_out(self,code,msg):
		conv = {"code":code,"args":msg}
		m = self.__json_message(conv).encode()
		self.msg_out = m
		self.msg_ready.set() 

	def receive_in(self,msg):
		r = json.loads(msg)
		self.msg_in = r
		self.__code_cmd()

	def __json_message(self,msg_text):
		return json.dumps(msg_text)

	def check_msg_in(self):
		x = None
		if self.msg_in != None:
			x = self.msg_in
			self.msg_in = None
		return x
		
	def check_msg_out(self):
		x = None
		if self.msg_out != None:
			x = self.msg_out
			self.msg_out = None
		return x
	
	def __code_cmd_off(self):
		if self.msg_in != None:
			code = self.msg_in.get("code")
			args = self.msg_in.get("args")
			#print("Received Code", code, "Args",args)
			if code == "HOST": #Hostname
				x = get_hostname()
				self.send_out(code,x)
			elif code == "APPL": #AP_Prof_List
				NMstat.update()
				x = NMstat.ap_prof_list()
				self.send_out(code,x)
			elif code == "LANP": #LAN Profiles
				x = NMstat.get_eth_profiles()
				self.send_out(code,x)
			elif code == "WIOF":
				x = wifi_onoff("OFF")
				self.send_out(code,x)
			else:
				print("Unknown action code",code)
			   
	def __code_cmd(self):
		if self.msg_in == None:
			return
		code = self.msg_in.get("code")
		args = self.msg_in.get("args")
		#print("Received Code", code, "Args",args)
		code_actions = {
			"HOST": lambda: get_hostname(),
			"APPL": lambda: (NMstat.update(), NMstat.ap_prof_list())[1],
			"LANP": lambda: NMstat.get_eth_profiles(),
			"WIAC": lambda: NMstat.wifi_active(args),
			"WIPL": lambda: NMstat.wifi_prof_list(),
			"WISS": lambda: NMstat.wifi_prof_ssid_list(),
			"SCAN": lambda: scanwifi(args),
			"APED": lambda: edit_accesspopup(args),
			"APGT": lambda: get_ap_details(args),
			"DELP": lambda: delete_profile(args),
			"GOAP": lambda: start_ap(),
			"GONW": lambda: start_nw(),
			"UPDT": lambda: NMstat.update(),
			"NWSL": lambda: start_selected_nw(args),
			"ADSL": lambda: create_new_profile(args),
			"EDNW": lambda: edit_nw_profile(args)
			}	
		action = code_actions.get(code)
		if action:
			try:
				x = action()
				#print("__code_cmd Action is :",x)
				self.send_out(code,x)
				#print("For ",x, " the results are ",x)
			except Exception as e:
				print(f"[Error handling {code}]: {e}")
		else:
			print("Unknown action code",code)

def handle_client(conn, addr):
	print(f"[Connected] {addr}")
	clients[addr] = conn
	Comms = Messaging()
	try:
		while True:
			data = conn.recv(1024)
			if not data:
				break
			try:
				Comms.receive_in(data.decode())
				Comms.msg_ready.wait()
				msg = Comms.check_msg_out()
				Comms.msg_ready.clear()

				if msg:
					conn.sendall(msg)
			except Exception:
				pass
	except (ConnectionResetError, BrokenPipeError):
		print(f"[{addr}] Disconnected unexpectedly.")
	finally:
		conn.close()
		clients.pop(addr, None)
		print(f"[Cleanup] {addr}")

def shutdown_handler(signum, frame):
	global running
	print("\n[Server] Caught termination signal. Shutting down...")
	running = False
	
	if server_socket:
		server_socket.close()
	
	for addr, conn in list(clients.items()):
		try:
			conn.shutdown(socket.SHUT_RDWR)
		except Exception:
			pass
		conn.close()

def server():
	global server_socket

	with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
		s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
		s.bind(('127.0.0.1', 65432))
		s.listen()
		server_socket = s
		print("[Server] Listening on port 65432...")

		while running:
			try:
				s.settimeout(1.0)
				conn, addr = s.accept()
				threading.Thread(target=handle_client, args=(conn, addr)).start()
			except socket.timeout:
				continue
			except OSError:
				break  # Socket closed
		
if __name__ == "__main__":
	NMstat = NMprofiles()
	signal.signal(signal.SIGTERM, shutdown_handler)  # Handle `systemctl stop`
	signal.signal(signal.SIGINT, shutdown_handler)   # Handle Ctrl+C (manual test)
	server_thread = threading.Thread(target=server)
	server_thread.start()
	try:
		while running:
			time.sleep(1)
	finally:
		server_thread.join()
