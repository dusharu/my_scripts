#!/bin/bash
################################################################################
#                                                                              #
#                              check cert                                      #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2017.01.17 #
################################################################################

MAIL="<admin_email>"
CERT="</etc/nginx/ssl/cert.pem>"
DOMAIN="<example.com>"
MAIL_SUBJ="WARNING: cert for $DOMAIN failed"

DATE_CERT_END="$(openssl x509 -in $CERT -noout -enddate | cut -d= -f 2)"
DATE_CERT_START="$(openssl x509 -in $CERT -noout -startdate | cut -d= -f 2)"
DATE_CERT_END_TIMESTAMP="$(date -d "$DATE_CERT_END" +%s)"
DATE_CERT_START_TIMESTAMP="$(date -d "$DATE_CERT_START" +%s)"
DATE_NOW_TIMESTAMP="$(date +%s)"
TIME_TO_END_CERT="$((DATE_CERT_END_TIMESTAMP-DATE_NOW_TIMESTAMP))"

if [[ $DATE_CERT_START_TIMESTAMP -ge $DATE_NOW_TIMESTAMP ]]; then
  echo -e "You'r cert start working at: $DATE_CERT_START \n But NOW: $(date)" | mail -s "$(hostname):$0 - $MAIL_SUBJ" $MAIL
fi

DAY_THOLD=15
if [[ $TIME_TO_END_CERT -le $((DAY_THOLD*86400)) ]]; then
  echo -e "You'r cert end at: $DATE_CERT_END \n NOW: $(date)\n DAY_THOLD == $DAY_THOLD \nPlease get new cert! " |\
  mail -s "$(hostname):$0 - $MAIL_SUBJ" $MAIL
fi
