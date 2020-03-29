#!/bin/bash
################################################################################
#                                                                              #
#                    backup xen vm on LVM with borg                            #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.09.16 #
################################################################################
# need: lvm with snapshot,  borgbackup
#don't forget
#export BORG_PASSCOMMAND="cat <key_file>"
#borg --progress init --encryption keyfile ssh://"${BORG_USER}"@"${BORG_HOST}":"${BORG_PORT}""${BORG_PATH}"


############################## VAR
declare -a LVM_VOLUME
LVM_VOLUME=(
  vm1
  vm2
  vm3
)

WORKDIR=$(/bin/dirname "$(/usr/bin/realpath "$0")")

export BORG_PASSCOMMAND="cat $WORKDIR/key_pass"
BORG_USER="<backup_user>"
BORG_HOST="<backup_host>"
BORG_PORT="<backup_port>"
BORG_PATH="<backup_path_on_remote_host>"
MOUNT_BACKUP=/mnt/backup
VG="<volume_group>"
LOG_FILE=/var/log/backup_vm.log # don't forget logrotate

##### EXIT_CODE
EXIT_CANT_CREATE_BACKUP_DIR=100
EXIT_CANT_CHANGE_PERMISSIONS=101


############################## FUNCTIONS
function PrintLog {
  echo "$(date "+%Y%m%d %H:%M:%S") $0[$$]: $*" >> $LOG_FILE
}

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
##### 0 - Check
PrintLog "===== 0 - Prepare backup ====="
PrintLog "Create $MOUNT_BACKUP"
mkdir -p "$MOUNT_BACKUP" >> $LOG_FILE 2>&1
CheckErrorCode $? "Can't create dir for mount - $MOUNT_BACKUP" "$EXIT_CANT_CREATE_BACKUP_DIR"
chown root:root "$MOUNT_BACKUP" >> $LOG_FILE 2>&1
CheckErrorCode $? "Can't execute: chown root:root $MOUNT_BACKUP" $EXIT_CANT_CHANGE_PERMISSIONS
chmod 700 "$MOUNT_BACKUP" >> $LOG_FILE 2>&1
CheckErrorCode $? "Can't execute: chmod 700 $MOUNT_BACKUP" $EXIT_CANT_CHANGE_PERMISSIONS

PrintLog "Change Log permissions"
chmod 600 "$LOG_FILE" >> $LOG_FILE 2>&1
CheckErrorCode $? "Can't execute: chmod 600 $LOG_FILE" $EXIT_CANT_CHANGE_PERMISSIONS
chown root:root "$LOG_FILE" >> $LOG_FILE 2>&1
CheckErrorCode $? "Can't execute: chown root:root $LOG_FILE" $EXIT_CANT_CHANGE_PERMISSIONS

##### 1 - get LVM volume in loop
i=0
for VOLUME in ${LVM_VOLUME[*]}; do
  ((i++))
  PrintLog "===== $i - create backup volume: $VOLUME ====="

  ##### 1.1 Create shapshot
  PrintLog "Create snapshot ${VOLUME}"
  PrintLog "/sbin/lvcreate -n \"${VOLUME}-snapshot\" -L 10G -s -p r \"${VG}/$VOLUME\""
  /sbin/lvcreate -n "${VOLUME}-snapshot" -L 10G -s -p r "${VG}/$VOLUME" >> $LOG_FILE 2>&1
  EXIT_CODE="$?"
  if [[ $EXIT_CODE -ne 0 ]]; then
    CheckErrorCode "$EXIT_CODE" "Can't create snapshot for $VOLUME"
    continue
  fi

  ##### 1.2 Create dir for mount
  PrintLog "Create dir for mount - ${MOUNT_BACKUP}/${VOLUME} "
  {
    mkdir -p "${MOUNT_BACKUP}/${VOLUME}"
    chown root:root "${MOUNT_BACKUP}/${VOLUME}"
    chmod 700 "${MOUNT_BACKUP}/${VOLUME}"
  } >> $LOG_FILE 2>&1

  ##### 1.3 Mount
  PrintLog "mount \"${VG}/${VOLUME}-snapshot\" -o ro,norecovery \"${MOUNT_BACKUP}/${VOLUME}\""
  # -o ro,norecovery - need, because snapshot create when VM working and journal not clear
  mount "${VG}/${VOLUME}-snapshot" -o ro,norecovery "${MOUNT_BACKUP}/${VOLUME}" >> $LOG_FILE 2>&1
  EXIT_CODE="$?"
  if [[ $EXIT_CODE -eq 0 ]]; then

    ##### 1.4 Create backup
    PrintLog "borg create create ssh://${BORG_USER}@${BORG_HOST}:${BORG_PORT}${BORG_PATH}::\"$VOLUME-$(date +%Y-%m-%d)\" \"${MOUNT_BACKUP}/${VOLUME}\""
    borg create "ssh://${BORG_USER}@${BORG_HOST}:${BORG_PORT}${BORG_PATH}::$VOLUME-$(date +%Y-%m-%d)" /"${MOUNT_BACKUP}/${VOLUME}" \
      --exclude '/mnt/backup/*/usr/portage/*' \
      --exclude '/mnt/backup/*/usr/src/*' \
      --exclude '/mnt/backup/*/var/cache/*' \
      --exclude '/mnt/backup/*/var/run/*' \
      --exclude '/mnt/backup/*/tmp/*' \
      --exclude '/mnt/backup/*/var/tmp/*' >> $LOG_FILE 2>&1
    CheckErrorCode $? "Borg backup failure with EXIT_CODE: $? on Volume: $VOLUME. Please check $LOG_FILE on $(hostname)"

    ##### 1.5 Umount
    PrintLog "umount ${MOUNT_BACKUP}/${VOLUME}"
    umount "${MOUNT_BACKUP}/${VOLUME}" >> $LOG_FILE 2>&1
    CheckErrorCode $? "umount failure on Volume: $VOLUME. Please check $LOG_FILE on $(hostname)"
  fi

  ##### 1.6 Remove snapshot
  sleep 3 #Error: "Logical volume LVM/<name>-snapshot contains a filesystem in use."
  PrintLog "/sbin/lvremove -f \"${VG}/${VOLUME}-snapshot\""
  /sbin/lvremove -f "${VG}/${VOLUME}-snapshot" >> $LOG_FILE 2>&1
  CheckErrorCode $? "lvremove failure on Volume: $VOLUME. Please check $LOG_FILE on $(hostname)"

  ##### 1.7 prune old bachup
  PrintLog "===== $i - prune old backup ====="
  borg prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --list --prefix "$VOLUME" --stats ssh://"${BORG_USER}"@"${BORG_HOST}":"${BORG_PORT}""${BORG_PATH}" >> $LOG_FILE 2>&1
done

##### 2. backup host vm
((i++))
PrintLog "===== $i - create backup host vm - $(hostname) ====="
PrintLog "borg create ssh://${BORG_USER}@${BORG_HOST}:${BORG_PORT}${BORG_PATH}::\"$(hostname)-$(date +%Y-%m-%d)\""
borg create "ssh://${BORG_USER}@${BORG_HOST}:${BORG_PORT}${BORG_PATH}::$(hostname)-$(date +%Y-%m-%d)" / \
  --exclude '/usr/portage' \
  --exclude '/usr/src/' \
  --exclude '/var/cache/' \
  --exclude '/var/run/' \
  --exclude '/var/tmp/' \
  --exclude '/dev/*' \
  --exclude '/proc/*' \
  --exclude '/sys/*' \
  --exclude '/tmp/*' \
  --exclude "/root/.config/borg/keys/${BORG_HOST}_mnt_D_backup" >> $LOG_FILE 2>&1

##### 3. prune old backup
((i++))
PrintLog "===== $i - prune old backup ====="
PrintLog "borg prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prefix \"$(hostname)\" --list --stats ssh://${BORG_USER}@${BORG_HOST}:${BORG_PORT}${BORG_PATH}"
borg prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prefix "$(hostname)" --list --stats "ssh://${BORG_USER}@${BORG_HOST}:${BORG_PORT}${BORG_PATH}" >> $LOG_FILE 2>&1

echo "borg backup done">> $LOG_FILE 2>&1
