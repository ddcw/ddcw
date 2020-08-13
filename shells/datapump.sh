#!/bin/env bash
#write by ddcw at 20200810
#gong neng jiu si : sheng cheng zhi xing dao shu ju de bu zhou he jiao ben.

#this script support LANG=en_US.UTF-8 only.
export LANG=en_US.UTF-8

#define variable
begintime=$(date +%s)
dt_f1=$(date +%Y%m%d_%H%M%S)
thisript=$0
PARAMETER_ALL=$@
PARAMETER_FILE="datapumpddcw.par"
current_dir=$(pwd)

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

function help_this_script() {
	echo_color info "sh ${thisript} [PARAMETER.par]|-h|-dir"
	exit 0
}

function muban_par() {
	echo_color info "you can sh ${thisript} ${PARAMETER_FILE}"
	cat << EOF > ${PARAMETER_FILE}
#source db
CONNECT_1=
DIRECTORY_1=
DIRECTORY_OS_1=
JOBNAME_1="JOB${dt_f1}"
PARALLEL_1=2
LOGFILE_1="LOG_${dt_f1}.log"

#destnation db
CONNECT_2=
DIRECTORY_2=
DIRECTORY_OS_2=
JOBNAME_2="JOB${dt_f1}"
PARALLEL_2=2
LOGFILE_2="LOG_${dt_f1}.log"

#Universal config
DUMPFILE="dumpf_${dt_f1}_%U.dump"
TABLES=
REMAP_SCHEMA=
REMAP_TABLESPACE=
#compression=[ ALL, DATA_ONLY, [METADATA_ONLY] and NONE ]
COMPRESSION=


EOF
}

function check_params() {
	[[ -z ${TABLES} ]] && exits "no tables selected. TABLES must be set only. other is sui bian"
	other_var="CONNECT_1 DIRECTORY_1 DIRECTORY_OS_1 CONNECT_2 DIRECTORY_2 DIRECTORY_OS_2 JOBNAME_1 LOGFILE_1 JOBNAME_2 LOGFILE_2 "
	need_number="PARALLEL_1 PARALLEL_2 "

	for i in ${other_var}
	do
		[[ -z $(eval echo \$$i) ]] && export $(echo $i)=$i
	done

	for i in ${need_number}
        do
                #eval hui xian ba bian liang huan chen zhi , zai zhi xing ming ling. ya lei ta lei da zi.
                [ "$(eval echo \$$i)" -eq "$(eval echo \$$i)" ] 2>/dev/null || exits "$i must number"
        done

	[[ -z ${COMPRESSION=} ]] && export COMPRESSION="NONE"
}

function init_first() {
	#mei you pan duan quan xian.
	if [[ -f ${PARAMETER_FILE} ]]
	then
		cd ${current_dir}
		echo_color warn "${PARAMETER_FILE}"
		source ${current_dir}/${PARAMETER_FILE}
		check_params
	else
		echo_color warn "${PARAMETER_FILE} does not exist."
		export PARAMETER_FILE="datapumpddcw.par"
		muban_par
		help_this_script
	fi
}

function create_directory() {
	directory="/u01/expdp"
	directory_name="directory$(date +%Y)"
	expdp_user="expdp$(date +%Y)"
	echo "sqlplus / as sysdba"
	echo "--alter session set container=PDB;"
	echo "create user ${expdp_user} identified by ${expdp_user};"
	echo "grant connect,resource,dba to ${expdp_user};"
	echo "create directory ${directory_name} as '${directory}';"
	echo "grant write,read on directory ${directory_name} to ${expdp_user};"
}

function select_db() {
	tables_detail=$(echo ${TABLES} | sed 's/,/ /g')
	user_table_detail=""
	user_table_index=""
	for i in ${tables_detail}
	do
		users=$(echo $i | awk -F . '{print $1}')
		tables=$(echo $i | awk -F . '{print $2}')
		[[ -z ${user_table_detail} ]] && user_table_detail="(dbse.owner = upper('${users}') and dbse.segment_name = upper('${tables}'))" || user_table_detail="${user_table_detail} \nor (dbse.owner = upper('${users}') and dbse.segment_name = upper('${tables}'))"
		[[ -z ${user_table_index} ]] && user_table_index="(dbi.owner = upper('${users}') and dbi.table_name = upper('${tables}'))" || user_table_index="${user_table_index} \nor (dbi.owner = upper('${users}') and dbi.table_name = upper('${tables}'))"
	done

	echo_color info "--table detail"
	echo "col owner format a15;"
	echo "col segment_name format a30;"
	echo "col partition_name format a20;"
	echo "col segment_type format a25;"
	echo "col tablespace_name format a15;"
	echo "set line 300"
       echo -e "select dbse.owner,
       dbse.segment_name,
       dbse.partition_name,
       dbse.segment_type,
       dbse.tablespace_name,
       dbse.bytes / 1024 / 1024
  from dba_segments dbse
 where ${user_table_detail};"
	echo ''
	echo ''
	echo ''
	echo ''

        echo_color info "--table sum"
        echo "col owner format a15;"
        echo "col segment_name format a30;"
        echo "col partition_name format a20;"
        echo "col segment_type format a25;"
        echo "col tablespace_name format a15;"
        echo "set line 300"
       echo -e "select count(*) TOTAL_TABLE_NUMBER,
	sum(dbse.bytes) / 1024 / 1024 size_MB
  from dba_segments dbse
 where ${user_table_detail};"
        echo ''
        echo ''
        echo ''
        echo ''

	echo_color info "--table index"
	echo "col owner format a15;" 
        echo "col segment_name format a30;" 
        echo "col partition_name format a20;" 
        echo "col segment_type format a25;" 
        echo "col tablespace_name format a15;"
	echo "set line 300"
        echo -e "select dbse.owner,
       dbse.segment_name,
       dbse.partition_name,
       dbse.segment_type,
       dbse.tablespace_name,
       dbse.bytes / 1024 / 1024
  from dba_segments dbse
 where  dbse.segment_name in
       (select dbi.index_name
          from dba_indexes dbi
         where ${user_table_index});"
}

function PARAMS_1() {
	for i in ${PARAMETER_ALL}
	do
		case ${i} in
			-h|-H|-help|-HELP|--h|--H|--help|--HELP|-?|--?|-Help|--Help)
				help_this_script;; 
			dir|-dir|DIR|-DIR)
				export IS_CREATE_DIRECTORY=1;;
			select|-select|SELECT|-SELECT|sel|-sel|SEL|-SEL)
				export IS_SELECT=1;;
			*)
				export PARAMETER_FILE=${i};;
		esac
	done
}


function main_() {
	echo_color info "this is main,"

	echo_color warn "SOURCE DB BEGIN EXPORT WAYS  ---------------------"
	echo_color info "1. you should export data."
	echo ''
	echo -e "\t\t expdp ${CONNECT_1} directory=${DIRECTORY_1} dumpfile=${DUMPFILE} job_name=${JOBNAME_1} logfile=${LOGFILE_1} parallel=${PARALLEL_1} COMPRESSION=${COMPRESSION} tables=${TABLES}\n"
	echo_color info "2. when it finish, you should cp ${DIRECTORY_OS_1}/${DUMPFILE} to destination ${DIRECTORY_OS_2}."
	echo_color warn "SOURCE DB END EXPORT WAYS------------------------"
	echo -e "\n\n\n\n"
	
	echo_color warn "DEST DB IMPORT BEGIN------------------------------"
	echo_color info "there has two ways for import data;"
	echo_color info "FIRST WAY:  "
	echo ''
	echo -e "\t\timpdp ${CONNECT_2} directory=${DIRECTORY_2} dumpfile=${DUMPFILE} job_name=${JOBNAME_2} logfile=${LOGFILE_2} $( [[ -z ${REMAP_SCHEMA} ]] || echo "REMAP_SCHEMA=${REMAP_SCHEMA}" ) $( [[ -z ${REMAP_TABLESPACE} ]] || echo "REMAP_TABLESPACE=${REMAP_TABLESPACE}" ) parallel=${PARALLEL_2} tables=${TABLES} \n
 "
	echo_color info "SECCOND WAY : "
	echo -e "1."
	echo_color warn "DEST DB IMPORT END------------------------------"
}

#[[ -z ${FIRST_PARAMETER} ]] || PARAMS_1
PARAMS_1
init_first
[[ -z ${IS_CREATE_DIRECTORY} ]] || create_directory
[[ -z ${IS_SELECT} ]] || select_db

main_
