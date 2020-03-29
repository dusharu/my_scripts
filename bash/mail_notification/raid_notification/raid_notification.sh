#!/bin/bash
################################################################################
#                                                                              #
#                       Check and mail raid events                             #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2014.11.28 #
################################################################################

############################## VAR
COMMAND="$1"

############################## FUNCTION
function SendEmail {
  EMAIL="<amdin_email>"
  BOT_EMAIL="<bot_email>"
  echo -e "$@" | mail -a "From: $BOT_EMAIL" -s "$(hostname):$0" $EMAIL
}

############################## MAIN
MD_STATUS="$(cat /proc/mdstat)"

if [[ $COMMAND == check ]]; then
  # run on cron
  if grep block /proc/mdstat |grep '_' > /dev/null 2>&1 ; then
    SendEmail "Disk Failed: \\n${MD_STATUS}"
  fi
else
  # run by /etc/init.d/mdadm
  SendEmail "$* \\n${MD_STATUS}"
fi
