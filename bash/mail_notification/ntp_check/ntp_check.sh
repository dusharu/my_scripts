#!/bin/bash
################################################################################
#                                                                              #
#                               Check ntp                                      #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2015.01.23 #
################################################################################
EMAIL="<email>"

if ntpq -p 127.0.0.1 |grep -qe "\.INIT\." -e "\.XFAC\." ; then
  echo -e "Some NTP servers is unreachable on $(hostname).\nCheck /etc/ntpd.conf and /etc/conf.d/ntp-client:\n\n$(ntpq -p 127.0.0.1)" |\
  mail -a "$(hostname)" -s "(hostname) NTP server failed"  "$EMAIL"
fi

if ! /etc/init.d/ntpd  status |grep -qe start; then
        echo "ntpd stoped" | mail -a "$(hostname)" -s "$(hostname) NTP server failed"  "$EMAIL"
fi
