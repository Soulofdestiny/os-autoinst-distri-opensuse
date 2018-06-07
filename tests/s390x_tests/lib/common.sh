# Copyright (C) 2018 IBM Corp.
# 
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

REGEX_KERNEL_PROBLEMS="(badness|kernel bug|corruption|erp failed|dereference|oops|stack overflow|backtrace|cpu capability change)"

init_tests(){
   TESTCASE_SECTION_COUNTER=0;
   TESTCASE_NUMBER_OF_FAILED=0 
   TESTCASE_NUMBER_OF_PASS=0 
}


show_test_results(){
 echo 
 echo "===> Results:"
 echo
 echo "Failed tests     : $TESTCASE_NUMBER_OF_FAILED"
 echo "Successful tests : $TESTCASE_NUMBER_OF_PASS"
 echo
 if [ $TESTCASE_NUMBER_OF_FAILED -ne 0 ]; then return 1; fi;
}

assert_exec(){
   local EXPECTEDRET="$1";
   local STARTTIME="$SECONDS"
   shift;
   echo "[EXECUTING] : '$@'"
   eval "$@"
   local RET="$?"
   assert_warn $RET $EXPECTEDRET "command execution with $(($SECONDS - $STARTTIME)) seconds runtime"
   return $?
}

assert_warn () {
	local i;
	local PASSED="[PASSED]";
	local FAILED="[FAILED]";
	local EXITCODE="$1";
	local MESSAGE="${!#}";
	local ASSERTCODES_COUNT=$(($#-2));
	local ASSERTCODES="${@:2:$ASSERTCODES_COUNT}";
	local FOUND=false;

	for (( i = 2; i < $#; i++ )); do
		if [ "$EXITCODE" == "${!i}" ]; then
			FOUND=true;
			break;
		fi
	done

	if $FOUND; then
		echo -e "$PASSED :: $MESSAGE :: $EXITCODE";
		TESTCASE_NUMBER_OF_PASS="$(($TESTCASE_NUMBER_OF_PASS + 1 ))";
		return 0;
	fi
	echo -e "$FAILED :: $MESSAGE :: $EXITCODE (expected ${ASSERTCODES// /, })";
	TESTCASE_NUMBER_OF_FAILED="$(($TESTCASE_NUMBER_OF_FAILED + 1 ))";
	return 1
}

assert_fail(){
	local i;
	local PASSED="[PASSED]";
	local FAILED="[FAILED]";
	local EXITCODE="$1";
	local MESSAGE="${!#}";
	local ASSERTCODES_COUNT=$(($#-2));
	local ASSERTCODES="${@:2:$ASSERTCODES_COUNT}";
	local FOUND=false;

	for (( i = 2; i < $#; i++ )); do
		if [ "$EXITCODE" == "${!i}" ]; then
			FOUND=true;
			break;
		fi
	done

	if $FOUND; then
		echo -e "$PASSED :: $MESSAGE :: $EXITCODE";
		TESTCASE_NUMBER_OF_PASS="$(($TESTCASE_NUMBER_OF_PASS + 1 ))";
		return 0;
	fi
	echo -e "$FAILED :: $MESSAGE :: $EXITCODE (expected ${ASSERTCODES// /, })";
	echo -e "\nATTENTION: THIS CAUSES A DIRECT STOP OF THE TESTCASE";
	TESTCASE_NUMBER_OF_FAILED="$(($TESTCASE_NUMBER_OF_FAILED + 1 ))";
	[ "$(type -t show_test_results)" == "function" ] && show_test_results;
	echo "** END OF TESTCASE";
	exit 1;
}

isVM(){
 local GUESTNAME=""
 local GUESTNO=""

   if [ ! -e /proc/sysinfo ] ; then
    echo "Cannot access /proc/sysinfo" >&1
    exit 1
   fi

   GUESTNAME="$(cat /proc/sysinfo | grep -i VM00.Name | sed 's/^.*:[[:space:]]*//g;s/[[:space:]]//g' | tr '[a-z]' '[A-Z]')"

   if [ -z "$GUESTNAME" ];then
    return 1
   fi
   if [ -n "$GUESTNAME" ];then
      load_vmcp
      return 0
   fi
   return 1
}



load_vmcp(){
 local GUESTNAME=""

   if [ ! -e /proc/sysinfo ] ; then
    echo "Cannot access /proc/sysinfo" >&1
    exit 1
   fi

   GUESTNAME="$(cat /proc/sysinfo | grep -i VM00.Name | sed 's/^.*:[[:space:]]*//g;s/[[:space:]]//g' | tr '[a-z]' '[A-Z]')"

   if [ -n "$GUESTNAME" ];then
        `vmcp q cpus > /dev/null 2>&1`
        if [ $? -ne 0 ];then
         modprobe vmcp >/dev/null 2>&1
         echo "Module vmcp loaded"
        fi
        return 0
   fi
   return 1
}

start_section(){
   echo -e "\n#####################################################################################" 
   echo -e "### [$1] START SECTION : $2" 
   echo -e "###"
   echo -e "### TIMESTAMP: $(date --date="today" "+%Y-%m-%d %H:%M:%S")\n"
   dmesg -c | egrep -C1000 -i "$REGEX_KERNEL_PROBLEMS" && assert_warn 1 0 "Kernel messages"
   return 0
}

end_section(){
   dmesg -c | egrep -C1000 -i "$REGEX_KERNEL_PROBLEMS" && assert_warn 1 0 "Kernel messages"
   echo -e "\n### TIMESTAMP: $(date --date="today" "+%Y-%m-%d %H:%M:%S")"
   echo -e "###" 
   echo -e "### [$1] END SECTION";
   echo -e "#####################################################################################\n" 
   return 0
}

section_start () {
    start_section "$TESTCASE_SECTION_COUNTER" "$1"
    section_up;
}
section_end () {
    section_down;
    end_section "$TESTCASE_SECTION_COUNTER"
}
section_up () {
  TESTCASE_SECTION_COUNTER=$(( TESTCASE_SECTION_COUNTER + 1 ));
  return $TESTCASE_SECTION_COUNTER;
}
section_down () {
  test "$TESTCASE_SECTION_COUNTER" -gt "0" && TESTCASE_SECTION_COUNTER=$(( TESTCASE_SECTION_COUNTER - 1 ));
  return $TESTCASE_SECTION_COUNTER;
}
########################################################
###
### This function remove all network interfaces expect LAN eth0
###
### $1 : DEVNOs of the LAN interface which not to be delete
###
### Example with LAN-Device=0.0.f5f0,0.0.f5f1,0.0.f5f2:
###
### net_cleanup_vm $1
### net_cleanup_vm "$cLANa $cLANb $cLANc"
### net_cleanup_vm "0.0.F5F0 0.0.F5F1 0.0.F5F2"
###

net_cleanup_vm(){
 local LAN="$1"
 local DEFAULT2=""

 load_vmcp

 LAN="$(echo ${LAN} | tr 'a-z' 'A-Z')"
 echo "Used LAN interfaces: $LAN"

 DEFAULT2="$( vmcp -b 20000 'q v osa' | awk '/^OSA ..* ON/{print $2}' )"
 echo "The following devices are attached at the moment: "$DEFAULT2

 for i in $LAN
  do LAN="$(echo $i | sed 's/0\..\.//' )"
     DEFAULT2="$(echo $DEFAULT2|sed s/$LAN//)"
  done

 echo "The following devices will be detached now: "$DEFAULT2

 for i in $DEFAULT2
 do
    echo "Delete DEVICE $i"
    vmcp "det $i"
    sleep 1
 done

 echo
 vmcp 'q v osa'
 echo

 echo "Waiting for VM-cleanup (1 sec.)"
 sleep 1
}


########################################################
###
### This function remove all network interfaces expect LAN eth0
###
### $1 : 1st DEVNO of the LAN interface which not to be delete
###
### Example with LAN-Device=0.0.f500,0.0.f501,0.0.f502:
###
### net_cleanup_linux $1
### net_cleanup_linux "$sLANa"
### net_cleanup_linux "0.0.f500"
###

net_cleanup_linux(){
 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local LAN="$1"
 local IFNAME=""
 local G1=""

 echo
 lsqeth -p
 echo

 DEFAULT1="$(ls -1 $P0 |grep 0. |grep -v $LAN )"
 echo "DEVICEs which will be delete: $DEFAULT1"

 for i in $DEFAULT1
 do
    IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$i/if_name)"
    echo "Delete interface $IFNAME with DEVICE $i"
    echo 0 > $P0$i/online
    echo 1 > $P0$i/ungroup
 done

 echo
 lsqeth -p
 echo

# LCS CleanUp:

 local P1="/sys/bus/ccwgroup/drivers/lcs/"

 DEFAULT2="$(ls -1 $P1 |grep 0. |grep -v $LAN )"

 if [ -z "$DEFAULT2" ]; then
  echo
  echo "No LCS Device"
  echo
  return
 else
  for j in $DEFAULT2
   do
    IFNAME="$(ls /sys/bus/ccwgroup/drivers/lcs/$j/net)"
    echo "Delete interface $IFNAME with DEVICE $j"
    echo 0 > $P1$j/online
    echo 1 > $P1$j/ungroup
   done
 echo "Waiting for Linux-cleanup (1 sec.)"
 sleep 1
 fi
}


########################################################
###
### This function set a VLAN interface
###
### $1 : Name of the LOG and PID
### $2 : Name of the base interface
### $3 : VLAN-ID
### $4 : IP-adress of the new VLAN-interface
### $5 : Netmask of the new VLAN-interface
### $6 : Broadcast-adress of the new VLAN-interface
### $7 : New VLAN-interface-name
###
### Example:
###
### net_vlan_up "$1"       "$2"      "$3"      "$4"            "$5"          "$6"             "$7"
### net_vlan_up "$LOGNAME" "$IFNAME" "$VLANID" "$IP"           "$MASK"       "$BROAD"         "$VLANNAME"
### net_vlan_up "31c"      "bond1"   "200"     "10.200.43.100" "255.255.0.0" "10.200.255.255" "VLAN100"
###

net_vlan_up(){
 local LOGNAME="$1"
 local IFNAME="$2"
 local VLANID="$3"
 local IP="$4"
 local MASK="$5"
 local BROAD="$6"
 local VLANNAME="$7"
 local xDATE=""
 local NEW="$VLANNAME"

 echo
 echo "<<< NEW-VLAN-Interface: $NEW >>>"
 echo
 echo
 xDATE=`date +%F_%T`
 echo $xDATE

 echo
 #vconfig add $IFNAME $VLANID >  $xDATE-$LOGNAME.log  2>&1
 ip link add dev $IFNAME.$VLANID link $IFNAME name $VLANNAME type vlan id $VLANID > $xDATE-$LOGNAME.log  2>&1 
 assert_warn $? 0 "Set VLAN ok?"
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 #ifconfig $NEW >   $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW >   $xDATE-$LOGNAME.log  2>&1
 echo
 #ifconfig $NEW $IP netmask $MASK broadcast $BROAD >  $xDATE-$LOGNAME.log  2>&1
 local ip_addr="$IP/$MASK"
 ip addr add $ip_addr brd + dev $NEW > $xDATE-$LOGNAME.log  2>&1
 ip link set dev $NEW up > $xDATE-$LOGNAME.log  2>&1
 echo
 #ifconfig $NEW >  $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat  $xDATE-$LOGNAME.log
 echo

}

########################################################
###
### This function group 3 DEVNOs to a new qdio-interface
###
### $1 : 1st DEVNO of the LAN interface
### $2 : 2nd DEVNO of the LAN interface
### $3 : 3rd DEVNO of the LAN interface
### $4 : Layer 2 or 3 [1/0]
### $5 : Portno [0/1] only valid for 1GbE-OSA-Express3
### $6 : CHPID
###
### Example:
###
### net_group_linux $1         $2         $3         $4      $5		$6
### net_group_linux $cE1a      $cE1b      $cE1c      $cP1Lay $cP1No	$cE1Chp
### net_group_linux "0.0.f200" "0.0.f201" "0.0.f202" "0"     "0"	85
###

net_group_linux(){
 local P0="/sys/bus/ccwgroup/drivers/qeth"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local LANb="$2"
 local LANc="$3"
 local LAYER="$4"
 local PORTNO="$5"
 local CHPID="$6"

 echo "Network devices before configuration";
 lsqeth -p
 echo

 echo
 echo "Set CHPID ON ..."
 echo chchp -c 1 $CHPID
 echo chchp -v 1 $CHPID
 echo

 echo "Configure device"
 printf "%-20s : %s\n" "Group device nodes" "$LANa,$LANb,$LANc";
 printf "intoooooo %s\n" "${P1}"
 echo "$LANa,$LANb,$LANc" > "${P1}" || return 1;
 printf "%-20s : %s\n" "Set network layer" "${LAYER}";
 echo "$LAYER" > "${P0}/${LANa}/layer2" || return 1;

 echo
 CardType="$( cat /sys/bus/ccwgroup/drivers/qeth/$LANa/card_type )"
 printf "%-20s : %s\n" "Set port number" "${PORTNO}";
 if [ "HiperSockets" = "$CardType" ];then
  echo "CardType=$CardType -- HiperSocket-Device has no port-number => nothing todo"
 else
  echo "CardType=$CardType -- OSA-Device => set port-number"
  echo "$PORTNO" > "${P0}/${LANa}/portno" || return 1;
 fi
 echo

 echo "Set device online '${P0}/${LANa}'"
 echo 1 > "${P0}/${LANa}/online" || return 1;
 echo

 echo "Network devices after configuration";
 lsqeth -p
 echo

 return 0;
}



########################################################
###
### Setup new interface
###
### $1 : 1st DEVNO of the new interface
### $2 : IP-Adress [10.x.x.x]
### $3 : Netmask [255.255.0.0]
### $4 : Broadcast [10.x.255.255]
### $5 : MacAdress [02:40:01:87:08:15] - optional -
###
### Example:
###
### net_ifup_linux $1     $2         $3            $4             $5
### net_ifup_linux $cE1a  $cE1ip     $cE1mask      $cE1broad      $cE1mac
### net_ifup_linux "f600" "10.1.1.1" "255.255.0.0" "10.1.255.255" "02:50:03:87:08:15"
###

net_ifup_linux(){

 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local IP="$2"
 local MASK="$3"
 local BROAD="$4"
 local MAC="$5"
 local IFNAME=""
 local LAYER2=""

IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/if_name)"
if [ "" = "$IFNAME" ]; then
  echo
  echo "ERROR: <<< Interface with DEVNO $LANa not operational >>>"
  echo
  return
else
  echo
  echo "Interface with DEVNO $LANa ok"
  echo
fi

LAYER2="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/layer2)"
if [ "1" = "$LAYER2" ]; then
  echo
  echo "Layer2 interface"
  echo
  #ifconfig $IFNAME hw ether $MAC
  ip link set $IFNAME address $MAC
  ip link set $IFNAME up
  echo
else
  echo
  echo "Layer3 interface"
  echo
fi

echo "Set IP-Adr"
echo
#ifconfig $IFNAME $IP netmask $MASK broadcast $BROAD
local ip_addr="$IP/$MASK"
ip addr add $ip_addr brd + dev $IFNAME
ip link set dev $IFNAME up

echo
#ifconfig $IFNAME
ip addr show $IFNAME
echo
}


########################################################
###
### This function attaches DEVNOs to the VM-guest
###
### $1 : DEVNO-list which should be attached to the vm-guest
###
### Example:
###
### net_att_devno_vm $1
### net_att_devno_vm "$cE1a $cE1b $cE1c"
### net_att_devno_vm "0.0.e000 0.0.e001 0.0.e002"
###

net_att_devno_vm(){
 local DEFAULT3="$1"

 load_vmcp

 echo
 vmcp 'q v osa'
 echo

 echo "DEVICEs which will be attached: $DEFAULT3"

 for i in $DEFAULT3
 do
    j="$(echo $i | sed 's/0\..\.//' )"
    echo "Attach DEVICE $j"
    vmcp "att $j *"
    sleep 1
 done

 echo
 vmcp 'q v osa'
 echo

 echo "Waiting for new attachements (1 sec.)"
 sleep 1
}






########################################################
###
###  network_tools.sh :: net_uping()
###
### This function start Unicast-PINGs in a LOOP and send the output to a local logfile
###
### $1 : Ifname of the outgoing interface
### $2 : Ping IP-Adress
### $3 : Start Loop
### $4 : End Loop (Iteration = $END - $START)
### $5 : Name of the LOG and PID
### $6 : Options (-f for floodping or -s 65507 for packetsize)
###    Remark: '-c' is already defined with $i of the loop
### $7 : RemoteHost (start ping via SSH from another host) - optional -
###    Remark: $SSH = the command to use for ssh
###
### Example:
###
### net_uping   $1       $2      $3      $4    $5         $6                 $7
### net_uping   $sE1     $sE1ip  "1"     "10"  "40b_c2s"  "-f -s 65507 ..."  $cHOST
### net_uping   $IFNAME  $IP     $START  $END  $LOGNAME   $OPTION            $REMOTE
###

net_uping(){
 local IFNAME="$1"
 local IP="$2"
 local START="$3"
 local END="$4"
 local LOGNAME="$5"
 local OPTION="${6}"
 local REMOTE="${7}"
 local XMOTE=""
 local MYPID=""
 local RET=""
 local i=""
 local xDATE=""
 local SSH=${SSH:-"ssh -i /root/.ssh/id_dsa.autotest -o StrictHostKeyChecking=no -oProtocol=2 -q -n -oBatchMode=yes "}

if [ -z "$REMOTE" ];then
 echo "--->>>>>>>>>> Local PING <<<<<<<<<<---"
 XMOTE=""
else
 echo "<<<<<<<<<<=== Remote PING ===>>>>>>>>>>"
 XMOTE="$SSH $REMOTE "
fi

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo

for (( i = $START; i <= $END; i++ ))      ### Loop ###
 do
  echo
  echo '<<<<<<<<<< Loop-No.: ' $i ' >>>>>>>>>>>'
  echo
  echo '>->-> IPv4: Unicast PING <-<-<'
  echo
  xDATE=`date +%F_%T`
  echo $xDATE
  $XMOTE ping $IP -c 3                    ### wake up ###
  echo
  (
   $XMOTE ping $IP -c $i $OPTION  >  $xDATE-$LOGNAME-uping-$i.log  2>&1
   head -n1 $xDATE-$LOGNAME-uping-$i.log && echo "[...]" &&  tail -n3 $xDATE-$LOGNAME-uping-$i.log
  ) &
   MYPID=$!
   wait $MYPID
   RET=$?
   echo $MYPID > $xDATE-$LOGNAME-uping-$i.PID
  sleep 1
   cat $xDATE-$LOGNAME-uping-$i.log | grep ' 0% packet loss'
   assert_warn $? 0 "$xDATE-$LOGNAME-uping-$i.log: no packet loss!"
  echo
  echo
  echo " >->-> End of Loop <-<-<"
  echo
done

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo
}

########################################################
###
###  network_tools.sh :: net_uping6()
###
### This function start Unicast-PINGs in a LOOP and send the output to a local logfile
###
### $1 : Ifname of the outgoing interface
### $2 : Ping IP-Adress - IPv6
### $3 : Start Loop
### $4 : End Loop (Iteration = $END - $START)
### $5 : Name of the LOG and PID
### $6 : Options (-f for floodping or -s 65507 for packetsize)
###    Remark: '-c' is already defined with $i of the loop
### $7 : RemoteHost (start ping via SSH from another host) - optional -
###    Remark: $SSH = the command to use for ssh
###
### Example:
###
### net_uping6  $1       $2      $3      $4    $5         $6                 $7
### net_uping6  $sE1     $sE1ip  "1"     "10"  "40b_c2s"  "-f -s 65507 ..."  $cHOST
### net_uping6  $IFNAME  $IP     $START  $END  $LOGNAME   $OPTION            $REMOTE
###

net_uping6(){
 local IFNAME="$1"
 local IP="$2"
 local START="$3"
 local END="$4"
 local LOGNAME="$5"
 local OPTION="${6}"
 local REMOTE="${7}"
 local XMOTE=""
 local MYPID=""
 local RET=""
 local i=""
 local xDATE=""
 local SSH=${SSH:-"ssh -i /root/.ssh/id_dsa.autotest -o StrictHostKeyChecking=no -oProtocol=2 -q -n -oBatchMode=yes "}

if [ -z "$REMOTE" ];then
 echo "--->>>>>>>>>> Local PING <<<<<<<<<<---"
 XMOTE=""
else
 echo "<<<<<<<<<<=== Remote PING ===>>>>>>>>>>"
 XMOTE="$SSH $REMOTE "
fi

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo

for (( i = $START; i <= $END; i++ ))      ### Loop ###
 do
  echo
  echo '<<<<<<<<<< Loop-No.: ' $i ' >>>>>>>>>>>'
  echo
  echo '>->-> IPv6: Unicast PING <-<-<'
  echo
  xDATE=`date +%F_%T`
  echo $xDATE
  $XMOTE ping6 -I $IFNAME $IP -c 3        ### wake up ###
  echo
  (
   $XMOTE ping6 -I $IFNAME $IP -c $i $OPTION  >  $xDATE-$LOGNAME-uping6-$i.log  2>&1
   head -n1 $xDATE-$LOGNAME-uping6-$i.log && echo "[...]" &&  tail -n3 $xDATE-$LOGNAME-uping6-$i.log
  ) &
   MYPID=$!
   wait $MYPID
   RET=$?
   echo $MYPID > $xDATE-$LOGNAME-uping6-$i.PID
  sleep 1
   cat $xDATE-$LOGNAME-uping6-$i.log | grep ' 0% packet loss'
   assert_warn $? 0 "$xDATE-$LOGNAME-uping6-$i.log: no packet loss!"
  echo
  echo
  echo " >->-> End of Loop <-<-<"
  echo
done

 echo
 #$XMOTE ifconfig $IFNAME
 $XMOTE ip addr show $IFNAME
 echo
}


isIfconfigOrIP()
{
local IFCONFIG
if [ -f "/sbin/ifconfig" ]
then
    #echo "use ifconfig"
    #IFCONFIG="$(ls /sbin/ | grep -w ifconfig)"
    #echo $IFCONFIG
    return 0
elif [ -f "/sbin/ip" ]
then
     #echo "use ip"
     #IFCONFIG="$(ls /sbin/ | grep -w ip)"
     #echo $IFCONFIG
     return 1
fi
}


isVconfigOrIP()
{
if [ -f "/sbin/vconfig" ]
then
    #echo "use ifconfig"
    #IFCONFIG="$(ls /sbin/ | grep -w ifconfig)"
    #echo $IFCONFIG
    return 0
elif [ -f "/sbin/ip" ]
then
     #echo "use ip"
     #IFCONFIG="$(ls /sbin/ | grep -w ip)"
     #echo $IFCONFIG
     return 1
fi
}



########################################################
###
###  network_tools.sh :: net_ifup_linux_ip()
###
### Setup new interface
###
### $1 : 1st DEVNO of the new interface
### $2 : IP-Adress [10.x.x.x]
### $3 : Netmask [255.255.0.0]
### $4 : Broadcast [10.x.255.255]
### $5 : MacAdress [02:40:01:87:08:15] - optional -
###
### Example:
###
### net_ifup_linux_ip $1     $2         $3            $4             $5
### net_ifup_linux_ip $cE1a  $cE1ip     $cE1pref      $cE1broad      $cE1mac
### net_ifup_linux_ip "f600" "10.1.1.1" "16" "10.1.255.255" "02:50:03:87:08:15"
###

net_ifup_linux_ip(){

 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local IP="$2"
 local MASK="$3"
 local BROAD="$4"
 local MAC="$5"
 local IFNAME=""
 local LAYER2=""

IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/if_name)"
if [ "" = "$IFNAME" ]; then
  echo
  echo "ERROR: <<< Interface with DEVNO $LANa not operational >>>"
  echo
  return
else
  echo
  echo "Interface with DEVNO $LANa ok"
  echo
fi

LAYER2="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/layer2)"
if [ "1" = "$LAYER2" ]; then
  echo
  echo "Layer2 interface"
  echo
  #ifconfig $IFNAME hw ether $MAC
  ip link set $IFNAME address $MAC
  sleep 1
  ip link set $IFNAME up
  echo
else
  echo
  echo "Layer3 interface"
  echo
fi

echo "Set IP-Adr"
echo
local ip_addr="$IP/$MASK"
#ifconfig $IFNAME $IP netmask $MASK broadcast $BROAD
ip addr add $ip_addr dev $IFNAME
  sleep 1
ip link set dev $IFNAME up
echo
#ifconfig $IFNAME
ip addr show $IFNAME
echo

}


net_ifup_linux_ip6(){

 local P0="/sys/bus/ccwgroup/drivers/qeth/"
 local P1="/sys/bus/ccwgroup/drivers/qeth/group"
 local LANa="$1"
 local IP="$2"
 local MASK="$3"
 local BROAD="$4"
 local MAC="$5"
 local IFNAME=""
 local LAYER2=""

IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/if_name)"
if [ "" = "$IFNAME" ]; then
  echo
  echo "ERROR: <<< Interface with DEVNO $LANa not operational >>>"
  echo
  return
else
  echo
  echo "Interface with DEVNO $LANa ok"
  echo
fi

LAYER2="$(cat /sys/bus/ccwgroup/drivers/qeth/$LANa/layer2)"
if [ "1" = "$LAYER2" ]; then
  echo
  echo "Layer2 interface"
  echo
  #ifconfig $IFNAME hw ether $MAC
  ip link set $IFNAME address $MAC
  sleep 1
  ip link set $IFNAME up
  echo
else
  echo
  echo "Layer3 interface"
  echo
fi

echo "Set IP-Adr"
echo
local ip_addr="$IP/$MASK"
#ifconfig $IFNAME $IP netmask $MASK broadcast $BROAD
ip -6 addr add $ip_addr dev $IFNAME
  sleep 1
ip link set dev $IFNAME up
echo
#ifconfig $IFNAME
ip addr show $IFNAME
echo
}



####################################################
###
###  network_tools.sh :: net_vlan_up_ip()
###
### This function set a VLAN interface
###
### $1 : Name of the LOG and PID
### $2 : Name of the base interface
### $3 : VLAN-ID
### $4 : IP-adress of the new VLAN-interface
### $5 : Netmask of the new VLAN-interface
### $6 : Broadcast-adress of the new VLAN-interface
###
### Example:
###
### net_vlan_up_ip "$1"       "$2"      "$3"      "$4"            "$5"          "$6"
### net_vlan_up_ip "$LOGNAME" "$IFNAME" "$VLANID" "$IP"           "$PREFIX"     "$BROAD"
### net_vlan_up_ip "31c"      "bond1"   "200"     "10.200.43.100" "16" "10.200.255.255"
###

net_vlan_up_ip(){
 local LOGNAME="$1"
 local IFNAME="$2"
 local VLANID="$3"
 local IP="$4"
 local MASK="$5"
 local BROAD="$6"
 local xDATE=""
 local NEW="$IFNAME.$VLANID"

 echo
 echo "<<< NEW-VLAN-Interface: $NEW >>>"
 echo
 echo
 xDATE=`date +%F_%T`
 echo $xDATE

 echo
 vconfig add $IFNAME $VLANID >  $xDATE-$LOGNAME.log  2>&1
 assert_warn $? 0 "Set VLAN ok?"
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 # ifconfig $NEW >   $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW  > $xDATE-$LOGNAME.log  2>&1
 local ip_addr="$IP/$MASK"

 ip addr add $ip_addr dev $NEW > $xDATE-$LOGNAME.log  2>&1
  sleep 1
 ip link set dev $NEW up > $xDATE-$LOGNAME.log  2>&1

 echo
# ifconfig $NEW $IP netmask $MASK broadcast $BROAD >  $xDATE-$LOGNAME.log  2>&1
 ip addr show $NEW  > $xDATE-$LOGNAME.log  2>&1
 echo
# ifconfig $NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/config >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat /proc/net/vlan/$NEW >  $xDATE-$LOGNAME.log  2>&1
 echo
 cat  $xDATE-$LOGNAME.log
 echo

}

