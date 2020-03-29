#!/bin/bash
################################################################################
#                                                                              #
#                        Check Status mysql SLAVE                              #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.06.19 #
################################################################################

######################### VAR #########################

DB_MASTER_FQDN="<mysql.example.com>"
FILE_SLAVE_PROBLEM='/tmp/slave_monitoring.txt'

############### EXIT CODE
ERROR_CANT_CONNECT_TO_MYSQL=100
ERROR_CANT_READ_MYCNF=103
ERROR_CANT_GET_INTERFACES_HOST=104
ERROR_CANT_GET_IP_HOST=105
ERROR_CANT_GET_IP_DB_MASTER=106
ERROR_SLAVE_BROKEN=107
ERROR_SLAVE_FALLS_BEHIND_MASTER=108

ERROR_RUN_ON_MASTER=0
ERROR_UNKNOWN=255

######################### FUNCTION #########################
function SendEmail {
  EMAIL="<admin_email>"
  BOT_EMAIL="<bot_email>"
  echo -e "$@" | mail -a "From: $BOT_EMAIL" -s "$(hostname):$0" $EMAIL
}

function CheckErrorCode {
  # $1 - Error code
  # $2 - Text for mail
  # $3 - Exit with ERROR CODE
  # NEED:
  # $ERROR_UNKNOWN, $FILE_SLAVE_PROBLEM
  if [[ $1 -ne 0 ]]; then
    if ! grep "$2" "$FILE_SLAVE_PROBLEM"  > /dev/null 2>&1 ; then
      echo "$2" >> "$FILE_SLAVE_PROBLEM"
        SendEmail "$2"
    fi
      if [[ -z $3 ]]; then
      exit $ERROR_UNKNOWN
    else
              exit "$3"
      fi
  else
    if grep "$2" "$FILE_SLAVE_PROBLEM"  > /dev/null 2>&1 ; then
      DEL_TEMPLATE="$(echo "$2" |\
        sed -e 's#"#\\"#g' |\
        sed -e 's#\\#\\\\#g' |\
        sed -e 's#/#\\/#g')"
      sed -i -e "/^$DEL_TEMPLATE/d" "$FILE_SLAVE_PROBLEM"
      SendEmail "PROBLEM RESOLVE: $2"
    fi
  fi
}

######################### MAIN #########################

############### Check

if [[ ! -r /root/.my.cnf ]]; then
  CheckErrorCode 1 "Can't read /root/.my.cnf.Exit." $ERROR_CANT_READ_MYCNF
else
  CheckErrorCode 0 "Can't read /root/.my.cnf.Exit." $ERROR_CANT_READ_MYCNF
fi

IP_INTERFACES="$(ip ro |grep -m1 default |awk '{print $5}')"
CheckErrorCode $? "Can't get default route inetrfaces from Host" $ERROR_CANT_GET_INTERFACES_HOST
IP_HOST="$(ip -4 add show dev "${IP_INTERFACES}" | grep -m1 inet  |awk '{print $2}' |sed -e 's#/.*$##g' )"
CheckErrorCode $? "Can't get IP from Host" $ERROR_CANT_GET_IP_HOST
IP_DB_MASTER=$(host ${DB_MASTER_FQDN} |awk '{print $4}')
CheckErrorCode $? "Can't get IP master DB" $ERROR_CANT_GET_IP_DB_MASTER

if [[ "${IP_HOST}" == "${IP_DB_MASTER}" ]]; then
  exit $ERROR_RUN_ON_MASTER
fi

MYSQL_SLAVE_STATUS="$(mysql -e 'SHOW SLAVE STATUS\G')"
CheckErrorCode $? "can't connect to mysql" $ERROR_CANT_CONNECT_TO_MYSQL

CHECK_SLAVE_DOUBLE_YES=$( echo "${MYSQL_SLAVE_STATUS}" |grep -c -e "Slave_IO_Running: Yes" -e "Slave_SQL_Running: Yes")
if [[ $CHECK_SLAVE_DOUBLE_YES -ne 2 ]]; then
  CheckErrorCode 1 "$0 - SLAVE broken." $ERROR_SLAVE_BROKEN
else
  CheckErrorCode 0 "$0 - SLAVE broken." $ERROR_SLAVE_BROKEN
fi

SECOND_BEHIND_MASTER=$(echo "${MYSQL_SLAVE_STATUS}"| awk '/Seconds_Behind_Master:/ {print $2}')
if [[ $SECOND_BEHIND_MASTER -ge 3600 ]]; then
  CheckErrorCode 1 "SLAVE BEHIND MASTER >= 1Hour(3600sec)." $ERROR_SLAVE_FALLS_BEHIND_MASTER
else
  CheckErrorCode 0 "SLAVE BEHIND MASTER >= 1Hour(3600sec)." $ERROR_SLAVE_FALLS_BEHIND_MASTER
fi
