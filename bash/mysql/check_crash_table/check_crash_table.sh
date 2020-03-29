#!/bin/bash
# shellcheck disable=SC2001
################################################################################
#                                                                              #
#                       check crash table in mysql                             #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.07.31 #
################################################################################
# INCRON_STRING: "/var/log/mysql/mysqld.err IN_MODIFY /opt/scripts/check_crash_table/check_crash_table.sh"
# This script must be setup in incron on all mysql node
# This scipt must be equals on all mysql node

# TODO:
# 1. Replace sed to dirname or any builtin bash string functions

############################## VAR
MYSQL_ERROR_LOG="/var/log/mysql/mysqld.err"
CRASH_TABLE="/tmp/crash_table.txt"
NEED_REPAIR="FALSE"
############################## FUNCTION
function SendEmail {
  EMAIL="<email_admin>"
  BOT_EMAIL="<email_bot>"
  echo -e "$@" | mail -a "From: $BOT_EMAIL" -s "$(hostname):$0" $EMAIL
}

############################## MAIN
ERROR="$(tail -n 1 ${MYSQL_ERROR_LOG})"
if CRASH_TABLE_STRING="$(echo "${ERROR}" |grep -m1 -oe 'Table .* is marked as crashed' 2>/dev/null )"; then
  #echo "${CRASH_TABLE_STRING}" # debug
  DB="$(echo "${CRASH_TABLE_STRING}" | sed -e 's#^.*\.\/\(.*\)\/.*#\1#g')"
  TABLE="$(echo "${CRASH_TABLE_STRING}" | sed -e 's#^.*\/\(.*\). is .*#\1#g')"
  if [[ ! -e "${CRASH_TABLE}" ]]; then
    NEED_REPAIR="TRUE"
  elif ! grep -e "^${DB} ${TABLE}$" "${CRASH_TABLE}" &>/dev/null ; then
    NEED_REPAIR="TRUE"
  fi
fi

if [[ ${NEED_REPAIR} == "TRUE" ]]; then
  echo "${DB} ${TABLE}" >> "${CRASH_TABLE}"
  SendEmail "$(date "+%Y-%m-%d %H:%M:%S") - ${DB}:${TABLE} - need repair"
  mysql "${DB}" -e "REPAIR TABLE ${TABLE};"
  EXIT_CODE=$?
  if [[ ${EXIT_CODE} -eq 0 ]]; then
    sed -ire "/^${DB} ${TABLE}$/ d" "${CRASH_TABLE}"
    SendEmail "$(date "+%Y-%m-%d %H:%M:%S") - ${DB}:${TABLE} - is repair now"
  else
    SendEmail "$(date "+%Y-%m-%d %H:%M:%S") - ${DB}:${TABLE} - repair FAILED.\nPlease, run command manualy:\nmyslq ${DB} -e \"REPAIR TABLE ${TABLE};\" "
  fi
fi
