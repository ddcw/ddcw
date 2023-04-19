#归档  压缩   加密
import struct
from threading import Thread
import os
import zlib
import json

def get_dirs_files(dirname,followlinks=False):#followlinks:True 递归访问符号连接
	dirs = []
	files = []
	for rootname,dirlist,filelist in os.walk(dirname):
		dirs += [ os.path.join(rootname,name) for name in dirlist ]
		files += [ os.path.join(rootname,name) for name in filelist ]
	dirs = set(dirs)
	files = set(files)
	return list(dirs),list(files),[ os.path.getsize(x) for x in files ]

#list/set 转二进制对象(str就2字节表示大小, int就统统8字节)
def list_to_bin(data,isstr=True):
	bdata = b''
	if isstr:
		for x in data:
			bdata += struct.pack('<H',len(x))+x.encode()
	else:
		for x in data:
			bdata += struct.pack('<Q',x)
	return bdata

def bin_to_list(bdata,isstr=True):
	data = []
	lbdata = len(bdata)
	i = 0
	if isstr:
		while i < lbdata:
			dl = struct.unpack('<H',bdata[i:i+2])[0]
			i += 2
			data.append(bdata[i:i+dl].decode())
			i += dl
	else:
		formatpack = f'<{int(lbdata/8)}Q'
		data = struct.unpack(formatpack,bdata)
	return data

#加密: 可以使用之前写的加密工具 https://cloud.tencent.com/developer/article/2256534
def encrypt(bdata,password):
	bdata = bytearray(bdata)
	password = bytearray(password)
	lbdata = len(bdata)
	lpassword = len(password)
	for x in range(lbdata):
		bdata[x] ^= password[x%lpassword]
	return bdata

#这里我就偷懒了, 直接用xor -_- ..
def decrypt(bdata,password):
	return encrypt(bdata,password)


#压缩
def compress(bdata):
	return zlib.compress(bdata)

#解压
def uncompress(bdata):
	return zlib.decompress(bdata)

class archce(object):
	def __init__(self,filename,target,password=None):
		"""
		parameter 0  压缩后的文件名
		parameter 1  要压缩或者解压的目录(多个目录就使用list/set)
		parameter 2  加密/解密的密码
		每个文件拆分成N个block(加密压缩)后存储
		HEADER: header_size:4byte   total_size:8byte   block_size:4byte  crc32:1byte  encryption:1byte fast_extract:8byte file_dir:obj
		BODY: body_size:8byte    block:   datasize:4byte(不含fileid和blockid)   fileid:4byte  blockid:4byte  data #block_id*block_size = offset
		FOOTER: [(fileid,(offset))]  #快速恢复
		"""
		self.filename = filename
		self.target = target
		self.password = password
		#self.encryption = False #默认不使用加密
		self.encryption = True if password is not None else False #有密码就加密
		self.block_size = 256*1024*1024  #默认每个块256MB 最大支持4GB(32bit)
		self.crc32 = False #懒得整crc校验了....
		self.compress = True #默认启用压缩
		self.parallel = 4 #并发
		self.fast_extract = True #快速解压,  就是在文件末尾存储 文件和相关的位置....
		self.FORCE = False

	def get_files(self):
		dirs,files,filesize = [],[],[]
		if isinstance(self.target,list) or isinstance(self.target,tuple):
			for name in self.target:
				if os.path.exists(name):
					if os.path.isfile(name):
						files += [name]
						continue
					if os.path.isdir(name):
						dirs += [name]
					a,b,c = get_dirs_files(name)
					dirs += a
					files += b
					filesize += c
				else:
					if self.FORCE:
						print(f'{name} dose not exists. and will continue')
					else:
						print(f'{name} dose not exists.')
						exit(2)
			dirs,files,filesize = list(set(dirs)), list(set(files)), list(set(filesize))
		else:
			dirs,files,filesize = get_dirs_files(self.target)
		return dirs,files,filesize

	def archive(self): #归档
		#header
		dirs,files,filesize = self.get_files()
		self.file_list = files
		if os.path.exists(self.filename) and not self.FORCE:
			return f'{self.filename} exist.'
		total_size = sum(filesize)
		block_size = self.block_size
		compr = 1 if self.compress else 0
		encryption = 1 if self.encryption else 0
		fast_extract = 0
		bdirs = list_to_bin(dirs)
		bfiles = list_to_bin(files)
		bfilesize = list_to_bin(filesize,False)

		if compr == 1:
			bdirs = compress(bdirs)
			bfiles = compress(bfiles)
			bfilesize = compress(bfilesize)
		if encryption == 1:
			bdirs = encrypt(bdirs,str(self.password).encode())
			bfiles = encrypt(bfiles,str(self.password).encode())
			bfilesize = encrypt(bfilesize,str(self.password).encode())

		header = struct.pack('<QLBBQLLLQ',total_size,block_size,compr,encryption,fast_extract,len(bdirs),len(bfiles),len(bfilesize),0) #留了8字节来记录body size
		header += bdirs + bfiles + bfilesize
		header = struct.pack('<L',len(header)) + header
		
		with open(self.filename,'wb') as f:
			f.write(header)

		_tmp_files = [ (x,files[x]) for x in range(len(files)) ]
		#f = open(self.filename,'ab')
		pc = {}
		for x in range(self.parallel):
			pc[x] = Thread(target=self.work0,args=(x,self.filename,block_size,compr,encryption,_tmp_files))
		for x in range(self.parallel):
			pc[x].start()
		for x in range(self.parallel):
			pc[x].join()
		#print('complete')
		#f.close()
		total_file_size = os.path.getsize(self.filename)
		if self.fast_extract: 
			footer = {}
			with open(self.filename,'rb') as f:
				header_size = struct.unpack('<L',f.read(4))[0]
				header = f.read(header_size)
				#print(header_size)
				while True:
					_tdata = f.read(12)
					if _tdata == b'':
						break
					filesize,fileid,blockid = struct.unpack('<LLL',_tdata)
					if fileid not in footer:
						footer[fileid] = []
					footer[fileid].append((blockid,f.tell(),filesize))
					f.seek(filesize,1)
					if f.tell() == total_file_size:
						break
			f = os.open(self.filename, os.O_WRONLY|os.O_CREAT)
			os.lseek(f, 18, 0)
			os.write(f,struct.pack('<Q',total_file_size))
			os.fsync(f)
			os.close(f)
			footer = json.dumps(footer).encode()
			with open(self.filename,'ab') as f:
				f.write(footer)
			print('write footer complete')
			#return footer,total_file_size

	def work0(self,x,filename,block_size,compr,encryption,_tmp_files):
		f = open(filename,'ab')
		while True:
			try:
				_fileid,_filename = _tmp_files.pop()
				print(f'Process {x} archive file {_filename}')
			except Exception as e:
				#print(e)
				break
			_tf = open(_filename,'rb')
			_block_id = 0 #block_id
			while True:
				_bdata = _tf.read(block_size)
				if _bdata == b'' and _block_id != 0: #空文件也记录下
					break
				if compr == 1:
					_bdata = compress(_bdata)
				if encryption == 1:
					_bdata = encrypt(_bdata,str(self.password).encode())
				_lbdata = len(_bdata)
				_bdata = struct.pack('<LLL',_lbdata, _fileid, _block_id,) + _bdata
				status = f.write(_bdata)
				#print(f'{x} {_block_id} {status} wirte OK')
				_block_id += 1
			_tf.close()
		f.close()
		

	def extract(self):
		if not isinstance(self.target,str):
			return f'{self.target} must be str'
		total_size,block_size,compr,encryption,dirs,files,filesize,_footer = self.file_header()
		self.file_list = files
		_footer = [ [x,_footer[x]] for x in _footer ]
		if encryption == 1 and self.password is None:
			return False
		for x in dirs:
			print(f'create dir {x}')
			#os.makedirs(x,exist_ok=self.FORCE)
			os.makedirs(x,exist_ok=True)
		pc = {}
		for x in range(self.parallel):
			pc[x] = Thread(target=self.work1,args=(x,_footer,block_size,compr,encryption,)) #filename: files[_footer[n][0]]  offset:files[_footer[n][1]]
		for x in range(self.parallel):
			pc[x].start()
		for x in range(self.parallel):
			pc[x].join()
		
	def work1(self,x,_footer,block_size,compr,encryption,):
		_f = open(self.filename,'rb')
		while True:
			try:
				fileid,file_detail = _footer.pop()
				filename = self.file_list[int(fileid)]
				print(f'write file {filename}')
			except:
				return
			with open(filename,'wb') as f:
				for x in file_detail:
					loffset = x[0]*block_size
					_offset = x[1]
					_filesize = x[2]
					_f.seek(_offset,0)
					bdata = _f.read(_filesize)
					if encryption == 1:
						bdata = decrypt(bdata,str(self.password).encode())
					if compr == 1:
						bdata = uncompress(bdata)
					f.seek(loffset,0)
					f.write(bdata)
					
		_f.close()

	def file_header(self):
		if not os.path.exists(self.filename):
			return f'no file {self.filename}'
		with open(self.filename,'rb') as f:
			header_size = struct.unpack('<L',f.read(4))[0]
			total_size,block_size,compr,encryption,fast_extract,lbdirs,lbfiles,lbfilesize,bodysize = struct.unpack('<QLBBQLLLQ',f.read(8+4+1+1+8+4+4+4+8))
			dirs = f.read(lbdirs)
			files = f.read(lbfiles)
			filesize = f.read(lbfilesize)
			if encryption == 1:
				dirs = decrypt(dirs,str(self.password).encode())
				files = decrypt(files,str(self.password).encode())
				filesize = decrypt(filesize,str(self.password).encode())
			if compr == 1:
				dirs = uncompress(dirs)
				files = uncompress(files)
				filesize = uncompress(filesize)
			dirs = bin_to_list(dirs)
			files = bin_to_list(files)
			filesize = bin_to_list(filesize,False)
			if fast_extract > 0:
				f.seek(fast_extract,0)
				_footer = json.loads(f.read().decode())
			else:
				_footer = None
		return total_size,block_size,compr,encryption,dirs,files,filesize,_footer

