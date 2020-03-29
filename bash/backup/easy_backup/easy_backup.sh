#!/bin/bash
################################################################################
#                                                                              #
#                       Simple Server backup                                   #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2014.08.10 #
################################################################################
export PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"
BACKUP_DIR="/backup"
BACKUP_FILE="$BACKUP_DIR/backup_$HOSTNAME.tar"
MYSQLDUMP="$BACKUP_DIR/mysqldump_all_$HOSTNAME.sql.gz"

################### MAIN
##### delete old files
rm -f "$MYSQLDUMP"
rm -f "$BACKUP_FILE"

#### system backup
tar cf "$BACKUP_FILE" /etc/
chmod 400 "$BACKUP_FILE"

tar rf "$BACKUP_FILE" /var/spool/
tar rf "$BACKUP_FILE" /boot/
tar rf "$BACKUP_FILE" /opt/scripts/
tar rf "$BACKUP_FILE" /var/lib/portage/world
### specific backup
tar rf "$BACKUP_FILE" /var/www/
mysqldump -u root -h localhost -p<PASS> --all-databases |gzip -c > "$MYSQLDUMP"
tar rf "$BACKUP_FILE" "$MYSQLDUMP"

##### compress data
gzip -f "$BACKUP_FILE"

#### remove tmp files
rm -f "$MYSQLDUMP"
