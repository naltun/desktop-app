#!/bin/bash

#
#  Script to control the Split-Tunneling functionality for Linux.
#  It is a part of Daemon for IVPN Client Desktop.
#  https://github.com/ivpn/desktop-app/daemon
#
#  Created by Stelnykovych Alexandr.
#  Copyright (c) 2021 Privatus Limited.
#
#  This file is part of the Daemon for IVPN Client Desktop.
#
#  The Daemon for IVPN Client Desktop is free software: you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as published by the Free
#  Software Foundation, either version 3 of the License, or (at your option) any later version.
#
#  The Daemon for IVPN Client Desktop is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#  details.
#
#  You should have received a copy of the GNU General Public License
#  along with the Daemon for IVPN Client Desktop. If not, see <https://www.gnu.org/licenses/>.
#

# Split Tunneling cgroup parameters
_cgroup_name=ivpn-exclude
_cgroup_classid=0x4956504e      # Anything from 0x00000001 to 0xFFFFFFFF
_cgroup_folder=/sys/fs/cgroup/net_cls/${_cgroup_name}

# Routing tabel configuration for packets coming from Split-Tunneling environment
_routing_table_name=ivpn-exclude-tbl
_routing_table_weight=17            # Anything from 1 to 252

# Additional parameters
_iptables_locktime=2

# Backup folder name.
# This folder contains temporary data to be able to clean everything correctly 
_backup_folder_name=ivpn-exclude-tmp

# Info: The 'mark' value for packets coming from the Split-Tunneling environment.
# Using here value 0xca6c. It is the same as WireGuard marking packets which were processed.
# That allows us not to be aware of changes in the routing policy database on each new connection of WireGuard.
# Extended description:
# The WG is updating its routing policy rule (ip rule) on every new connection:
#   32761:	not from all fwmark 0xca6c lookup 51820
# The problem is that each time this rule appears with the highest priority.
# So, this rule absorbs all packets which are not marked as 0xca6c
_packets_fwmark_value=0xca6c        # Anything from 1 to 2147483647

# Paths to standard binaries
_bin_iptables=/sbin/iptables
_bin_ip6tables=/sbin/ip6tables
_bin_runuser=/usr/sbin/runuser
_bin_ip=/sbin/ip
_bin_awk=/usr/bin/awk
_bin_grep=/usr/bin/grep
_bin_dirname=/usr/bin/dirname
_bin_sed=/usr/bin/sed

#Variables vill be initialized later:
_def_interface_name=""
_def_gateway=""

function test()
{
    if [ ! -f ${_bin_iptables} ];       then echo "ERROR: Binary Not Found (${_bin_iptables})"; return 1; fi    
    if [ ! -f ${_bin_ip} ];             then echo "ERROR: Binary Not Found (${_bin_ip})"; return 1; fi    
    if [ ! -f ${_bin_grep} ];           then echo "ERROR: Binary Not Found (${_bin_grep})"; return 1; fi
    if [ ! -f ${_bin_dirname} ];        then echo "ERROR: Binary Not Found (${_bin_dirname})"; return 1; fi
    if [ ! -f ${_bin_sed} ];            then echo "ERROR: Binary Not Found (${_bin_sed})"; return 1; fi

    if [ ! -d /sys/fs/cgroup/ ];        then echo "ERROR: CGROUP folder Not Found (/sys/fs/cgroup/)"; return 1; fi    
    if [ ! -d /sys/fs/cgroup/net_cls ]; then echo "ERROR: CGROUP folder Not Found (/sys/fs/cgroup/net_cls)"; return 1; fi    

    if [ ! -f ${_bin_ip6tables} ];      then echo "WARNING: Binary Not Found (${_bin_ip6tables})"; fi
    if [ ! -f ${_bin_awk} ];            then echo "WARNING: Binary Not Found (${_bin_awk})"; fi
    if [ ! -f ${_bin_runuser} ];        then echo "WARNING: Binary Not Found (${_bin_runuser})"; fi    
}

function init()
{
    # default interface name
    _def_interface_name=$1
    # default gateway IP
    _def_gateway=$2
    
    # Ensure the input parameters not empty
    if [ -z ${_def_interface_name} ]; then
        echo "[i] Default network interface is not defined. Trying to determine it automatically..."
        _def_interface_name=$(${_bin_ip} route | ${_bin_awk} '/default/ { print $5 }')
        echo "[+] Default network interface: '${_def_interface_name}'"
    fi
    if [ -z ${_def_gateway} ]; then
        echo "[i] Default gateway is not defined. Trying to determine it automatically..."
        _def_gateway=$(${_bin_ip} route | ${_bin_awk} '/default/ { print $3 }')
        echo "[+] Default gateway: '${_def_gateway}'"
    fi
    if [ -z ${_def_interface_name} ]; then
        echo "[!] Default network interface is not defined."
        return 2
    fi
    if [ -z ${_def_gateway} ]; then
        echo "[!] Default gateway is not defined."
        return 3
    fi

    ##############################################
    # Ensure previous configuration erased
    ##############################################
    clean $@  > /dev/null 2>&1

    set -e

    ##############################################
    # Backup some parameters for restore function (_def_interface_name, /proc/sys/net/ipv4/conf/${_def_interface_name}/rp_filter )
    ##############################################
    backup
    # Set required reverse path filtering parameter
    if [ -f /proc/sys/net/ipv4/conf/${_def_interface_name}/rp_filter ]; then
        echo 2 > /proc/sys/net/ipv4/conf/${_def_interface_name}/rp_filter
    fi

    ##############################################
    # Create cgroup
    ##############################################
    if [ ! -d ${_cgroup_folder} ]; then
        mkdir -p ${_cgroup_folder}
        echo ${_cgroup_classid} > ${_cgroup_folder}/net_cls.classid
    fi
    
    ##############################################
    # Firewall rules for packets coming from cgroup
    ##############################################    
    # NOTE! All rules here added with "-I" parameter. "-I" means insert rule at the top.
    # So, the original rules sequence will be the reverse sequence to the list below.

    # Save packets mark (to be able to restore mark for incoming packets of the same connection)
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -I POSTROUTING -j CONNMARK --save-mark    
    # Force the packets to exit through default interface (eg. eth0, enp0s3 ...) with NAT
    ${_bin_iptables} -w ${_iptables_locktime} -t nat -I POSTROUTING -m cgroup --cgroup ${_cgroup_classid} -o ${_def_interface_name} -j MASQUERADE
    # Add mark on packets of classid ${_cgroup_classid}
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -I OUTPUT -m cgroup --cgroup ${_cgroup_classid} -j MARK --set-mark ${_packets_fwmark_value}
    # Important! allow DNS request before setting mark rule (DNS request should not be marked)
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -I OUTPUT -m cgroup --cgroup ${_cgroup_classid} -p tcp --dport 53 -j ACCEPT
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -I OUTPUT -m cgroup --cgroup ${_cgroup_classid} -p udp --dport 53 -j ACCEPT
    # Allow packets from/to cgroup (bypass IVPN firewall)
    ${_bin_iptables} -w ${_iptables_locktime} -I OUTPUT -m cgroup --cgroup ${_cgroup_classid} -j ACCEPT
    ${_bin_iptables} -w ${_iptables_locktime} -I INPUT -m cgroup --cgroup ${_cgroup_classid} -j ACCEPT   # this rule is not effective, so we use 'mark' (see the next rule)
    ${_bin_iptables} -w ${_iptables_locktime} -I INPUT -m mark --mark ${_packets_fwmark_value} -j ACCEPT

    # Restore packets mark for incoming packets
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -I PREROUTING -j CONNMARK --restore-mark

    if [ -f /proc/net/if_inet6 ]; then
        # Block IPv6 traffic (IPv6 not supported in current version)
        ${_bin_ip6tables} -w ${_iptables_locktime} -t mangle -I OUTPUT -m cgroup --cgroup ${_cgroup_classid} -j DROP
    fi

    ##############################################
    # Initialize routing table for packets coming from cgroup   
    ##############################################    
    if ! ${_bin_grep} -E "^[0-9]+\s+${_routing_table_name}\s*$" /etc/iproute2/rt_tables &>/dev/null ; then
        # initialize new routing table
        echo "${_routing_table_weight}      ${_routing_table_name}" >> /etc/iproute2/rt_tables
        # splittun table has a default gateway to the default interface
        ${_bin_ip} route add default via ${_def_gateway} table ${_routing_table_name}  
        # Packets with mark will use splittun table
        ${_bin_ip} rule add fwmark ${_packets_fwmark_value} table ${_routing_table_name}
    fi

    ##############################################
    # Compatibility with WireGuard rules 
    ##############################################
    # Check iw WG connected
    _ret=$(${_bin_ip} rule list not from all fwmark 0xca6c) # WG rule
    if [ ! -z "${_ret}" ]; then
        # Only for WireGuard connection:
        # Ensure rule 'rule add from all lookup main suppress_prefixlength 0' has higher priority
        ${_bin_ip} rule del from all lookup main suppress_prefixlength 0 > /dev/null 2>&1
        ${_bin_ip} rule add from all lookup main suppress_prefixlength 0
    fi

    set +e

    echo "IVPN Split Tunneling enabled"
}

function clean()
{
    ##############################################
    # Restore parameters
    ##############################################
    # read ${_def_interface_name} from backup
    restore

    # Ensure the input parameters not empty
    if [ -z ${_def_interface_name} ]; then
        echo "[i] Default network interface is not defined. Trying to determine it automatically..."
        _def_interface_name=$(${_bin_ip} route | ${_bin_awk} '/default/ { print $5 }')
        echo "[+] Default network interface: '${_def_interface_name}'"
    fi

    ##############################################
    # Move all processes from the IVPN cgroup to the main cgroup
    ##############################################    
    removeAllPids

    ##############################################
    # Remove cgroup    
    ##############################################
    # check is cgroup exists
    if [ -d ${_cgroup_folder} ]; then
        # Note: the cgroup folder will be removed only in case
        # when no active process are in that cgroup
        rmdir ${_cgroup_folder}
    fi  

    ##############################################
    # Remove firewall rules
    ##############################################
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -D PREROUTING -j CONNMARK --restore-mark
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -D OUTPUT -m cgroup --cgroup ${_cgroup_classid} -p tcp --dport 53 -j ACCEPT
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -D OUTPUT -m cgroup --cgroup ${_cgroup_classid} -p udp --dport 53 -j ACCEPT
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -D OUTPUT -m cgroup --cgroup ${_cgroup_classid} -j MARK --set-mark ${_packets_fwmark_value}
    ${_bin_iptables} -w ${_iptables_locktime} -t mangle -D POSTROUTING -j CONNMARK --save-mark  
    ${_bin_iptables} -w ${_iptables_locktime} -D OUTPUT -m cgroup --cgroup ${_cgroup_classid} -j ACCEPT
    ${_bin_iptables} -w ${_iptables_locktime} -D INPUT -m cgroup --cgroup ${_cgroup_classid} -j ACCEPT   # this rule is not effective, so we use 'mark' (see the next rule)
    ${_bin_iptables} -w ${_iptables_locktime} -D INPUT -m mark --mark ${_packets_fwmark_value} -j ACCEPT

    if [ ! -z ${_def_interface_name} ]; then
        ${_bin_iptables} -w ${_iptables_locktime} -t nat -D POSTROUTING -m cgroup --cgroup ${_cgroup_classid} -o ${_def_interface_name} -j MASQUERADE
    fi

    if [ -f /proc/net/if_inet6 ]; then
        # Block IPv6 traffic (IPv6 not supported in current version)
        ${_bin_ip6tables} -w ${_iptables_locktime} -t mangle -D OUTPUT -m cgroup --cgroup ${_cgroup_classid} -j DROP    
    fi

    ##############################################
    # Remove routing
    ##############################################
    ${_bin_ip} rule del fwmark ${_packets_fwmark_value} table ${_routing_table_name}    
    ${_bin_ip} route del default table ${_routing_table_name}
    ${_bin_sed} -i "/${_routing_table_name}\s*$/d" /etc/iproute2/rt_tables    
}

function getBackupFolderPath()
{
    # Directory where current script is located
    _script_dir=$(${_bin_dirname} "$0")

    if [ -z "${_script_dir}" ]; then
        return 1
    fi

    local _tempDir="${_script_dir}/${_backup_folder_name}"
    if [ -d "${_script_dir}/../mutable" ]; then
        _tempDir="${_script_dir}/../mutable/${_backup_folder_name}"
    fi

    # return value in stdout
    echo ${_tempDir}
    return 0
}

function backup()
{
    if [ -z ${_def_interface_name} ]; then
        return 1
    fi

    local _tempDir="$( getBackupFolderPath )"
    mkdir -p ${_tempDir}

    echo ${_def_interface_name} > ${_tempDir}/def_interface
    if [ -f /proc/sys/net/ipv4/conf/${_def_interface_name}/rp_filter ]; then        
        cat /proc/sys/net/ipv4/conf/${_def_interface_name}/rp_filter >  ${_tempDir}/${_def_interface_name}-rp_filter
    fi
}

function restore()
{
    local _tempDir="$( getBackupFolderPath )"
    
    if [ ! -f ${_tempDir}/def_interface ]; then 
        return 1
    fi

    _def_interface_name="$( cat ${_tempDir}/def_interface )"

    if [ -f ${_tempDir}/${_def_interface_name}-rp_filter ]; then
        cat ${_tempDir}/${_def_interface_name}-rp_filter > /proc/sys/net/ipv4/conf/${_def_interface_name}/rp_filter
    fi

    rm -fr ${_tempDir}
}

# Move all processes from the IVPN cgroup to the main cgroup
function removeAllPids() 
{    
    while IFS= read -r line
    do
        echo $line >> /sys/fs/cgroup/net_cls/cgroup.procs
    done < "${_cgroup_folder}/cgroup.procs"
}

function addpid()
{
    local _pid="$1"    
    if [ -z "${_pid}" ]; then
        echo "[!] ERROR: PID not defined"
        exit 1
    fi   
    echo "[+] Adding PID ${_pid} to Split Tunneling group..."
    echo ${_pid} >> ${_cgroup_folder}/cgroup.procs
}

function execute()
{    
    _user="$1"
    _app="$2"

    if [ -z "${_app}" ]; then
        echo "[!] ERROR: Application not defined"
        exit 1
    fi   

    # Check if split tunneling enabled
    status > /dev/null 2>&1
    if [ $? != 0 ]; then
        echo "ERROR: split tunneling DISABLED. Please call 'start' command first"
        exit 1
    fi

    # Obtaining information about user running the script
    # (script can be executed with 'sudo', but we should get real user)
    if [ -z "${_user}" ]; then
        _user="${SUDO_USER:-$USER}"
    fi    
    if [ -z "${_user}" ]; then
        echo "[!] User not defined"
        exit 2
    fi

    addpid $$
    
    if [ $? != 0 ]; then
        echo "[!] Failed "
        exit 3
    fi

    echo "[+] Starting '${_app}' for a user '${_user}'..."
    ${_bin_runuser} -u ${_user} -- ${_app}
}

function status()
{
    if [ -d ${_cgroup_folder} ]; then
         if ${_bin_grep} -E "^[0-9]+\s+${_routing_table_name}\s*$" /etc/iproute2/rt_tables &>/dev/null ; then
            echo "Split Tunneling: ENABLED"
            return 0
         fi
    fi
    echo "Split Tunneling: DISABLED"
    return 1
}

function info()
{
    echo "[*] Interfaces (${_bin_ip} link):"
    ${_bin_ip} link
    echo

    _val=`cat /proc/sys/net/ipv4/ip_forward`
    echo "[*] /proc/sys/net/ipv4/ip_forward: ${_val}"
    echo

    echo "[*] /proc/sys/net/ipv4/conf/*/rp_filter:"
    for i in /proc/sys/net/ipv4/conf/*/rp_filter; do
        _val=`cat $i`
        echo $i: ${_val}
    done
    echo  

    if [ ! -d ${_cgroup_folder} ]; then
        echo "[*] cgroup folder NOT exists: '${_cgroup_folder}'"
    else
        echo "[*] cgroup folder exists: '${_cgroup_folder}'"
        echo "[*] File '${_cgroup_folder}/net_cls.classid':"
        cat ${_cgroup_folder}/net_cls.classid
    fi
    echo     

    echo "[*] File '/etc/iproute2/rt_tables':"
    cat /etc/iproute2/rt_tables
    echo

    echo "[*] iptables -t mangle -S:"
    ${_bin_iptables} -t mangle -S
    echo 

    echo "[*] iptables -t nat -S:"
    ${_bin_iptables} -t nat -S
    echo 

    echo "[*] ip rule:"
    ${_bin_ip} rule
    echo 

    echo "[*] ip route show table ${_routing_table_name}"
    ${_bin_ip} route show table ${_routing_table_name}
    echo    
}

if [[ $1 = "start" ]] ; then    
    _interface_name=""
    _gateway_ip=""
    _dns_ip=""
    shift
    while getopts ":i:g:d:" opt; do
        case $opt in
            i) _interface_name="$OPTARG"   ;;
            g) _gateway_ip="$OPTARG"    ;;
            d) _dns_ip="$OPTARG"    ;;
        esac
    done
    init  ${_interface_name} ${_gateway_ip} ${_dns_ip}   

elif [[ $1 = "stop" ]] ; then    
    _interface_name=""
    shift
    while getopts ":i:" opt; do
        case $opt in
            i) _interface_name="$OPTARG"   ;;
        esac
    done
    clean ${_interface_name}

elif [[ $1 = "addpid" ]] ; then
    shift 
    addpid $@  

elif [[ $1 = "run" ]] ; then    
    _command=""
    _user=""
    shift
    while getopts ":u:" opt; do
        case $opt in
            u) _user="$OPTARG"   ;;
        esac
    done
    if [ ! -z ${_user} ]; then
        shift
        shift
    fi
    _command=$@
    execute "${_user}" "${_command}"     

elif [[ $1 = "info" ]] ; then
    shift 
    info $@  

elif [[ $1 = "status" ]] ; then
    shift
    status $@

elif [[ $1 = "test" ]] ; then
    shift
    test $@

elif [[ $1 = "manual" ]] ; then
    _FUNCNAME=$2
    shift
    shift
    echo "Running manual command: ${_FUNCNAME}($@) "
    ${_FUNCNAME} $@
else
    echo "Script to control the Split-Tunneling functionality for Linux."
    echo "It is a part of Daemon for IVPN Client Desktop."
    echo "https://github.com/ivpn/desktop-app/daemon"
    echo "Created by Stelnykovych Alexandr."
    echo "Copyright (c) 2021 Privatus Limited."
    echo ""
    echo "Usage:"
    echo "Note! The script have to be started under privilaged user (sudo $0 ...)"
    echo "    $0 <command> [parameters]"
    echo "Parameters:"
    echo "    start [-i <interface_name>] [-g <gateway_ip>] [-d <dns>]"
    echo "        Initialize split-tunneling functionality"
    echo "        - interface_name - (optional) name of network interface to be used for ST environment"
    echo "        - gateway_ip     - (optional) gateway IP to be used for ST environment"
    echo "        - dns            - (optional) DNS IP to be used for ST environment"
    echo "    stop [-i <interface_name>]"
    echo "        Uninitialize split-tunneling functionality"
    echo "        - interface_name - (optional) name of network interface which was previously used for '-init' command"
    echo "    run [-u <username>] <command>"
    echo "        Start commands in split-tunneling environment"
    echo "        - command        - the command or path to binary to be executed"
    echo "        - username       - (optional) the account under which the command have to be executed"
    echo "    status"
    echo "        Check split-tunneling status"
    echo "Examples:"
    echo "    Initialize split-tunneling functionality:"
    echo "        $0 start"
    echo "        $0 start -i wlp3s0 -g 192.168.1.1 -d 1.1.1.1"
    echo "    Start commands in split-tunneling environment:"
    echo "        $0 run firefox"
    echo "        $0 run /usr/bin/firefox"
    echo "        $0 run ping 8.8.8.8"
    echo "    Uninitialize split-tunneling functionality:"
    echo "        $0 stop"
    echo "        $0 stop -i wlp3s0"
    echo "    Check split-tunneling status:"
    echo "        $0 status"
fi
