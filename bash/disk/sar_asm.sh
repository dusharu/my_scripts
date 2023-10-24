#!/bin/bash
################################################################################
#                                                                              #
#                   replace name disk to asm name in sar output                #
#                                                                              #
#                       mailto: dusharu17@gmail.com                            #
#                                                                   2018.07.27 #
################################################################################
############################## READ ME
# easy way
# works  like:
# ls -l /dev/oracleasm/* |\
#  awk '{  print $11 " " $9}' |\
#  sed -e 's#^\.\.\/##; s/^\(sd[a-z]\)[0-9]*/\1/; s#\/dev\/oracleasm\/##' |\
#  awk '{print "sed -e \"s#" $1 " #" $2 " #\" | \\"}'

############################## VAR
# ASM_DIR_ARRAY set without "/" in end
# Example
# /dev/oracleasm - OK
# /dev/oracleasm/ - FAIL
declare -a ASM_DIR_ARRAY=(/dev/oracleasm )
#SAR_PARAMETR=(-pd -f /var/log/sa/sa28 -s 00:00:00 -e 01:40:00)
SAR_PARAMETR=(-pd 1 1)


############################## MAIN
for ASM_DIR in "${ASM_DIR_ARRAY[@]}"; do
  #echo "work in ASM_DIR: $ASM_DIR"
  for disk in "$ASM_DIR"/*; do
    disk_insert_template="$(basename "${disk}")"
    disk_replace_template="$(lsblk "${disk}" |sed -ne '2p;' |awk '{print $1}')"
    if echo "${disk_replace_template}" | grep -e "sd[a-z]*1" &> /dev/null ; then
      # get sdd form sdd1
      disk_replace_template="${disk_replace_template:0:((${#disk_replace_template}-1))}"
    fi
    if echo  "${disk_replace_template}" | grep -e "p[0-9]$" &> /dev/null ; then
      #get 360002ac000000000000000660000c700 from 360002ac000000000000000660000c700p1
      disk_replace_template="${disk_replace_template:0:((${#disk_replace_template}-2))}"
    fi
    SED_CMD="${SED_CMD} s#${disk_replace_template} #_${disk_insert_template}_#;"
    echo "s#${disk_insert_template}#_${disk_replace_template}_#;"
  done
done

echo "$SED_CMD"

echo "RUN SAR - $(date):"
#sar ${SAR_PARAMETR} | sed -e "${SED_CMD}"
sar "${SAR_PARAMETR[@]}" | sed -e "${SED_CMD}"
