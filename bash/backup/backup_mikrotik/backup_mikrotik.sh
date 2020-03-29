#!/bin/bash
# shellcheck disable=SC2012
################################################################################
#                                                                              #
#                         Backup miktoik config                                #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2017.03.07 #
################################################################################

##### Prepare Mikrotik
### on localhost
# generate ssh key
# scp .ssh/id_rsa.pub 192.168.1.1:
# ssh 192.168.1.1
### on Mikrotik
#/user group add name=backup policy=ssh,test,ftp,read,sensitive,policy
#/user add name=backup_user group=backup disabled=no password=$PASS
#/user ssh-keys import user=backup_user public-key-file=id_rsa.pub

### !!! THIS script not clear on www.shellcheck.net !!!
# 1. SC2086: Double quote to prevent globbing and word splitting.
## 1.1 Can't run SSH param from file and send to ssh as parametr
###(Ex. ssh $DEV_OPTIONS -p "$DEV_PORT" "$DEV_USER"@"$DEV_IP")
# 2. SC2012: Use find instead of ls to better handle non-alphanumeric filenames.
## 2.1 find can't sort files by modification time, but we need last backup file for diff with current backup

############################## VAR
#set -x #debug
DATE="$(date +%Y%m%d)"
LIST_DEVICES="$(/bin/dirname "$(/usr/bin/realpath "$0")")/list_devices"

BACKUP_DIR="/mnt/backup_mikrotik"
BACKUP_PASS="<password_backup>"
DAY_EVERYMONTH_BACKUP=01
MAX_LOGS_EVERYDAY=30
MAX_LOGS_EVERYMONTH=13
BACKUP_LOCK_FILE='/tmp/mikrotik_backup.lock'

DIFF_LOG="/tmp/mikrotik_config_diff.log"
ERROR_LOG="/tmp/mikrotik_backup_error.log"

########## EXIT_CODE
ERROR_FIND_LOCK_FILE=101
ERROR_CANT_CREATE_ERROR_LOG=102

############################## FUNCTION ##############################
function SendEmail {
  EMAIL='<admin_email>'
  echo -e "$@" | mail -a "$(hostname)" -s "$(hostname):$0" $EMAIL
}

function CheckErrorCode {
  # $1 - Error code
  # $2 - Error message
  if [[ $1 -ne 0 ]]; then
    echo "$2" >> $ERROR_LOG
  fi
}

############################## MAIN ##############################
##### check

if [[ -e "$BACKUP_LOCK_FILE" ]]; then
  SendEmail "Find Lock file - $BACKUP_LOCK_FILE"
  exit "$ERROR_FIND_LOCK_FILE"
else
  touch "$BACKUP_LOCK_FILE"
fi

echo > "$ERROR_LOG"
if [[ ! -w "$ERROR_LOG" ]]; then
  SendEmail "Can't create Error Log: $ERROR_LOG"
  exit $ERROR_CANT_CREATE_ERROR_LOG
fi

##### modify VAR
if [[ $((10#$(date +%d))) -eq $DAY_EVERYMONTH_BACKUP ]]; then
  MAX_LOGS=$MAX_LOGS_EVERYMONTH
  else
  MAX_LOGS=$MAX_LOGS_EVERYDAY
fi

##### create and clear log
echo > "$DIFF_LOG"
CheckErrorCode $? "Can't Create diff log"

##### start backup and process log
while read -r DEV_NAME DEV_IP DEV_PORT DEV_USER DEV_OPTIONS; do
  ##### set BACKUP_DIR
  if [[ $((10#$(date +%d))) -eq $DAY_EVERYMONTH_BACKUP ]]; then
    BACKUP_PATH="$BACKUP_DIR/$DEV_NAME/EveryMONTH"
  else
    BACKUP_PATH="$BACKUP_DIR/$DEV_NAME/EveryDAY"
  fi

  if echo "$DEV_NAME" | grep -q -e '^\s*#' ; then
    echo "Skip $DEV_NAME $DEV_IP" >/dev/null # debug
  else
    ##### create backup dir
    #echo "Run $DEV_NAME $DEV_IP" #debug
    mkdir -p "$BACKUP_PATH" 2>/dev/null
    CheckErrorCode $? "Can't Create $BACKUP_PATH"
    chmod 700 "$BACKUP_PATH"
    CheckErrorCode $? "Can't set permissions for $BACKUP_PATH"

    ##### create backup .rsc
    #shellcheck disable=SC2086
    ssh -n -o "StrictHostKeyChecking no" $DEV_OPTIONS -p "$DEV_PORT" "$DEV_USER"@"$DEV_IP" "/export verbose hide-sensitive" > "$BACKUP_PATH/${DEV_NAME}_${DATE}.rsc"
    # hide-sensitive - hide password and other private information.
    # if set hide-sensitive - you can't get mail with password change
    #ssh -n -o "StrictHostKeyChecking no" $DEV_OPTIONS -p "$DEV_PORT" "$DEV_USER"@"$DEV_IP" "/export verbose" > "$BACKUP_PATH/${DEV_NAME}_${DATE}.rsc"
    CheckErrorCode $? "Can't get config from $DEV_USER@$DEV_IP:$DEV_PORT"
    chmod 600 "$BACKUP_PATH/${DEV_NAME}_${DATE}.rsc"
    CheckErrorCode $? "Can't set permissions for $BACKUP_PATH/${DEV_NAME}_${DATE}.rsc"

    ##### create backup .backup
    # shellcheck disable=SC2086
    ssh -n -o "StrictHostKeyChecking no" $DEV_OPTIONS -p "$DEV_PORT" "$DEV_USER"@"$DEV_IP" "/system backup save name=everyday.backup password=$BACKUP_PASS" > /dev/null 2>&1
    CheckErrorCode $? "Can't Create everyday.backup on $DEV_USER@$DEV_IP:$DEV_PORT"
    # shellcheck disable=SC2086
    scp -P "$DEV_PORT" -o "StrictHostKeyChecking no" $DEV_OPTIONS "$DEV_USER@$DEV_IP:everyday.backup" "$BACKUP_PATH/${DEV_NAME}_${DATE}.backup"  > /dev/null 2>&1
    CheckErrorCode $? "Can't get backup from $DEV_USER@$DEV_IP:$DEV_PORT"
    chmod 600 "$BACKUP_PATH/${DEV_NAME}_${DATE}.backup"
    CheckErrorCode $? "Can't set permissions for $BACKUP_PATH/${DEV_NAME}_${DATE}.backup"

    ##### diff
    echo "====== $DEV_NAME - $DEV_IP ======" >> $DIFF_LOG
    if [[ $((10#$(date +%d))) -eq $DAY_EVERYMONTH_BACKUP ]]; then
      # Today is EveryMonth backup Day
      NOWDAY_FILE="$(ls -lt "$BACKUP_PATH"/*.rsc |sed -ne '1p' |awk '{print $NF}')"
      YESTERDAY_FILE="$(ls -lt "$BACKUP_PATH"/../EveryDAY/*.rsc |sed -ne '1p' |awk '{print $NF}')"
    elif [[ $((10#$( date -d @$(($(date -d "$DATE" +%s)-86400)) +%d ))) -eq $DAY_EVERYMONTH_BACKUP ]]; then
      # Yesterday was EveryMonth backup Day
      NOWDAY_FILE="$(ls -lt "$BACKUP_PATH"/../EveryMONTH/*.rsc |sed -ne '1p' |awk '{print $NF}')"
      YESTERDAY_FILE="$(ls -lt "$BACKUP_PATH"/*.rsc |sed -ne '1p' |awk '{print $NF}')"
    else
      # EveryMonth backup Day not used
      NOWDAY_FILE="$(ls -lt "$BACKUP_PATH"/*.rsc |sed -ne '1p' |awk '{print $NF}')"
      YESTERDAY_FILE="$(ls -lt "$BACKUP_PATH"/*.rsc |sed -ne '2p' |awk '{print $NF}')"
    fi
    #echo "diff $NOWDAY_FILE $YESTERDAY_FILE" # debug
    if [[ ( -e "$NOWDAY_FILE") && ( -e "$YESTERDAY_FILE" ) ]]; then
      DIFF=$(diff "$NOWDAY_FILE" "$YESTERDAY_FILE" 2>/dev/null)
      EXIT_CODE=$?
      if [[ $EXIT_CODE -ne 0 ]]; then
        echo "$DIFF" >> "$DIFF_LOG"
      fi
    fi

  ##### remove old
  FILE_IN_DIR=$(($(ls -l "$BACKUP_PATH" |wc -l)-1))
  #echo "$FILE_IN_DIR - $MAX_LOGS" #debug
  while [[ ( $FILE_IN_DIR -gt $((MAX_LOGS*2)) ) && ( "$FILE_IN_DIR" -ne 0 ) ]]; do
    FILE_TO_DEL=$(ls -lrt "$BACKUP_PATH" |sed -ne '2p' |awk '{print $NF}')
    #echo "Delete file $BACKUP_PATH/$FILE_TO_DEL"
    sleep 3
    rm -rf "${BACKUP_PATH:?}/$FILE_TO_DEL"
    CheckErrorCode $? "Can't delete $BACKUP_PATH/$FILE_TO_DEL"
    FILE_IN_DIR=$(($(ls -l "$BACKUP_PATH" |wc -l)-1))
  done
  fi
done < "$LIST_DEVICES"

##### send diff_log to mail
sed -i -e "s//\n/g" "$DIFF_LOG"
if grep -q -v -e "====== .* ======" -e "^\s*$" -e " by RouterOS " -e "^---" -e "1c1" "$DIFF_LOG" &>/dev/null ; then
  DIFF=$(cat -A  $DIFF_LOG|sed -e 's#\$$##')
  SendEmail "$DIFF"
fi

##### send error_log to mail
if grep -e "." "$ERROR_LOG" &>/dev/null ; then
  ERROR_TO_MAIL="$(cat "$ERROR_LOG")"
  SendEmail "$ERROR_TO_MAIL"
fi

##### remove lock file
rm -f "$BACKUP_LOCK_FILE"
#rm -f $DIFF_LOG
#rm -f $ERROR_LOG
