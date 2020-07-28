#!/bin/env bash
#write by ddcw at 20200717 first
#offical url https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/index.html
#this script only install oracle after complete Check_ENV_ORACLE. So you should check ENV first ,of course you can run install_shells/CheckOracleENV20200328_19C.sh to set ENV
#scriptName: oracle19c_install.sh

#change log
#2020728 add main,zhu yao gong neng dou shi jin tian xie da. sai guo li hai tie ya zi da.

#define variable
begintime=`date +%s`
dt=$(date +%Y%m%d-%H%M%S)
PARAM=$@
current_pwd=`pwd`



#run this function and exit with $2
function exits(){
  echo -e "[`date +%Y%m%d-%H:%M:%S`] \033[31;40m$1\033[0m"
  [ -z $2 ] && exit $2
  exit 1
}

function echo_color() {
  case $1 in
    green)
      echo -e "\033[32;40m$2\033[0m"
      ;;
    red)
      echo -e "\033[31;40m$2\033[0m"
      ;;
    error|erro|ERROR|E|e)
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
    *)
      echo "Example: echo_color red string"
      ;;
  esac
}

#bak file function, bak_file FILENAME but abandonmented
function bak_file() {
  [ -d ~/bak_file ] || mkdir ~/bak_file
  filename=`echo $1 |sed 's/\//_/g'`
  cp -f $1 ~/bak_file/${filename}_${dt}
}


#init user set params
function init_parameter() {
	export	ORACLE_BASE=${ORACLE_BASE%*/}
	export	ORACLE_HOME=${ORACLE_HOME%*/}
	export	CURRENT_USER=$(id | awk -F uid= '{print $2}' | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
	export	CURRENT_USER_GROUP=$(id | awk -F gid= '{print $2}' | awk -F '(' '{print $2}' | awk -F ')' '{print $1}')
	export  INVENTORY_LOCATION_DIR=${ORACLE_BASE%/*}
	export  LISTENER_NAMES="LISTENER"
	export  LISTENER_PORT=1521
	export  ORACLE_SID=$(hostname)
	export  DB_UNIQUE_NAME=${ORACLE_SID}
	export  DB_NAME=${ORACLE_SID}
	export  characterSet="AL32UTF8"
	export  open_cursors=1000
	export  processes=3000
	export  EMPORT=5500

	export ORACLE_SOFTWARE_NAME="LINUX.X64_193000_db_home.zip"
	
	[[ -z ${BASE_INSTALL_DIR} ]] && export BASE_INSTALL_DIR="/usr/local/oracle19c"
	export  ASROOT_RUN="/tmp/.asrootRunscript.sh"
	echo '' > ${ASROOT_RUN} || exits "current user cant use /tmp or full"

	#pga_size MB
	export PGA_AGGREGATE_TARGET=$(cat /proc/meminfo | grep MemTotal | awk '{print $2/1024/5*2/4}' | awk -F . '{print $1}')
	#sga_size MB
	export SGA_TARGET=$(cat /proc/meminfo | grep MemTotal | awk '{print $2/1024/5*2/4*3}' | awk -F . '{print $1}')

}

#check env for install oracle, such as space,kernel params,software....
function check_env() {
	#check ENV variable
	ENV_variable="ORACLE_HOME ORACLE_BASE ORACLE_HOSTNAME ORACLE_SID"
	for i in ${ENV_variable}
	do
		env | grep ${i}= >/dev/null 2>&1 || exits "current ENV has not ${i} , you should set it and run again."
	done
	
	#get oracle19c software , or exit
	[[ -z ${ORACLE_SOFTWARE} ]] && export ORACLE_SOFTWARE=$(find / -name ${ORACLE_SOFTWARE_NAME} 2>/dev/null | head -1)
	[[ -z ${ORACLE_SOFTWARE} ]] && exits "no software ${ORACLE_SOFTWARE_NAME}"

	#check SPACE 
	[[ $(du -s ${ORACLE_HOME} | awk '{print $1}') -gt 10000 ]] && exits "maybe oracle has install, ${ORACLE_HOME} is not null "
	[[ $(df -P ${ORACLE_HOME} | tail -1 | awk '{print $(NF-2)}') -lt 8000000 ]] && exits "${ORACLE_HOME} size too little, must > 8GB"
	[[ $(df -P ${ORACLE_BASE} | tail -1 | awk '{print $(NF-2)}') -lt 13000000 ]] && exits "${ORACLE_HOME} size too little, must > 13GB"
	[[ $(df -P /tmp | tail -1 | awk '{print $(NF-2)}') -gt 1500000 ]] || exits '/tmp must greate 1.5G'


	#sga size
	[ "${SGA_TARGET}" -lt "800" ] && exits "sga_target ${SGA_TARGET} is too small, needs to be at least 784M"

	#check directories
	[[ $(wc -l ${ASROOT_RUN} | awk '{print $1}') -gt 1 ]] && exits "you should mkdir some of directories and to grant authorization . just like ${ASROOT_RUN}"

}

function mkdir_authorization() {
	#make need directories, if rootPassword=XXXX, su_command mkdir and  chown
	need_dir="${ORACLE_HOME} ${ORACLE_BASE} ${BASE_INSTALL_DIR} ${INVENTORY_LOCATION_DIR}"
	if [[ -z ${rootpassword} ]]
	then
		for i in ${need_dir}
		do
			mkdir -p $i || echo "mkdir -p $i" >> ${ASROOT_RUN}
			touch ${i}/.flag_judge_Authority && rm -rf ${i}/.flag_judge_Authority || echo "chown -R ${CURRENT_USER}:${CURRENT_USER_GROUP} $i" >> ${ASROOT_RUN}
		done
	else
		for i in ${need_dir}
		do
			su_command "mkdir -p ${i}"
			su_command "chown -R ${CURRENT_USER}:${CURRENT_USER_GROUP} $i"
		done
	fi
}

function unzip_to_ORACLE_HOME() {
	unzip -q ${ORACLE_SOFTWARE} -d ${ORACLE_HOME}
}

function check_PACK() {
	#compat-libstdc++-33 maybe no use
	#nfs-utils only for Oracle ACFS
	#net-tools for RAC and Clusterware
	noinstall_pack=""
	need_packs="unzip bc binutils compat-libcap1 compat-libstdc++-33 glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi libXtst libXrender libXrender-devel libgcc libstdc++ libxcb make smartmontools sysstat"
	for i in ${need_packs}
	do
		rpm --query --queryformat "%{NAME}" $i >/dev/null 2>&1 || noinstall_pack="${noinstall_pack} $i"
	done
	if [[ -z ${noinstall_pack} ]] 
	then
		echo_color info "check software successful, will continue...."
		return 0
	else
		echo_color warn "${noinstall_pack} is not install , you should install then and run again , or use IGNORE_PACK=1 to force run script"
		[[ -z ${rootpassword} ]] && su_command "yum -y install ${noinstall_pack}" || return 1
	fi
}

#config dbinstall.rsp
function init_db_install_rsp() {
	cat << EOF > ${BASE_INSTALL_DIR}/db_install.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=${CURRENT_USER_GROUP}
INVENTORY_LOCATION=${INVENTORY_LOCATION_DIR}
ORACLE_BASE=${ORACLE_BASE}
ORACLE_HOME=${ORACLE_HOME}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=true
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.ConfigureAsContainerDB=false
oracle.install.db.config.starterdb.memoryOption=false
oracle.install.db.config.starterdb.installExampleSchemas=false
oracle.install.db.config.starterdb.managementOption=DEFAULT
oracle.install.db.config.starterdb.omsPort=0
oracle.install.db.config.starterdb.enableRecovery=false
EOF
}

#config netca.rsp
function init_netca_rsp() {
	cat << EOF > ${BASE_INSTALL_DIR}/netca.rsp
[GENERAL]
RESPONSEFILE_VERSION="19.0"
CREATE_TYPE="CUSTOM"
[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"${LISTENER_NAMES}"}
LISTENER_PROTOCOLS={"TCP;${LISTENER_PORT}"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;${LISTENER_PORT}"}

EOF
}

#config dbca.rsp
function init_dbca_rsp() {
	#when NOPDB=1 dbca will use dbca_NOPDB.rsp, other sids use dbca.rsp.
	#for study will has two dbca reponse file.
	cat << EOF > ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v19.0.0
gdbName=${gdbName}
sid=${ORACLE_SID}
databaseConfigType=SI
policyManaged=false
createServerPool=false
force=false
createAsContainerDatabase=false
numberOfPDBs=0
useLocalUndoForPDBs=true
templateName=${ORACLE_HOME}/assistants/dbca/templates/New_Database.dbt
systemPassword=${systemPassword} 
sysPassword=${sysPassword}
pdbAdminPassword=${pdbAdminPassword}
emConfiguration=DBEXPRESS
emExpressPort=${EMPORT}
runCVUChecks=FALSE
omsPort=0
dvConfiguration=false
olsConfiguration=false
datafileDestination=${ORADATA}/{DB_UNIQUE_NAME}/
storageType=FS
characterSet=${characterSet}
nationalCharacterSet=AL16UTF16
registerWithDirService=false
listeners=${LISTENER_NAMES}
variables=ORACLE_BASE_HOME=${ORACLE_HOME},DB_UNIQUE_NAME=${DB_UNIQUE_NAME},ORACLE_BASE=${ORACLE_BASE},PDB_NAME=,DB_NAME=${DB_NAME},ORACLE_HOME=${ORACLE_HOME},SID=${ORACLE_SID}
initParams=undo_tablespace=UNDOTBS1,sga_target=${SGA_TARGET}MB,db_block_size=8192BYTES,nls_language=AMERICAN,dispatchers=(PROTOCOL=TCP) (SERVICE=${ORACLE_SID}XDB),diagnostic_dest={ORACLE_BASE},control_files=("${ORADATA}/{DB_UNIQUE_NAME}/control01.ctl", "${ORADATA}/{DB_UNIQUE_NAME}/control02.ctl"),remote_login_passwordfile=EXCLUSIVE,audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,processes=${processes},pga_aggregate_target=${PGA_AGGREGATE_TARGET}MB,nls_territory=AMERICA,local_listener=LISTENER_${ORACLE_SID},open_cursors=${open_cursors},compatible=19.0.0,db_name=${DB_NAME},audit_trail=none
sampleSchema=false
memoryPercentage=40
databaseType=MULTIPURPOSE
automaticMemoryManagement=false
totalMemory=0
EOF
	#with PDBS , pdbName=  initParams=enable_pluggable_database=true
	cat << EOF > ${BASE_INSTALL_DIR}/dbca.rsp
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v19.0.0
gdbName=${gdbName}
sid=${ORACLE_SID}
databaseConfigType=SI
policyManaged=false
createServerPool=false
force=false
createAsContainerDatabase=false
numberOfPDBs=1
pdbName=${pdbName}
useLocalUndoForPDBs=true
templateName=${ORACLE_HOME}/assistants/dbca/templates/New_Database.dbt
systemPassword=${systemPassword} 
sysPassword=${sysPassword}
pdbAdminPassword=${pdbAdminPassword}
emConfiguration=DBEXPRESS
emExpressPort=${EMPORT}
runCVUChecks=FALSE
omsPort=0
dvConfiguration=false
olsConfiguration=false
datafileDestination=${ORADATA}/{DB_UNIQUE_NAME}/
storageType=FS
characterSet=${characterSet}
nationalCharacterSet=AL16UTF16
registerWithDirService=false
listeners=${LISTENER_NAMES}
variables=ORACLE_BASE_HOME=${ORACLE_HOME},DB_UNIQUE_NAME=${DB_UNIQUE_NAME},ORACLE_BASE=${ORACLE_BASE},PDB_NAME=,DB_NAME=${DB_NAME},ORACLE_HOME=${ORACLE_HOME},SID=${ORACLE_SID}
initParams=undo_tablespace=UNDOTBS1,enable_pluggable_database=true,sga_target=${SGA_TARGET}MB,db_block_size=8192BYTES,nls_language=AMERICAN,dispatchers=(PROTOCOL=TCP) (SERVICE=${ORACLE_SID}XDB),diagnostic_dest={ORACLE_BASE},control_files=("${ORADATA}/{DB_UNIQUE_NAME}/control01.ctl", "${ORADATA}/{DB_UNIQUE_NAME}/control02.ctl"),remote_login_passwordfile=EXCLUSIVE,audit_file_dest={ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump,processes=${processes},pga_aggregate_target=${PGA_AGGREGATE_TARGET}MB,nls_territory=AMERICA,local_listener=LISTENER_${ORACLE_SID},open_cursors=${open_cursors},compatible=19.0.0,db_name=${DB_NAME},audit_trail=none
sampleSchema=false
memoryPercentage=40
databaseType=MULTIPURPOSE
automaticMemoryManagement=false
totalMemory=0
EOF
}

#install oracle software only
function install_db_software() {
	echo install dbinstall
	$ORACLE_HOME/runInstaller  -silent -ignoreSysPrereqs  -ignorePrereq  -showProgress -responseFile  ${BASE_INSTALL_DIR}/db_install.rsp >${BASE_INSTALL_DIR}/db_install.log
}

#install netca
function install_netca() {
	echo install netca
	${ORACLE_HOME}/bin/netca -silent -responsefile ${BASE_INSTALL_DIR}/netca.rsp > ${BASE_INSTALL_DIR}/netca.log
}

#install dbca
function install_dbca() {
	echo dbca
	if [[ ${NOPDB} -eq 1 ]]
	then
		${ORACLE_HOME}/bin/dbca -silent -createDatabase  -responseFile ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp > ${BASE_INSTALL_DIR}/dbca.log
	else
		${ORACLE_HOME}/bin/dbca -silent -createDatabase  -responseFile ${BASE_INSTALL_DIR}/dbca.rsp > ${BASE_INSTALL_DIR}/dbca.log
	fi
}

#install post, clear, start_stop,backup
function set_clearFS() {
	echo "to be continued"
}

function set_start_stop() {
	#this script is too old, need to rewrite
        [ -d ~/scripts/  ] || mkdir ~/scripts/
        startup_txt="
#!/bin/env bash\n
lsnrctl start >/dev/null 2>&1\n
sqlplus / as sysdba <<EOF\n
startup\n
alter pluggable database all open;\n
EOF\n
"
        echo -e ${startup_txt} > ~/scripts/oracle_start.sh
        chmod +x  ~/scripts/oracle_start.sh
        sed -i 's/^\s*//' ~/scripts/oracle_start.sh
        stop_txt="
#!/bin/env bash\n
lsnrctl stop >/dev/null 2>&1\n
sqlplus / as sysdba <<EOF\n
shutdown immediate\n
EOF\n
"
        echo -e ${stop_txt} > ~/scripts/oracle_stop.sh
        chmod +x  ~/scripts/oracle_stop.sh
        sed -i 's/^\s*//' ~/scripts/oracle_stop.sh
echo_color info "set  ~/scripts/oracle_stop.sh ~/scripts/oracle_start.sh finish"
echo_color info "start: ~/scripts/oracle_start.sh"
echo_color info "stop: ~/scripts/oracle_stop.sh"

}


function set_Backup() {
	echo "to be continued..."
}

function isntall_post() {
	set_clearFS
	set_start_stop
	set_Backup
}

#help this script
function help_this_script() {
	echo help
}

#to config user set variable
function configUSERset() {
	echo hhee
}

#this is main,ko no DIO da
function main_() {
	echo main	
	init_parameter
	configUSERset
	mkdir_authorization
	[[ ${IGNORE_PACK} -eq 1 ]] ||  check_PACK
	check_env
	unzip_to_ORACLE_HOME

	init_db_install_rsp
	init_netca_rsp
	init_dbca_rsp

	install_db_software
	install_netca
	install_dbca
	
	isntall_post
	
}
main_
