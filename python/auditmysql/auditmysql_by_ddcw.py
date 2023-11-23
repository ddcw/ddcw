from scapy.all import sniff
import datetime
import yaml
import sys,os

def btoint(bdata,t='little'):
	return int.from_bytes(bdata,t)

#定于全局变量
global userinfo
global user_dict
global f

def audit_sql(sql,username):
	sql = sql.strip().lower()
	for x in userinfo[username][1]:
		if sql.startswith(x):
			return True
	return False

def save_pack(pack):
	if hasattr(pack,'load') and len(pack.load) >= 5:
		bdata = pack.load
		ip_port = f"{pack['IP'].src}:{pack['TCP'].sport}"
		if len(bdata) == btoint(bdata[:3])+4: #不支持SSL
			bdata = bdata[4:]
		else:
			return None
		#print(bdata)
		lbdata = len(bdata)
		msg = ''

		if bdata[:1] == b'\x03': #SQL PACK
			if ip_port in user_dict:
				username = user_dict[ip_port]
				sql = bdata[3:].decode()
				if audit_sql(sql,username): #如果符合审计要求,就返回True
					msg = f"[{datetime.datetime.now()}] [{userinfo[username][0]}] [{ip_port}] [{username}] : {sql}\n"
					f.write(msg)
					f.flush()

		elif bdata[:1] == b'\x01':
			if ip_port not in user_dict: #不是需要审计的账号, 就直接跳过
				return None
			username = user_dict[ip_port]
			msg = f"[{datetime.datetime.now()}] [{userinfo[username][0]}] [{ip_port}] [{username}] : DISCONNECT\n"
			#del user_dict[ip_port]
			f.write(msg)
			f.flush()

		elif lbdata > 32 and len(set(bdata[9:32])) == 1: #CONNECT PACK
			username = bdata[32:32+bdata[32:].find(b'\x00')].decode()
			if username not in userinfo: #不是需要审计的账号, 就直接跳过
				return None
			user_dict[ip_port] = username
			msg = f"[{datetime.datetime.now()}] [{userinfo[username][0]}] [{ip_port}] [{username}] : CONNECTING\n"
			f.write(msg)
			f.flush()
		else:
			#print('FAILD...',ip_port)
			pass
			

			

if __name__ == '__main__':
	if len(sys.argv) <= 1:
		print(f'python {sys.argv[0]} xxx.yaml')
		sys.exit(0)

	conf_filename = sys.argv[1]
	if os.path.exists(conf_filename):
		with open(conf_filename, 'r', encoding="utf-8") as f:
			inf_data =  f.read()
		conf = yaml.load(inf_data,Loader=yaml.Loader)
	else:
		print(f'{sys.argv[0]} does not exist')
		sys.exit(1)

	user_dict = conf['GLOBAL']['USER_DICT'] #记录连接和账号对应关系的dict
	userinfo = {} #要审计的账号信息
	for x in conf['CHILD']:
		for username in x['users']:
			userinfo[username] = [x['name'],x['record_begin']]
	f = open(conf['GLOBAL']['FILENAME'],'a')
	sniff(filter=f"dst port {conf['GLOBAL']['INTERFACE_PORT']}", iface=conf['GLOBAL']['INTERFACE_NAME'], prn=save_pack)
