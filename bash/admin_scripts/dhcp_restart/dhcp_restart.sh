#!/bin/bash

############# VAR #############
DHCP_CONF="/etc/dhcp/dhcpd.conf"
DHCP_NEW_CONF_DIR="/home/nocbot/dhcp_conf"
DHCP_NEW_CONF="$DHCP_NEW_CONF_DIR/dhcpd.conf"
DHCP_OLD_CONF_DIR="/etc/dhcp/old_configs"
DHCP_OLD_CONF="$DHCP_OLD_CONF_DIR/dhcpd.conf.$(date +%Y%m%d%H%M)"

############# MAIN #############

### Test's
if [[ ! -d "$DHCP_OLD_CONF_DIR" ]]; then
  echo "$0 on $(hostname): Can't find $DHCP_OLD_CONF_DIR. Try to create."
  mkdir -p $DHCP_OLD_CONF_DIR
fi

if [[ ! -e "$DHCP_NEW_CONF" ]]; then
  echo "$0 on $(hostname): Can't find $DHCP_NEW_CONF"
  echo "New config not apply."
  echo "Exit."
  exit 11
fi

echo "Backup old copy dhcp.conf to $DHCP_OLD_CONF"
mv "$DHCP_CONF" "$DHCP_OLD_CONF"
echo "Copy new dhcpd.conf"
cp "$DHCP_NEW_CONF" "$DHCP_CONF"
echo "Restart DHCP"
/etc/init.d/dhcpd restart

### Check running DHCP
echo "Check running DHCP on $(hostname)"
if [[ ! $(pgrep -f /usr/sbin/dhcpd) ]]; then
  echo -e "   DHCP NOT RESTARTED. Rolling back..."
  cp "$DHCP_OLD_CONF" "$DHCP_CONF"
  /etc/init.d/dhcpd restart
  echo -e "   Check_2 running DHCP"
  if [[ $(pgrep -f /usr/sbin/dhcpd) ]]; then
    echo "   Using old config $DHCP_OLD_CONF, DHCP Restarted"
  else
    echo "   WARNING: Unknown trouble during roll back the changes."
    exit 12
  fi
fi

################## REMOVE OLD CONFIG
rm -f "$DHCP_NEW_CONF"
echo "   Delete old config(older 10 days)"
find "$DHCP_OLD_CONF_DIR" -mtime +10 -delete
