#!/bin/bash
################################################################################
#                                                                              #
#                       Check cpu by thermal diode for snmp                    #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2014.12.17 #
################################################################################
sensors |grep it8728 -A 19 |grep -e "thermal diode" |awk '{print $2}' |grep -o "[0-9.]*"
