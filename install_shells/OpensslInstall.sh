#!/usr/bin/env bash
#write by ddcw at 2021.10.06
#本脚本采用源码编译安装openssl的方式. 

#openssl下载地址: https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz

#使用方法:  sh OpensslInstall.sh [openssl-1.0.2u.tar.gz]
#如果未指定openssl包的话, 会在当前目录[深度 1]自动寻找openssl源码包, 如果当前没得, 但是能wget的话, 也会wget下载的.

OPENSSL_TAR=$1

stty erase ^H
export LANG="en_US.UTF-8"
export dt=$(date +%s)
umask 0022

#run this function and exit with $2
exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] || exit $2
  exit 1
}

echo_color() {
  detaillog1=$3
  [[ -z ${detaillog1} ]] && detaillog1=${details}
  case $1 in
    green)
      echo -e "\033[32;40m$2\033[0m"
      ;;
    red)
      echo -e "\033[31;40m$2\033[0m"
      ;;
    error|err|erro|ERROR|E|e)
      echo -e "[\033[1;5;41;33mERROR\033[0m `date +%Y%m%d-%H:%M:%S`] \033[1;41;33m$2\033[0m"
      ;;
    redflicker)
      echo -e "\033[1;5;41;33m$2\033[0m"
      ;;
    info|INFO|IF|I|i)
      echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m$2\033[0m"
      ;;
    highlightbold)
      echo -e "\033[1;41;33m$2\033[0m"
      ;;
    warn|w|W|WARN|warning)
      echo -e "[\033[31;40mWARNNING\033[0m `date +%Y%m%d-%H:%M:%S`] \033[31;40m$2\033[0m"
      ;;
    detail|d|det)
      echo -e "[\033[32;40mINFO\033[0m `date +%Y%m%d-%H:%M:%S`] \033[32;40m$2\033[0m"
      echo "[`date +%Y%m%d-%H:%M:%S`] $2" >> ${detaillog1}
      ;;
    n|null)
      echo -e "$2"
      ;;
    *)
      echo "INTERNAL ERROR: echo_color KEY VALUE"
      ;;
  esac
}

help_this() {
	echo "sh $0 openssl-1.0.2u.tar.gz"
	exit 2
}

yumddcw() {
        export PACKT_TYPE="yum"
        which apt >/dev/null 2>&1 && which dpkg >/dev/null 2>&1 && PACKT_TYPE="apt"
        which zypper >/dev/null 2>&1 && which rpm >/dev/null 2>&1 && PACKT_TYPE="zypper"
        packages1=$@
        case ${PACKT_TYPE,,} in
                yum)
                        yum -y ${packages1} >/dev/null 2>&1 || echo_color warn "mysqlbe install ${packages1} failed ( yum -y ${packages1} )"
                        ;;
                apt)
                        packages1=$(echo ${packages1} | sed 's/zlib-devel/zlib1g-dev/')
                        packages1=$(echo ${packages1} | sed 's/zlib&/zlib1g/')
                        packages1=$(echo ${packages1} | sed 's/libaio&/libaio1/')
                        packages1=$(echo ${packages1} | sed 's/openssl-libs&/libssl1.0.0/')
                        apt -y ${packages1} >/dev/null 2>&1 || echo_color warn "mysqlbe install ${packages1} failed ( apt -y $packages1 )"
                        ;;
                zypper)
                        zypper -n ${packages1} >/dev/null 2>&1 || echo_color warn "mysqlbe install ${packages1} failed ( zypper -n ${packages1} )"
                        ;;
                *)
                        echo_color err "内部错误 001"
                        ;;
        esac
}

INSTALL_DIR="/usr/local/opensslddcw"
PLATFORM=$(uname -m)
mkdir -p /tmp/ddcw
[[ -f ${OPENSSL_TAR} ]] || export OPENSSL_TAR=$(ls openssl-*.*.*.tar.* -tr 2>/dev/nul | tail -n 1)
[[ ! -f ${OPENSSL_TAR} ]] && which wget >/dev/null 2>&1 && ping www.openssl.org -c 1 >/dev/null 2>&1 && echo_color info "wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz" && wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz && OPENSSL_TAR="openssl-1.0.2u.tar.gz"
if [[ -f ${OPENSSL_TAR} ]] ;then
	yumddcw install zlib-devel
	yumddcw install gcc
	echo_color info "开始解压 ${OPENSSL_TAR} ..."
	openssl_name=$(tar -xvf ${OPENSSL_TAR}) || exits "解压失败: tar -xvf ${OPENSSL_TAR}"
	echo ${openssl_name%%/*} | grep openssl-1.0 >/dev/null 2>&1 && ldconfig -p | grep libssl.so.10 >/dev/null 2>&1 && exits "libssl.so.10已存在, 不需要继续安装openssl(${openssl_name%%/*})"
	[[ -d ${INSTALL_DIR} ]] && echo_color warn "安装目录(${INSTALL_DIR})已经存在, 将替换掉" && mv ${INSTALL_DIR} /tmp/ddcw/${INSTALL_DIR##*/}_${dt}
	cd ${openssl_name%%/*}
	echo_color info "解压完成,开始编译安装..(${INSTALL_DIR})"
	./config shared zlib  --prefix=${INSTALL_DIR} >/dev/null 2>&1 && make -j `grep processor /proc/cpuinfo | wc -l` >/dev/null 2>&1 && make install >/dev/null 2>&1
	echo_color info "安装完成. 开始创建软连接.."
	if [[ -d /usr/lib64 ]];then
		[[ ! -f /usr/lib64/libssl.so.10 ]] && ln -s ${INSTALL_DIR%/}/lib/libssl.so.1.0.0 /usr/lib64/libssl.so.10
		[[ ! -f /usr/lib64/libcrypto.so.10 ]] && ln -s ${INSTALL_DIR%/}/lib/libcrypto.so.1.0.0 /usr/lib64/libcrypto.so.10
	elif [[ -d /usr/lib ]]; then
		[[ ! -f /usr/lib/${PLATFORM}-linux-gnu/libssl.so.10 ]] && ln -s ${INSTALL_DIR%/}/lib/libssl.so.1.0.0 /usr/lib/${PLATFORM}-linux-gnu/libssl.so.10
		[[ ! -f /usr/lib/${PLATFORM}-linux-gnu/libcrypto.so.10 ]] && ln -s ${INSTALL_DIR%/}/lib/libcrypto.so.1.0.0 /usr/lib/${PLATFORM}-linux-gnu/libcrypto.so.10
	else
		grep  "${INSTALL_DIR%/}/lib" /etc/ld.so.conf >/dev/null 2>&1 || echo "${INSTALL_DIR%/}/lib" >> /etc/ld.so.conf
	fi
	ldconfig >/dev/null 2>&1
	
	echo_color info "软连接创建完成,请校验. ( ldconfig -p | grep libssl.so )"
else
	echo_color error "请指定openssl包"
	help_this
fi
