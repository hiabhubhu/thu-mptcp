#!/bin/bash

SERVERIP="101.200.81.7"                      # Default server IP
filepath="${SERVERIP}/blocks/"               # Server file path
# Configuration Path
PATH_FL="./settings/filelist.txt"            # File list
PATH_CC="./settings/congestion_control.txt"  # Congestion control
PATH_BUF="./settings/buffer_size.txt"        # Buffer size
PATH_SCH="./settings/scheduler.txt"          # Scheduler
# Array
list_iface=()                                # Interfaces with state up
list_fl=()                                   # File list
list_cc=()                                   # Congestion control
list_buf=()                                  # Transmitting buffer size
list_sch=()                                  # Scheduler
##############################################################################
# interfaces
function get_iface
{
    for iface in `ls /sys/class/net/ | grep wlan`; do
	if [ `cat /sys/class/net/${iface}/operstate` = "up" ]; then
	    list_iface+=(${iface})
	fi
    done
    echo "Up Interfaces(${#list_iface[@]}): ${list_iface[@]}"
}
# file list
function get_fl
{
    while IFS= read -r line; do
	list_fl+=(${line})
    done < "$PATH_FL" 
    echo "File name(${#list_fl[@]}): ${list_fl[@]}"
}
# congestion control
function get_cc
{
    while IFS= read -r line; do
	list_cc+=(${line})
    done < "$PATH_CC"
    echo "Congestion Control(${#list_cc[@]}): ${list_cc[@]}"
}
# buffer
function get_buf
{
    while IFS= read -r line; do
	list_buf+=(${line})
    done < "$PATH_BUF"
    echo "Transmitting Buffer Size(${#list_buf[@]}): ${list_buf[@]}"
}
# scheduler
function get_sch
{
    while IFS= read -r line; do
	list_sch+=(${line})
    done < "$PATH_SCH"
    echo "Scheduler(${#list_sch[@]}): ${list_sch[@]}"
}
# countdown
function countdown
{
    seconds=$1
    info=$2
    while [[ $seconds -ge 0 ]]; do
	echo -ne "The ${info} will start in ${seconds} seconds...\033[0K\r"
	(( seconds -= 1 ))
	sleep 1
    done
}

# test function
# $1 - file name
# $2 - buffer size
# $3 - scheduler
# $4 - congestion control
function test
{
    clientpath="${root_dir}/${id}.`date +%Y.%m.%d.%H.%M.%S.%N`"
    # log client configuration for each test
    mkdir -p ${clientpath}
    echo $1 >> "${clientpath}/file_name"          # file name
    echo $2 >> "${clientpath}/buffer"             # buffer_size
    echo $3 >> "${clientpath}/scheduler"          # scheduler
    echo $4 >> "${clientpath}/congestion_control" # congestion control
    echo ${id} >> "${clientpath}/id"              # current test id
    # kill tcpdump & loop.sh in both server and client
    ssh root@${SERVERIP} pkill tcpdump
    ssh root@${SERVERIP} pkill loop.sh
    sudo pkill tcpdump
    sudo pkill loop.sh
    # server - change configuration
    # cc | buffer | scheduler
    echo "## SERVER CONFIG"
    ssh root@${SERVERIP} sysctl net.ipv4.tcp_congestion_control=${4}
    ssh root@${SERVERIP} sysctl net.ipv4.tcp_wmem="\"${2} ${2} ${2}\""
    ssh root@${SERVERIP} sysctl net.mptcp.mptcp_scheduler=${3}
    # client - change configuration
    # cc | buffer | scheduler
    echo "## CLIENT CONFIG"
    sudo sysctl net.ipv4.tcp_congestion_control=${4}
    sudo sysctl net.ipv4.tcp_rmem="${2} ${2} ${2}"
    sudo sysctl net.mptcp.mptcp_scheduler=${3}
    # log server configuration for each test
    serverpath="${root_dir}/${id}.`date +%Y.%m.%d.%H.%M.%S.%N`"
    ssh root@${SERVERIP} mkdir -p ${serverpath}
    ssh root@${SERVERIP} "echo $1 >> \"${serverpath}/file_name\""          # file name
    ssh root@${SERVERIP} "echo $2 >> \"${serverpath}/rx_buf\""             # buffer size
    ssh root@${SERVERIP} "echo $3 >> \"${serverpath}/scheduler\""          # scheduler
    ssh root@${SERVERIP} "echo $4 >> \"${serverpath}/congestion_control\"" # congestion control
    ssh root@${SERVERIP} "echo ${id} >> \"${serverpath}/id\""              # current test id
    # server - run tcpdump & loop.sh
    ssh root@${SERVERIP} mkdir "${serverpath}/eth1"
    ssh root@${SERVERIP} "echo ${SERVERIP} >> \"${serverpath}/eth1/ip_address\""
    ssh root@${SERVERIP} "echo `date +%s.%N` >> \"${serverpath}/eth1/start_time\""
    # server - create a random file to avoid buffering by the server and Mobile
    ssh root@${SERVERIP} "dd if=/dev/urandom of=/var/www/blocks/${1} bs=200MB count=1"
    echo "## START SERVER TCPDUMP"
    ssh root@${SERVERIP} tcpdump tcp -U -s 96 -i eth1 -w "${serverpath}/eth1/${SERVERIP}.pcap" &
    # client - run tcpdump & loop.sh for each interface
    echo "## START CLIENT TCPDUMP"
    for iface in ${list_iface[@]}; do
	mkdir "${clientpath}/${iface}"
	IP=`ifconfig ${iface} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'`
	echo ${IP} >> "${clientpath}/${iface}/ip_address"
	echo `date +%s.%N` >> "${clientpath}/${iface}/start_time"
	echo `iwconfig ${iface}` >> "${clientpath}/${iface}/iwconfig"
	sudo tcpdump tcp -U -s 96 -i ${iface} -w "${clientpath}/${iface}/${IP}.pcap" &
	sudo ./loop.sh -i ${iface} -o "${clientpath}/${iface}/throughput.log" &
    done
    # wait for 15 second
    countdown 15 "download"
    # wget
    wget --delete-after "${SERVERIP}/blocks/${1}"
    #rm ${file}
    # server - kill tcpdump & loop.sh
    ssh root@${SERVERIP} pkill tcpdump
    ssh root@${SERVERIP} pkill loop.sh
    ssh root@${SERVERIP} "echo `date +%s.%N` >> \"${serverpath}/eth1/end_time\""
    # server - remove the temporary file
    ssh root@${SERVERIP} "rm /var/www/blocks/${1}"
    # client - kill tcpdump & loop.sh
    sudo pkill tcpdump
    sudo pkill loop.sh
    for iface in ${list_iface[@]}; do
	echo `date +%s.%N` >> "${clientpath}/${iface}/end_time"
    done
}
###############################################################################
while [ -n "$1" ]; do
    case $1 in
	-s | --server  )  shift; SERVERIP=$1 ;;
	*  )              ;;
    esac
    shift;
done
# get total experiments start time
root_dir=`date +%Y.%m.%d.%H.%M.%S.%N`
mkdir ${root_dir}
# get configurable parameters information
get_iface; get_fl; get_cc; get_buf; get_sch
# test file rx tx sch cc
id=1
while true; do
    clear
    
    file=${list_fl[ $RANDOM % ${#list_fl[@]} ] }
    cc=${list_cc[ $RANDOM % ${#list_cc[@]} ] }
    buf=${list_buf[ $RANDOM % ${#list_buf[@]} ] }
    sch=${list_sch[ $RANDOM % ${#list_sch[@]} ] }

    echo "### START TEST ${id}"
    echo "file = ${file}  cc = ${cc}  buf = ${buf}  sch = ${sch}"
    echo "[`date +%s.%N`] START TEST #${id} (file=${file} cc=${cc} buf=${buf} sch=${sch})" >> "${root_dir}/.log"
    test ${file} ${buf} ${sch} ${cc}
    echo "[`date +%s.%N`] END TEST" >> "${root_dir}/.log"
    (( id += 1 ))
    countdown 15 "next test"
done
