#!/bin/bash
################################################################################
#                                                                              #
#                      reload apache when get new cert                         #
#                                                                              #
#                           mailto:dusharu17@gmail.com                         #
#                                                                   2017.01.17 #
################################################################################

EMAIL="<admin_email>"
APACHECTL_ERROR="$(apache2ctl configtest )"
ERROR_CODE="$?"
if [[ $ERROR_CODE -ne 0 ]]; then
  echo -e "apache2ctl configtest - FAILED. \n${APACHECTL_ERROR}" | \
  mail -a "$(hostname)" -s "$(hostname):$0 " \
  "$EMAIL"
else
  /etc/init.d/apache2 graceful
  ERROR_CODE="$?"
  if [[ $ERROR_CODE -ne 0 ]]; then
    echo -e "apache2 graceful restart - FAILED\n when update letcenrypt cert" |\
    mail -a "$(hostname)" -s "$(hostname):$0 apache2 restart FAILED" \
    "$EMAIL"
  fi
fi
