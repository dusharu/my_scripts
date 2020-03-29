#!/bin/bash
################################################################################
#                                                                              #
#                             Create new xen-vm                                #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   2018.05.07 #
################################################################################

#### This is not tested !!!
#################### VAR ####################
VM_NAME="<vm_name>"
VM_IP="<vm_ip>"
VM_MASK="<vm_mask>"
LAST_OCTET=$(echo ${VM_IP} |awk -F "." '{print $4}')
VM_MEM=1048 # start mem, MB
VM_MAX_MEM=4096 # mem for hot-plug, MB
CPUS="\"15\"" #which core be used
VCPU=1 # how many cores use
VM_ROOT_SIZE=20G
# default Root Size == 20G

############### TEMPLATE ###############
VM_TEMPLATE_NAME="<default-vm>"
VM_TEMPLATE_CONF="</etc/xen/config_xen/s_default-vm>"
VM_TEMPLATE="/root/default_vm.tar.gz"
MOUNT_POINT="/mnt/gentoo"
VM_TEMPLATE_IP="<default_vm_ip>"
FIRST_OCTET_VM_TEMPLATE=$(echo ${VM_TEMPLATE_IP} |awk -F "." '{print $1"."$2"."$3}')

############### VAR for script ###############
STEP=0

############### EXIT CODE ###############
EXIT_CODE_LVCREATE=100
EXIT_CODE_MKFS=101
EXIT_CODE_MOUNT=102
EXIT_CODE_TAR=103
EXIT_CODE_UMOUNT=104
EXIT_CODE_NEW_VM_CONF=105
EXIT_CODE_NO_FREE_MAC=106
EXIT_CODE_CANT_STOP_TEMPLATE_VM=107
EXIT_CODE_CANT_RUN_TEMPLATE_VM=108
EXIT_CODE_CANT_MOUNT_VM_TEMPLATE_PARTITION=109
EXIT_CODE_CANT_CHANGE_DIR=110
EXIT_CODE_CANT_CREATE_TEMPLATE=111
EXIT_CODE_CANT_UMOUNT_VM_TEMPLATE_PARTITION=112
EXIT_CODE_TEMPLATE_VM_DOESNT_RUN=113
EXIT_CODE_TEMPLATE_CONF_DOESNT_EXIST=114



#################### Function ####################
function CheckErrorCode {
  # $1 - Error code
  # $2 - echo text
  # $3 - Exit with ERROR CODE
  if [[ $1 -ne 0 ]]; then
    echo "$2"
    if [[ -n $3 ]]; then
      exit "$3"
    fi
  fi
}



#################### MAIN ####################
((STEP++))
echo "===== $STEP - check start file  ====="
if ! xl list ${VM_TEMPLATE_NAME} > /dev/null 2>&1; then
  echo "template vm - ${VM_TEMPLATE_NAME} doesn't run. Exit."
  exit  $EXIT_CODE_TEMPLATE_VM_DOESNT_RUN
fi

if [[ ! -e ${VM_TEMPLATE_CONF} ]]; then
  echo "VM Template conf desn't exist - ${VM_TEMPLATE_CONF}. Exit."
  exit $EXIT_CODE_TEMPLATE_CONF_DOESNT_EXIST
fi

((STEP++))
echo "===== $STEP - stop teplate vm  ====="
xl shutdown -w ${VM_TEMPLATE_NAME}
CheckErrorCode $? "can't stop template vm - ${VM_TEMPLATE_NAME}" $EXIT_CODE_CANT_STOP_TEMPLATE_VM

((STEP++))
echo "===== $STEP - create teplate for new vm ====="
mount /dev/vg_data/lv_${VM_TEMPLATE_NAME} ${MOUNT_POINT}
CheckErrorCode $? "can't mount template partition" $EXIT_CODE_CANT_MOUNT_VM_TEMPLATE_PARTITION
cd ${MOUNT_POINT} || \
CheckErrorCode $? "can't change dir to template mountpoint - ${MOUNT_POINT}" $EXIT_CODE_CANT_CHANGE_DIR
#tar cvzf /root/default_vm.tar.gz --xattrs --exclude ./usr/src --exclude ./usr/portage/distfiles --exclude ./etc/ssh/ssh_host_* --exclude ./var/log/*.gz  ./
rm -f ${VM_TEMPLATE}
tar czf ${VM_TEMPLATE} --xattrs --exclude ./usr/src --exclude ./usr/portage/distfiles --exclude ./etc/ssh/ssh_host_* --exclude ./var/log/*.gz  ./
CheckErrorCode $? "can't create template" $EXIT_CODE_CANT_CREATE_TEMPLATE
cd /root || \
CheckErrorCode $? "can't change dir to /root"
umount  ${MOUNT_POINT}
CheckErrorCode $? "can't umount template partition" $EXIT_CODE_CANT_UMOUNT_VM_TEMPLATE_PARTITION

((STEP++))
echo "===== $STEP - run teplate vm ====="
xl create /etc/xen/config_xen/s_${VM_TEMPLATE_NAME}
CheckErrorCode $? "can't run template vm - ${VM_TEMPLATE_NAME}" $EXIT_CODE_CANT_RUN_TEMPLATE_VM

((STEP++))
echo "===== $STEP - create partiton ====="
lvcreate -n lv_${VM_NAME} -L ${VM_ROOT_SIZE} /dev/vg_data
CheckErrorCode $? "can't create LV" $EXIT_CODE_LVCREATE
mkfs.ext4 -L ${VM_NAME} /dev/vg_data/lv_${VM_NAME}
CheckErrorCode $? "can't create ext4 fs" $EXIT_CODE_MKFS
mount /dev/vg_data/lv_${VM_NAME} ${MOUNT_POINT}
CheckErrorCode $? "cant mount new LV" $EXIT_CODE_MOUNT

((STEP++))
echo "===== $STEP - extract data from template ====="
#tar xvpzf /root/default_vm.tar.gz --xattrs -C /mnt/gentoo/
tar xpzf ${VM_TEMPLATE} --xattrs -C ${MOUNT_POINT}
CheckErrorCode $? "cant mount new LV" $EXIT_CODE_TAR

((STEP++))
echo "===== $STEP - set param for new VM ====="
sed -i -e "s#default-vm#${VM_NAME}#" ${MOUNT_POINT}/etc/ssmtp/ssmtp.conf
CheckErrorCode $? "cant set ${VM_NAME} in ${MOUNT_POINT}/etc/ssmtp/ssmtp.conf"
sed -i -e "s#default-vm#${VM_NAME}#" ${MOUNT_POINT}/etc/snmp/snmpd.conf
CheckErrorCode $? "cant set ${VM_NAME} in ${MOUNT_POINT}/etc/snmp/snmpd.conf"
sed -i -e "s#default-vm#${VM_NAME}#" ${MOUNT_POINT}/etc/conf.d/hostname
CheckErrorCode $? "cant set ${VM_NAME} in ${MOUNT_POINT}/etc/conf.d/hostname"
sed -i -e "s#config_eth0=\".*#config_eth0=\"${VM_IP} netmask ${VM_MASK} brd ${FIRST_OCTET_VM_TEMPLATE}.255\"#" ${MOUNT_POINT}/etc/conf.d/net
CheckErrorCode $? "cant set ip in ${MOUNT_POINT}/etc/conf.d/net"
sed -i -e "s#routes_eth0=.*#routes_eth0=\"default via ${FIRST_OCTET_VM_TEMPLATE}.1 metric 10\"#" ${MOUNT_POINT}/etc/conf.d/net
CheckErrorCode $? "cant set gw in ${MOUNT_POINT}/etc/conf.d/net"
sed -i -e "s# ${VM_TEMPLATE_IP} # ${VM_IP} #"  ${MOUNT_POINT}/var/lib/iptables/rules-save
CheckErrorCode $? "cant set ip in ${MOUNT_POINT}/var/lib/iptables/rules-save"

((STEP++))
echo "===== $STEP - clear template data in new VM ====="
rm -f ${MOUNT_POINT}/etc/ssh/ssh_host_*
rm -f ${MOUNT_POINT}/var/log/*.gz
true > ${MOUNT_POINT}/var/log/messages
true > ${MOUNT_POINT}/var/log/dmesg
true > ${MOUNT_POINT}/var/log/net-snmpd.log

((STEP++))
echo "===== $STEP - umount new vm partition ====="
cd /root || \
umount ${MOUNT_POINT}
CheckErrorCode $? "cant umount new LV" $EXIT_CODE_UMOUNT

((STEP++))
echo "===== $STEP - create new vm xen config ====="
cp /etc/xen/config_xen/s_default-vm /etc/xen/config_xen/s_${VM_NAME}
CheckErrorCode $? "cant create xen config for new vm" $EXIT_CODE_NEW_VM_CONF
sed -i -e "s#default-vm#${VM_NAME}#g" /etc/xen/config_xen/s_${VM_NAME}
CheckErrorCode $? "cant set new VM name in /etc/xen/config_xen/s_${VM_NAME}"
sed -i -e "s#^memory =.*#memory = ${VM_MEM}#g"  /etc/xen/config_xen/s_${VM_NAME}
CheckErrorCode $? "cant set new VM memory in /etc/xen/config_xen/s_${VM_NAME}"
sed -i -e "s#^maxmem =.*#maxmem = ${VM_MAX_MEM}#g"  /etc/xen/config_xen/s_${VM_NAME}
CheckErrorCode $? "cant set new VM maxmem  in /etc/xen/config_xen/s_${VM_NAME}"
sed -i -e "s#^cpus =.*#cpus = ${CPUS}#g"  /etc/xen/config_xen/s_${VM_NAME}
CheckErrorCode $? "cant set new VM cpus in /etc/xen/config_xen/s_${VM_NAME}"
sed -i -e "s#^vcpus =.*#vcpus = ${VCPU}#g"  /etc/xen/config_xen/s_${VM_NAME}
CheckErrorCode $? "cant set new VM vcpus in /etc/xen/config_xen/s_${VM_NAME}"

echo "======== ${STEP}.1 - search free mac for new vm ====="
FREE_MAC=FALSE
for i in $(seq "$LAST_OCTET" 99); do
  if grep -q -e "mac=00:16:3e:23:10:$i" /etc/xen/config_xen/s_* ; then
    echo "00:16:3e:23:10:$i - in use"
  else
    FREE_MAC=TRUE
    echo "00:16:3e:23:10:$i - FREE"
    break
  fi
done

echo "======== ${STEP}.2 - set free mac for new vm ====="
if [[ $FREE_MAC == "TRUE" ]]; then
  sed -i -e "s#vif = \[ 'mac=00:16:3e:23:10:[0-9]*,\(.*\)#vif = \[ 'mac=00:16:3e:23:10:$i,\1#" /etc/xen/config_xen/s_${VM_NAME}
else
  echo "Can't find FREE MAC in 00:16:3e:23:10:XX; Where XX = from $LAST_OCTET to 99"
  exit $EXIT_CODE_NO_FREE_MAC
fi

((STEP++))
echo "===== $STEP - NEW VM READY ====="
echo "please check config /etc/xen/config_xen/s_${VM_NAME}:"
echo
echo "don't forget add info about new VM to wiki:"
echo "1. Cluster resources"
echo "2. IP in use"
echo
echo "don't forget add new vm to cacti"
echo
echo "run vm: xl create /etc/xen/config_xen/s_${VM_NAME}"
echo "check vm: xl list ${VM_NAME}"
echo "debug console: xl console ${VM_NAME}; #CTRL+] - for exit"
