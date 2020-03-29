#!/bin/bash
################################################################################
#                                                                              #
#                       Check running important process                        #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2014.08.10 #
################################################################################

############### VAR
PROCESS_NAME="nginx2"
LOCK_FILE="/tmp/check_process_$PROCESS_NAME"

MAIL_BODY="$PROCESS_NAME failed on $HOSTNAME"
TIME_AFTER_LAST_MAIL=600

############### FUNCTION
function SendEmail {
  MAIL_1="<admin_email>"
  BOT_EMAIL="<bot_email>"
  echo -e "$@" | mail -a "From: $BOT_EMAIL" -s "$(hostname):$0" "$MAIL_1"
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

############### MAIN
if pgrep "$PROCESS_NAME" &>/dev/null ; then
  #echo "$PROCESS_NAME run"
  rm -f "$LOCK_FILE"
  CheckErrorCode $? "Can't delete $LOCK_FILE"
else
  #echo "$PROCESS_NAME don't run"
  if [[ -f "$LOCK_FILE" ]]; then
    #echo "$LOCK_FILE - exist"
    LOCK_FILE_DATE="$(stat --format %Y $LOCK_FILE)"
    CURRENT_DATE="$(date +%s)"

    if [[ $((CURRENT_DATE-LOCK_FILE_DATE)) -ge $TIME_AFTER_LAST_MAIL ]]; then
      #echo " $((CURRENT_DATE-LOCK_FILE_DATE)) -ge $TIME_AFTER_LAST_MAIL"
      SendEmail "$MAIL_BODY"
      touch $LOCK_FILE
    #else
    #  echo "$((CURRENT_DATE-LOCK_FILE_DATE)) -le $TIME_AFTER_LAST_MAIL"
    fi
  else
    #echo "$LOCK_FILE - don't exist"
    SendEmail "$MAIL_BODY"
    touch $LOCK_FILE
  fi
fi
