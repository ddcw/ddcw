#!/usr/bin/env bash
#write by ddcw @https://github.com/ddcw
#mysql_config_editor的shell版, 不用再交互了. 支持加密解密~/.mylogin.cnf
#用法: 
#解密 sh mysql_config_editor.sh decode ~/.mylogin.cnf 
#加密 sh mysql_config_editor.sh encode ~/.mylogin.cnf /tmp/t20240305_out.txt

#/tmp/t20240305_out.txt 格式如下:
aa='
[root]
user = "root"
password = "123456"
host = "127.0.0.1"
port = 3314
socket = "/data/mysql_3314/run/mysql.sock"
'


OP=$1    #操作, 只有decode, encode
BFILE=$2 #二进制文件, 就是.mylogin.cnf
TFILE=$3 #文本文件 

tmpfile1="/tmp/.tmpfileformysql_config_editorbyddcw1" #临时文件, 用于中间交互数据的.
tmpfile2="/tmp/.tmpfileformysql_config_editorbyddcw2" #临时文件,保存结果数据的

# 输入: 二进制密钥的十六进制字符串形式
# 输出: aes key 放到 tmpfile2
realkey() {
	keyhex=$1 # 传入的是二进制密钥的十六进制字符串形式
	
	# 初始化一个空的十六进制字符串表示的密钥
	rkey_hex=""
	for (( i=0; i<16; i++ )); do
		rkey_hex+="00"
	done
	
	for (( i=0; i<${#keyhex}; i+=2 )); do
		byte_hex=${keyhex:$i:2}
		dec_val=$((16#$byte_hex))
		index=$((i/2%16))
		index_hex_start=$((index*2))
		rkey_byte_hex=${rkey_hex:$index_hex_start:2}
		
		rkey_byte_dec=$((16#$rkey_byte_hex))
		xor_byte_dec=$((rkey_byte_dec^dec_val))
		
		rkey_hex=$(printf "%s%.2x%s" "${rkey_hex:0:$index_hex_start}" "$xor_byte_dec" "${rkey_hex:$index_hex_start+2}")
	done
	echo $rkey_hex > ${tmpfile2}
}

#从 ${BFILE} start读n字节到 ${tmpfile2}
readsize(){
	start=$1
	size=$2
	dd if=${BFILE} bs=1 skip=${start} count=${size} of=${tmpfile2} 2>/dev/null
}

#读hex
readhex(){
	start=$1
	size=$2
	readsize ${start} ${size}
	dd if=${BFILE} bs=1 skip=${start} count=${size} 2>/dev/null | od -An -tx1 | tr -d '\n ' | sed ':a;N;$!ba;s/\n//g' > ${tmpfile2}
}

#读int32
readuint32(){
	start=$1
	size=4
	od -An -t u4 -j ${start} -N ${size} ${BFILE} | awk '{print $1}' > ${tmpfile2}
}

openssl_decode(){
	key=$1
	hex_string=$2
	: > ${tmpfile1}
	for (( i=0; i<${#hex_string}; i+=2 )); do
		byte="\\x${hex_string:$i:2}"
		printf "$byte" >> "${tmpfile1}"
	done
	openssl enc -aes-128-ecb -d -K  ${key} -in ${tmpfile1} -out ${tmpfile2}

}

openssl_encode(){
	key=$1  #HEX
	hex_string=$2
	: > ${tmpfile2}
	: > ${tmpfile1}
	for (( i=0; i<${#hex_string}; i+=2 )); do
		byte="\\x${hex_string:$i:2}"
		printf "$byte" >> "${tmpfile1}"
	done
	printf '\n' >> "${tmpfile1}" #要换行, 不然识别不了
	openssl enc -aes-128-ecb -K  ${key} -in ${tmpfile1} -out ${tmpfile2}
}

write_hex(){
	hex_string=$1
	filename=$2
	for (( i=0; i<${#hex_string}; i+=2 )); do
		byte="\\x${hex_string:$i:2}"
		printf "$byte" >> ${filename}
	done
	
}

write_int32(){
	int_value=$1
	printf "\\x$(printf '%08x' $int_value | cut -c7-8)" >> ${BFILE}
	printf "\\x$(printf '%08x' $int_value | cut -c5-6)" >> ${BFILE}
	printf "\\x$(printf '%08x' $int_value | cut -c3-4)" >> ${BFILE}
	printf "\\x$(printf '%08x' $int_value | cut -c1-2)" >> ${BFILE}
}

encode(){
	#echo -e "${TFILE} --> ${BFILE}"
	: > ${BFILE}
	key=$(head -c 20 /dev/urandom | od -v -A n -t x1 | tr -d ' \n ')
        realkey ${key}
        real_key=`cat ${tmpfile2}`
	#写个0 填充
	write_int32 0
	write_hex ${key} ${BFILE}
	
	#循环处理TFILE文件了
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [ -z "$line" ]; then
			continue #跳过空行
		fi
		byte_count=$(echo -n "$line" | wc -c)   #实际大小
		((byte_count++))
		value=$(echo -n "$line" | od -v -A n -t x1 | tr -d ' \n')
		pad_len=$(( (byte_count/ 16 + 1) * 16 )) #进1
		write_int32 ${pad_len}  #写大小 4bytes
		openssl_encode ${real_key} ${value}  #写数据
		cat ${tmpfile2} >> ${BFILE}

	done < ${TFILE}
	echo "FINISH. FILENAME: ${BFILE}"
	chmod 600 ${BFILE}
}

decode(){
	echo ""
	#echo -e "${BFILE} --> ${TFILE}"
	#: > ${TFILE}
	offset=4 #开始4字节不管了
	readhex ${offset} 20
	offset=$[ ${offset} + 20 ]
	realkey `cat ${tmpfile2}`
	real_key=`cat ${tmpfile2}`
	#echo "real_key" ${real_key}
	maxsize=`stat -c "%s" ${BFILE}`
	while [ 1 -eq 1 ];do
		#echo "OFFSET START: ${offset}"
		readuint32 ${offset} 4
		offset=$[ ${offset} + 4 ]
		keysize=`cat ${tmpfile2}`
		#echo "SIZE: ${keysize}"
		if [ "${keysize}" == "" ] || [ ${offset} -ge ${maxsize} ];then
			break
		fi
		readhex ${offset} ${keysize}
		offset=$[ ${offset} + ${keysize} ]
		hexstring=`cat ${tmpfile2}`
		#echo "real_key: ${real_key}   hexstring: ${hexstring}"
		openssl_decode "${real_key}" "${hexstring}"
		#cat ${tmpfile2} >> ${TFILE}
		cat ${tmpfile2}
		#echo "OFFSET STOP: ${offset}"
	done
	#cat ${TFILE}
	echo ""
	
}
if [ "${OP^^}" == "DECODE" ];then
	if [ ! -f ${BFILE} ];then
		echo "${BFILE} not exists"
		exit 1
	fi
	decode
elif [ "${OP^^}" == "ENCODE" ];then
	if [ ! -f ${TFILE} ];then
		echo "${TFILE} not exists"
		exit 1
	fi
	if [ -f ${BFILE} ];then
		mv ${BFILE} /tmp/.mylogin.cnf.backbyddcw_`date +%s` #存在的话, 就备份一手, 免得操作有问题
	fi
	encode
else
	echo "unknown ${@}"
fi
