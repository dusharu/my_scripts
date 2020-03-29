#!/bin/bash
# shellcheck disable=SC2012
################################################################################
#                                                                              #
#                            Backup mysql db                                   #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.06.17 #
################################################################################
# script must run on mysql SLAVE node
# script used /root/.my.cnf for connect mysql
# script on SLAVE must be same as script on MASTER

######################### VAR #########################
declare -a DB_LIST
declare -a DB_SKIP_LIST
DB_SKIP_LIST=("performance_schema" "information_schema")
DB_MASTER_FQDN="<mysql.example.com>"

BACKUP_DIR="/mnt/backup_dir/db_backup"
DAY_EVERYMONTH_BACKUP=10
MAX_MOUNTH_BACKUP=12
MAX_DAY_BACKUP=31
declare -a MYSQLDUMP_OPT MYSQLDUMP_EXTRA_OPT
MYSQLDUMP_OPT=( --add-drop-database --routines --lock-all-tables )
MASTER=FALSE

############### EXIT CODE
ERROR_CANT_CONNECT_TO_MYSQL=100
ERROR_BACKUP_DIR_DOESNT_WRITABLE=101
ERROR_CANT_SET_PERMISSIONS_TO_BACKUP_DIR=102
ERROR_CANT_READ_MYCNF=103
ERROR_SLAVE_BROKEN=104
ERROR_SLAVE_BEHIND_MASTER_MORE_THAN_1_DAY=105
ERROR_CANT_GET_IP_HOST=106
ERROR_CANT_GET_IP_DB_MASTER=107
ERROR_CANT_GET_IP_DB_MASTER=108

ERROR_RUN_ON_MASTER=200
######################### FUNCTION #########################
function SendEmail {
  EMAIL="<amdmin_email>"
  BOT_EMAIL="<bot_email>"
  echo -e "$@" | mail -a "From: $BOT_EMAIL" -s "$(hostname):$0" $EMAIL
}

function CheckErrorCode {
  # $1 - Error code
  # $2 - Text for mail
  # $3 - Exit with ERROR CODE
  if [[ $1 -ne 0 ]]; then
    SendEmail "$2"
    if [[ -n $3 ]]; then
      exit "$3"
    fi
  fi
}

function CheckBackupDir {
  # $1 - BACKUP_DIR
  # Need VAR: ERROR_BACKUP_DIR_DOESNT_WRITABLE and ERROR_CANT_SET_PERMISSIONS_TO_BACKUP_DIR
  # Need Function: SendEmail CheckErrorCode
  BACKUP_DIR="$1"
  mkdir -p "$BACKUP_DIR"
  if [[ ! -w $BACKUP_DIR ]]; then
    SendEmail "$BACKUP_DIR doesn't writable "
    exit "$ERROR_BACKUP_DIR_DOESNT_WRITABLE"
  else
    chown root:root "$BACKUP_DIR"
    CheckErrorCode $? "Can't set owner:group to backup dir - $BACKUP_DIR" "$ERROR_CANT_SET_PERMISSIONS_TO_BACKUP_DIR"
    chmod 750 "$BACKUP_DIR"
    CheckErrorCode $? "Can't set permissions 750  to backup dir - $BACKUP_DIR" "$ERROR_CANT_SET_PERMISSIONS_TO_BACKUP_DIR"
  fi
}

######################### MAIN #########################

############### Check
if [[ ! -r /root/.my.cnf ]]; then
  SendEmail "Can't read /root/.my.cnf. Exit."
  exit "$ERROR_CANT_READ_MYCNF"
fi

CheckBackupDir "$BACKUP_DIR"

IP_INTERFACES="$(ip ro |grep -m1 default |awk '{print $5}')"
CheckErrorCode "$?" "Can't get default route inetrfaces from Host" "$ERROR_CANT_GET_INTERFACES_HOST"
IP_HOST="$(ip -4 add show dev "${IP_INTERFACES}" | grep -m1 inet  |awk '{print $2}' |sed -e 's#/.*$##g' )"
CheckErrorCode $? "Can't get IP from Host" $ERROR_CANT_GET_IP_HOST
IP_DB_MASTER=$(host ${DB_MASTER_FQDN} |awk '{print $4}')
CheckErrorCode "$?" "Can't get IP master DB" "$ERROR_CANT_GET_IP_DB_MASTER"
if [[ "${IP_HOST}" == "${IP_DB_MASTER}" ]]; then
  # if you want run script on master delete --lock-all-tables from mysqldump options
  #SendEmail "$0 run on MASTER. Exit."
  MASTER=TRUE
else
  MYSQL_SLAVE_STATUS="$(mysql -e 'SHOW SLAVE STATUS\G')"
  CheckErrorCode $? "can't connect to mysql" $ERROR_CANT_CONNECT_TO_MYSQL

  CHECK_SLAVE_DOUBLE_YES=$( echo "${MYSQL_SLAVE_STATUS}" |grep -c -e "Slave_IO_Running: Yes" -e "Slave_SQL_Running: Yes")
  if [[ $CHECK_SLAVE_DOUBLE_YES -ne 2 ]]; then
    SendEmail "$0 - SLAVE broken. Exit."
    exit $ERROR_SLAVE_BROKEN
  fi

  SECOND_BEHIND_MASTER=$(echo "${MYSQL_SLAVE_STATUS}"| awk '/Seconds_Behind_Master:/ {print $2}')
  if [[ $SECOND_BEHIND_MASTER -ge 86400 ]]; then
    SendEmail "SLAVE BEHIND MASTER >= 1day(86400sec). You can use Yesterday backup. Exit."
    exit $ERROR_SLAVE_BEHIND_MASTER_MORE_THAN_1_DAY
  fi
fi
############### Prepare Backup Infrastructure
if [[ $((10#$(date +%d))) -eq $DAY_EVERYMONTH_BACKUP ]]; then
  BACKUP_DIR="${BACKUP_DIR}/EveryMounth"
  MAX_BACKUP=${MAX_MOUNTH_BACKUP}
else
  BACKUP_DIR="${BACKUP_DIR}/EveryDay"
  MAX_BACKUP=${MAX_DAY_BACKUP}
fi
CheckBackupDir "$BACKUP_DIR"
BACKUP_DIR="${BACKUP_DIR}/$(date +%Y-%m-%d)"
CheckBackupDir "$BACKUP_DIR"

############### Get mysql DB
mapfile -t DB_LIST < <(mysql -NBe "SHOW DATABASES;")
CheckErrorCode $? "can't connect to mysql" $ERROR_CANT_CONNECT_TO_MYSQL

############### Create DB backup
if [[ ${MASTER} == "TRUE" ]]; then
  cp /etc/mysql/my.cnf "${BACKUP_DIR}/my_master.cnf"
  exit $ERROR_RUN_ON_MASTER
else
  cp /etc/mysql/my.cnf "${BACKUP_DIR}/my_slave.cnf"
fi

for DB in ${DB_LIST[*]}; do
  SKIP_DB_FLAG="FALSE"
  for SKIP_DB in ${DB_SKIP_LIST[*]}; do
    if [[ "$DB" == "$SKIP_DB" ]] ; then
      SKIP_DB_FLAG="TRUE"
    fi
  done

  if [[ "$SKIP_DB_FLAG" == "FALSE" ]]; then
    if [[ "$DB" == "mysql" ]]; then
      MYSQLDUMP_EXTRA_OPT=(--flush-privileges)
      MYSQLDUMP_FILE="${BACKUP_DIR}/0000-${DB}-$(date +%Y-%m-%d).sql"
    else
      MYSQLDUMP_EXTRA_OPT=()
      MYSQLDUMP_FILE="${BACKUP_DIR}/${DB}-$(date +%Y-%m-%d).sql"
    fi
      mysqldump "${MYSQLDUMP_OPT[@]}" "${MYSQLDUMP_EXTRA_OPT[@]}" --result-file="${MYSQLDUMP_FILE}" "${DB}"
  fi
done

############### compress DB backup
for DUMP_FILE in "${BACKUP_DIR}"/*.sql; do
  bzip2 "$DUMP_FILE"
  CheckErrorCode "$?" "Comperss $DUMP_FILE error"
done

############### Delete old Backup
BACKUP_DIR="$(dirname "$BACKUP_DIR")"
FILE_IN_DIR="$(ls -l "$BACKUP_DIR" |wc -l)"

while [[ ( $FILE_IN_DIR -gt ${MAX_BACKUP} ) && ( $FILE_IN_DIR -ne 0 ) ]]; do
  FILE_TO_DELETE=$(ls -lrt "${BACKUP_DIR}" | sed -ne '2p' |awk '{print $NF}' )
  rm -rf "${BACKUP_DIR:?}/${FILE_TO_DELETE}"
  FILE_IN_DIR=$(ls -l "$BACKUP_DIR" |wc -l)
done
