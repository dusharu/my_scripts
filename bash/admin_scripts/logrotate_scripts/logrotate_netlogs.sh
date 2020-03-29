#!/bin/bash
################################################################################
#                                                                              #
#                        rotate and clear netlogs                              #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.09.01 #
################################################################################
# please check that file structure like <dir>/<host>/<YEAR>/<MOUNTH>/<log-name>-<day>.log
# EX.: /var/log/netlogs/my_host/1970/12/all-31.log

############################## VAR
LOG_DIR=/var/log/netlogs/

############### EXIT CODE
EXIT_INVALID_DIR=100

############################## FUNCTION
function SendEmail {
  EMAIL="<admin_email>"
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

############################## MAIN

# compute  delete dates
YESTERDAY="$(( 10#$( date -d @$(( $(date -d "$DATE" +%s) -86400)) +%d ) ))"
YEAR_TO_DELETE="$(( $( date +%Y ) - 2 ))"

if [[ "${YESTERDAY}" -le 9 ]]; then
  YESTERDAY="0${YESTERDAY}"
fi

# check dir for delete not /
if [[ ! $LOG_DIR =~ ^/var/log/ ]]; then
  echo "LOG_DIR not start from /var/log/" | SendEmail
  exit $EXIT_INVALID_DIR
fi

##### gzip Yesterday files
find "${LOG_DIR}" -name "*-${YESTERDAY}.log" -exec gzip {} +
CheckErrorCode $? "gzip yesterday logs not end correct \n\
Please,run and check output:\n\
find ${LOG_DIR} -name \"*-${YESTERDAY}.log\" -print"

##### delete dir create 2 years ago
find "${LOG_DIR}" -type d -name "$YEAR_TO_DELETE" -exec rm -rf {} +
CheckErrorCode $? "delete logs older than 2years not end correct \n\
Please,run and check output: \n\
find ${LOG_DIR} -type d -name \"$YEAR_TO_DELETE\" -print"
