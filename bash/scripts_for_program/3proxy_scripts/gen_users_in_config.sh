#!/bin/bash
################################################################################
#                                                                              #
#                       gen 3proxy users rules and counters                    #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.04.16 #
################################################################################
# gen access rules
grep -ve "^\s*#" -e "^\s*$" /etc/3proxy/3proxy_users.cfg |\
sed -e 's#users \"\(.*\):..:.*#allow \1#g'  > /etc/3proxy/3proxy_users_allow.cfg


# gen counters rules
grep -ve "^\s*#" -e "^\s*$" /etc/3proxy/3proxy_users.cfg | \
awk  -F : '{gsub ("users \"","",$1); print "countin  \"" NR*2-1 "/"$1"-in\"  H 1000000 "$1"\n" "countout \"" NR*2 "/"$1"-out\" H 1000000 "$1}' > /etc/3proxy/3proxy_users_counters.cfg

# set perm
chown root:proxy3 /etc/3proxy/*
chmod 640 /etc/3proxy/*
