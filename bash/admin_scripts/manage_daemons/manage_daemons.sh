#!/bin/bash
################################################################################
#                                                                              #
#                      Manage daemons for non-root user                        #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2016.02.13 #
################################################################################

COMMAND=$1
SERVICE=$2
PERMISSION=FALSE

if [[ $SERVICE == "asterisk" ]] ; then
        PERMISSION=TRUE
fi

if [[ $PERMISSION == "TRUE" ]]; then
        "/etc/init.d/$SERVICE" "$COMMAND"
else
        echo "Wrong service. Please run:"
        echo "sudo /usr/local/bin/manage_service.sh <COMMAND> <SERVICE>"
        echo "<COMMAND> is start, stop, restart or status"
        echo "<SERVICE> is apache2"
fi
