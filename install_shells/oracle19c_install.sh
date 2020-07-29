#!/bin/env bash
#write by ddcw at 20200717 first
#offical url https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/index.html
#this script only install oracle after complete Check_ENV_ORACLE. So you should check ENV first ,of course you can run install_shells/CheckOracleENV20200328_19C.sh to set ENV
#scriptName: oracle19c_install.sh

#change log
#2020728 add main,zhu yao gong neng dou shi jin tian xie da. sai guo li hai tie ya zi da.

#this script support LANG=en_US.UTF-8 only.
export LANG=en_US.UTF-8

#define variable
begintime=`date +%s`
dt=$(date +%Y%m%d-%H%M%S)
PARAMS=$@
current_pwd=`pwd`
thisript=$0



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
      echo "INTERNAL ERROR: echo_color KEY VALUE"
      ;;
  esac
}

function su_command(){
	rpm -q expect >/dev/null 2>&1 || exits "this OS has not expect, so rootpassword is invalid"
        user=root
        commd=$1
        password=${rootpassword}
        expect << EOF
        set timeout 30
        spawn su ${user} -c "${commd}"
        expect {
                        "(yes/no" {send "yes\r";exp_continue}
                        "assword:" {send "${password}\r"}
        }
        expect "${user}@*" {send "exit\r"}
        expect eof
EOF
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
	export  INVENTORY_LOCATION_DIR=${ORACLE_BASE%/*}/oraInventory
	export  LISTENER_NAMES="LISTENER"
	export  LISTENER_PORT=1521
	export  ORACLE_SID=$(hostname)
	export  DB_UNIQUE_NAME=${ORACLE_SID}
	export  DB_NAME=${ORACLE_SID}
	export  gdbName=${DB_NAME}
	export  characterSet="AL32UTF8"
	export  open_cursors=1000
	export  processes=3000
	export  EMPORT=5500
	export  pdbName=${ORACLE_SID}pdb
	export  ORADATA=${ORACLE_BASE}/oradata
	export  sysPassword=${ORACLE_SID}
	export  systemPassword=${ORACLE_SID}
	export  pdbAdminPassword=${ORACLE_SID}

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
	echo_color info "check ENV ${ENV_variable}"
	for i in ${ENV_variable}
	do
		env | grep ${i}= >/dev/null 2>&1 || exits "current ENV has not ${i} , you should set it and run again."
	done
	
	#get oracle19c software , or exit
	echo_color info "find software"
	[[ -z ${ORACLE_SOFTWARE} ]] && export ORACLE_SOFTWARE=$(find / -name ${ORACLE_SOFTWARE_NAME} 2>/dev/null | head -1)
	[[ -z ${ORACLE_SOFTWARE} ]] && exits "no software ${ORACLE_SOFTWARE_NAME}"
	echo_color info "ORACLE_SOFTWARE  ${ORACLE_SOFTWARE}"

	#check SPACE 
	echo_color info  "check SPACE about  ${ORACLE_HOME} ${ORACLE_BASE} /tmp"
	[[ $(du -s ${ORACLE_HOME} | awk '{print $1}') -gt 10000 ]] && exits "maybe oracle has install, ${ORACLE_HOME} is not null "
	[[ $(df -P ${ORACLE_HOME} | tail -1 | awk '{print $(NF-2)}') -lt 8000000 ]] && exits "${ORACLE_HOME} size too little, must > 8GB"
	[[ $(df -P ${ORACLE_BASE} | tail -1 | awk '{print $(NF-2)}') -lt 13000000 ]] && exits "${ORACLE_HOME} size too little, must > 13GB"
	[[ $(df -P /tmp | tail -1 | awk '{print $(NF-2)}') -gt 1500000 ]] || exits '/tmp must greate 1.5G'


	#sga size
	[ "${SGA_TARGET}" -lt "800" ] && exits "sga_target ${SGA_TARGET} is too small, needs to be at least 784M"

	#check directories
	[[ $(wc -l ${ASROOT_RUN} | awk '{print $1}') -gt 1 ]] && exits "you should mkdir some of directories and to grant authorization . just like ${ASROOT_RUN}"

	#check number: porcess,cursor,sga,pga,listener,emport....
	need_number="open_cursors processes EMPORT LISTENER_PORT"
	echo_color info "check ${need_number} IS NUMBER"
	for i in ${need_number}
	do
		#eval hui xian ba bian liang huan chen zhi , zai zhi xing ming ling. ya lei ta lei da zi.
		[ "$(eval echo \$$i)" -eq "$(eval echo \$$i)" ] 2>/dev/null || exits "$i must number"
	done
	
	#chekc params NOT NULL:DB_NAME gdbName ORACLE_SID ORACLE_HOME ORACLE_BASE INVENTORY_LOCATION_DIR ORADATA characterSet open_cursors processes PGA_AGGREGATE_TARGET SGA_TARGET LISTENER_PORT sysPassword systemPassword pdbAdminPassword
	need_NOT_NULL="DB_NAME gdbName ORACLE_SID ORACLE_HOME ORACLE_BASE INVENTORY_LOCATION_DIR ORADATA characterSet open_cursors processes PGA_AGGREGATE_TARGET SGA_TARGET LISTENER_PORT sysPassword systemPassword pdbAdminPassword"
	echo_color info "check ${need_NOT_NULL} is valid"
	for i in ${need_NOT_NULL}
	do
		[[ "$(eval echo \$$i)" == "$(eval echo \$$i)" ]] 2>/dev/null || exits "$i must NOT NULL"
	done
	echo_color info "CHECK FINISH"
}

function mkdir_authorization() {
	#make need directories, if rootPassword=XXXX, su_command mkdir and  chown
	need_dir="${ORACLE_HOME} ${ORACLE_BASE} ${BASE_INSTALL_DIR} ${INVENTORY_LOCATION_DIR}"
	echo_color info "make directories : ${need_dir}"
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
	echo_color info "unzip ${ORACLE_SOFTWARE} -d ${ORACLE_HOME}"
	unzip -q ${ORACLE_SOFTWARE} -d ${ORACLE_HOME}
}

function check_PACK() {
	#compat-libstdc++-33 maybe no use
	#nfs-utils only for Oracle ACFS
	#net-tools for RAC and Clusterware
	noinstall_pack=""
	need_packs="unzip bc binutils compat-libcap1 compat-libstdc++-33 glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi libXtst libXrender libXrender-devel libgcc libstdc++ libxcb make smartmontools sysstat"
	echo_color info "check pack : ${need_packs}"
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
		[[ -z ${rootpassword} ]] || su_command "yum -y install ${noinstall_pack}" || return 1
	fi
}

#config dbinstall.rsp
function init_db_install_rsp() {
	echo_color info "${BASE_INSTALL_DIR}/db_install.rsp"
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
	echo_color info "init ${BASE_INSTALL_DIR}/netca.rsp"
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
	echo_color info "init ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp"
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
	echo_color info "init ${BASE_INSTALL_DIR}/dbca.rsp"
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
	echo_color info "install db software"
	ps -ef | grep "${BASE_INSTALL_DIR}/db_install.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1
	echo '' > ${BASE_INSTALL_DIR}/db_install.log
	tail -f ${BASE_INSTALL_DIR}/db_install.log &
	$ORACLE_HOME/runInstaller  -ignorePrereq  -silent -noconfig -force -responseFile  ${BASE_INSTALL_DIR}/db_install.rsp >${BASE_INSTALL_DIR}/db_install.log
	while true
	do
		if grep "Successfully Setup Software" ${BASE_INSTALL_DIR}/db_install.log >/dev/null 2>&1
		then
			echo_color info "oracle software install finish."
			echo '' > ${ASROOT_RUN}
			echo "cp ${ORACLE_BASE}/oraInventory/orainstRoot.sh ${ORACLE_BASE}/oraInventory/orainstRoot.sh.bak${dt}" >> ${ASROOT_RUN}
			echo "sh ${ORACLE_BASE}/oraInventory/orainstRoot.sh" >> ${ASROOT_RUN}
			echo "cp ${ORACLE_HOME}/root.sh ${ORACLE_HOME}/root.sh.bak${dt}" >> ${ASROOT_RUN}
			echo "sh ${ORACLE_HOME}/root.sh" >> ${ASROOT_RUN}
			if [[ -z ${rootpassword} ]]
			then
				echo_color warn "you should run script as root\n${ORACLE_BASE}/oraInventory/orainstRoot.sh\n${ORACLE_HOME}/root.sh. you can run like ${ASROOT_RUN}"
			else
				su_command "sh ${ASROOT_RUN}"
			fi
			break
		else
			sleep 10
		fi
	done
	ps -ef | grep "${BASE_INSTALL_DIR}/db_install.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1
}

#install netca
function install_netca() {
	echo_color info "install listener"
	${ORACLE_HOME}/bin/netca -silent -responsefile ${BASE_INSTALL_DIR}/netca.rsp > ${BASE_INSTALL_DIR}/netca.log
}

#install dbca
function install_dbca() {
	echo_color info "create database"
	
	#write at 20191204 wriet, so to do write again
	echo -e "you can visit \033[1;41;33m`ls -t $ORACLE_BASE/cfgtoollogs/dbca/${DB_NAME}/trace.log_* | head -1`\033[0mto known more"

	ps -ef | grep "${BASE_INSTALL_DIR}/dbca.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1
	echo '' > ${BASE_INSTALL_DIR}/dbca.log
	tail -f ${BASE_INSTALL_DIR}/dbca.log &
	if [[  -z ${NOPDB}  ]]
	then
		${ORACLE_HOME}/bin/dbca -silent -createDatabase  -responseFile ${BASE_INSTALL_DIR}/dbca.rsp > ${BASE_INSTALL_DIR}/dbca.log
	else
		${ORACLE_HOME}/bin/dbca -silent -createDatabase  -responseFile ${BASE_INSTALL_DIR}/dbca_NOPDB.rsp > ${BASE_INSTALL_DIR}/dbca.log
	fi
	ps -ef | grep "${BASE_INSTALL_DIR}/dbca.log" | grep -v grep | awk '{print $2}' | xargs -t -i kill -9 {} >/dev/null 2>&1
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

        grep "define" ${ORACLE_HOME}/sqlplus/admin/glogin.sql >/dev/null 2>&1  || echo -e "define _editor='vi'" >> ${ORACLE_HOME}/sqlplus/admin/glogin.sql
        grep "sqlprompt" ${ORACLE_HOME}/sqlplus/admin/glogin.sql >/dev/null 2>&1 || echo  set sqlprompt "_user'@'_connect_identifier> " >> ${ORACLE_HOME}/sqlplus/admin/glogin.sql
        grep "linesize" ${ORACLE_HOME}/sqlplus/admin/glogin.sql >/dev/null 2>&1  || echo -e '''set linesize 100 pagesize 50''' >> ${ORACLE_HOME}/sqlplus/admin/glogin.sql
        grep stty ~/.bash_profile >/dev/null 2>&1 || echo "stty erase ^H" >> ~/.bash_profile

	$ORACLE_HOME/bin/sqlplus / as sysdba << EOF >> ${BASE_INSTALL_DIR}/sqlplus_set_parameters.log
ALTER PROFILE default LIMIT PASSWORD_LIFE_TIME UNLIMITED;
EOF

	[[ -z ${NOPDB} ]] && $ORACLE_HOME/bin/sqlplus / as sysdba << EOF  >> ${BASE_INSTALL_DIR}/sqlplus_set_parameters.log
alter pluggable database ${pdbName} save state;
alter session set container=${pdbName};
ALTER PROFILE default LIMIT PASSWORD_LIFE_TIME UNLIMITED;
EOF
}

#help this script
function help_this_script() {
	echo_color info "you can visit https://github.com/ddcw/ddcw to known more"
	echo_color red  "------------------------sh ${thisript} [PARAMETER=VALUE] ...------------------------"
	echo_color red "------------------------CURRENT VALUES ------------------------"
	need_print_value="DB_NAME gdbName pdbName ORACLE_SID ORACLE_HOME ORACLE_BASE INVENTORY_LOCATION_DIR ORACLE_SOFTWARE_NAME ORADATA characterSet open_cursors processes PGA_AGGREGATE_TARGET SGA_TARGET LISTENER_PORT EMPORT sysPassword systemPassword pdbAdminPassword "
	for i in ${need_print_value}
	do
		eval echo "$i=\$$i"
	done
	echo_color red "------------------------      END      ------------------------"
	echo_color info "TIPS:  characterSet : AL32UTF8 ZHS16GBK"
	exit 0
	
}

#to config user set variable
function configUSERset() {
	for i in ${PARAMS}
	do
		param=`echo $i | awk -F "=" '{print $1}'`
		value=`echo $i | awk -F "=" '{print $2}'`
		case ${param} in
			ORACLE_SID|SID|oracle_sid|sid)
				export ORACLE_SID=${value}
				;;
			pdbName|pdbname|PDBNAME|PdbName)
				export pdbName=${value}
				;;
			DB_NAME|dbname|dbName|DBname)
				export DB_NAME=${value}
				;;
			DB_UNIQUE_NAME)
				export DB_UNIQUE_NAME=${value}
				;;
			characterSet|characterset|CHARACTERSET|ZFJ|zfj)
				export characterSet=${value}
				;;
			processes|Processes|PROCESSES)
				export processes=${value}
				;;
			open_cursors|OPEN_CURSORS|OPENCURSORS|opencursors)
				export open_cursors=${value}
				;;
			gdbName|gdbname|GDBNAME|GloableName|GLOABLENAME|gloablename)
				export gdbName=${value}
				;;
			pga_aggregate_target|PGA|pga|PGA_AGGREGATE_TARGET)
				export PGA_AGGREGATE_TARGET=%${value}
				;;
			sga_target|sga|SGA|SGA_TARGET)
				export SGA_TARGET=${value}
				;;
			sysPassword|syspassword|SYSPASSWORD|sys|SYS|sysPW|SYSPW)
				export sysPassword=${value}
				;;
			systemPassword|systempassword|systemPW|SYSTEMPASSWORD|SYSTEMPW)
				export systemPassword=${value}
				;;
			pdbAdminPassword|pdbadmin|pdbpassword|PDBPW|PDBPASSWORD)
				export pdbAdminPassword=${value}
				;;
			p|password|pw|-p|PW|pw|passwd|PASSWD|passWD|PASSWORD)
				export sysPassword=${value}
				export systemPassword=${value}
				export pdbAdminPassword=${value}
				;;
			h|-h|--h|help|-help|--help|HELP|--HELP)
				export HELP_FLAG=1
				;;
			ORADATA|dbdir|datafile_dir|dd)
				ORADATA=${value}
				;;
			rootpassword|Root|root|ROOT|rootP|ROOTPASSWORD|RP|rp|-rootpasswd|-rootpassword)
				export rootpassword=${value}
				;;
			INVENTORY_LOCATION_DIR)
				export INVENTORY_LOCATION_DIR=${value}
				;;
			IGNORE_PACK|ignore_pack|Ignore_pack|Ignore_Pack)
				export IGNORE_PACK=${value}
				;;
			EMPORT|emport|Emport)
				export EMPORT=${value}
				;;
			LISTENER_NAMES|listener_names|LISTENER_NAME)
				export LISTENER_NAMES=${value}
				;;
			ORACLE_SOFTWARE_NAME)
				export ORACLE_SOFTWARE_NAME=${value}
				;;
			LISTENER_PORT|listener_port|Listener_port)
				export LISTENER_PORT=${value}
				;;
			ORACLE_SOFTWARE)
				export ORACLE_SOFTWARE=${value}
				;;
			NOPDB)
				export NOPDB=${value}
				;;
			ORACLE_HOME)
				export ORACLE_HOME=${value}
				;;
			ORACLE_BASE)
				export ORACLE_BASE=${value}
				;;
			*)
				export HELP_FLAG=1
				;;
		esac
	done
}

#to judge rootpassword
function judge_rootpassword() {
	su_command "touch /tmp/.flag_rootpassword_${begintime}"	
	[[ -f /tmp/.flag_rootpassword_${begintime} ]] || exits "root password is wrong"
}

#this is main,ko no DIO da
function main_() {
	init_parameter
	configUSERset
	[[ -z ${HELP_FLAG} ]] || help_this_script
	[[ -z ${rootpassword} ]] || judge_rootpassword
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

	endtime=`date +%s`
	costm=`echo ${begintime} ${endtime} | awk '{print ($2-$1)/60}'`
	echo_color info "\nsysPassword=${sysPassword}"
	echo_color info "systemPassword=${systemPassword}"
	echo_color info "pdbAdminPassword=${pdbAdminPassword}\n"
	echo -e "\n\033[1;41;33m `date +%Y%m%d-%H:%M:%S` cost ${costm} minutes\033[0m"
}
main_
