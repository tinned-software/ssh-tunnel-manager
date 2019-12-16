#!/bin/bash
#
# @author Gerhard Steinbeis (info [at] tinned-software [dot] net)
# @copyright Copyright (c) 2013
version=0.6.7
# @license http://opensource.org/licenses/GPL-3.0 GNU General Public License, version 3
# @package net
#
# Configuration file for the ssh-tunnel-manager script. Default location for 
# the config file is /etc/ssh-tunnel-manager.conf or if that does not exist, 
# the ssh-tunnel-manager.conf in the same directory as the script itself.
#

#
# Define names for the tunnel to identify them. The list needs to be configured 
# in the same order as the tunnel config in the TUNELS list.
#
#TUNNEL_NAMES=(
#	"Tunnel-A"
#	"Tunnel-B"
#)

#
# Ths TUNNELS array is used to configure the individual tunnels. Each 
# configuration entry needs to follow the SSH options. An example of 
# how such a configuration line might look like is listed here.
#
# TUNNELS=(
#	"-p 1234 username@host1.example.com -L 10001:127.0.0.1:3306 -L 10011:127.0.0.1:27017"
#	"-p 1234 username@host2.example.com -L 10002:127.0.0.1:3306 -L 10012:127.0.0.1:27017"
#)

#
# The RECONNECT_TIMER is used in case of a tunnel connection to be lost. After 
# the script is detecting that the connection was lost, the time defined the 
# time to wait before the the script tries to reconnect the tunnel.
#
RECONNECT_TIMER=5

#
# The LOGFILE setting defines the path of the logfile. You have the possibility to use 
# the $SCRIPT_PATH variable to define the path of the logfile to be the same 
# as the script directory.
#
LOGFILE=""

#
# This DBG setting is adding additional details to the logfile. The values are 0 
# to hide the extra log content and 1 to show it.
#
DBG=0

#
# Default configuration file to load settings from can be defined here.
#
DEFAULT_CONFIG="ssh-tunnel-manager.conf"

#
# Non Config values
#
# Get script directory
SCRIPT_PATH="$(cd $(dirname $0);pwd -P)"
LOGFILE="$SCRIPT_PATH/ssh-tunnel-manager.log"

#
# Parse all parameters
#
HELP=0
TERMINATE=0
COMMAND_INDEX_NAME=''
while [ $# -gt 0 ]; do
	case $1 in
		# General parameter
		-h|--help)
			HELP=1
			shift
			;;

			-v|--version)
			echo 
			echo "Copyright (c) 2013 Tinned-Software (Gerhard Steinbeis)"
			echo "License GNUv3: GNU General Public License version 3 <http://opensource.org/licenses/GPL-3.0>"
			echo 
			echo "`basename $0` version $version"
			echo
			exit 0
			;;

		# specific parameters
		--config)
			# load settings file
			if [[ -f "$2" ]]; then
				. $2
				CONFIG_FILE=$2
				CONFIG_LOADED=1
			else
				HELP=1
				echo "ERROR: Specified config file cound not be found." 
			fi
			shift 2
			;;

		# specific parameters
		start)
			COMMAND='start'
			shift
			if [[ $# -gt 0 ]]; then
				COMMAND_INDEX_NAME=$1
				shift
			fi
			;;

		stop)
			COMMAND='stop'
			shift
			if [[ $# -gt 0 ]]; then
				COMMAND_INDEX_NAME=$1
				shift
			fi
			;;

		restart)
			COMMAND='restart'
			shift
			if [[ $# -gt 0 ]]; then
				COMMAND_INDEX_NAME=$1
				shift
			fi
			;;

		status)
			COMMAND='status'
			shift
			if [[ $# -gt 0 ]]; then
				COMMAND_INDEX_NAME=$1
				shift
			fi
			;;

		show)
			COMMAND='show'
			shift
			;;

		manage)
			COMMAND='manage'
			INDEX=$2
			shift 2
			;;

		# undefined parameter        
		*)
			echo "ERROR: Unknown option '$1'"
			HELP=1
			shift
			break
			;;
	esac
done

# check if a command has been provided
if [[ -z "${COMMAND}" ]]; then
	if [ "$HELP" -ne "1" ]; then
		echo "ERROR: No command defined in parameter list."
		HELP=1
	fi
fi

# Load the default configuration file if no other configuration file is provided
if [[ -z "$CONFIG_LOADED" ]]; then
	# Check if configuration file exists
	if [[ -f "/etc/$DEFAULT_CONFIG" ]]; then
		. /etc/$DEFAULT_CONFIG
		CONFIG_FILE=/etc/$DEFAULT_CONFIG
	else
		if [[ -f "$SCRIPT_PATH/$DEFAULT_CONFIG" ]]; then
			. $SCRIPT_PATH/$DEFAULT_CONFIG
			CONFIG_FILE=$SCRIPT_PATH/$DEFAULT_CONFIG
		fi
	fi
fi

# check if a tunnel configuration has been provided
if [[ "${#TUNNELS[@]}" -lt "1" && ! -z "${COMMAND}" ]]; then
	if [ "$HELP" -ne "1" ]; then
		echo "ERROR: No tunnel configuration found."
		HELP=1
	fi
fi

# show help message
if [ "$HELP" -eq "1" ]; then
	echo 
	echo "Copyright (c) 2013 Tinned-Software (Gerhard Steinbeis)"
	echo "License GNUv3: GNU General Public License version 3 <http://opensource.org/licenses/GPL-3.0>"
	echo 
	echo "This script is used to setup multiple ssh tunnels and manage to keep "
	echo "them alive. This script will launch manager instances to keep the "
	echo "individual tunnels alive. See the configuration file for more details "
	echo "about the configuration."
	echo 
	echo "Usage: `basename $0` [-hv] [--config filename.conf] [start|stop|status|restart|show] [tunnel-ID]"
	echo "  -h  --help         print this usage and exit"
	echo "  -v  --version      print version information and exit"
	echo "      --config       Configuration file to read parameters from"
	echo "      start [TN]     Start the ssh tunnels configured"
	echo "      stop [TN]      Stop the ssh tunnels configured"
	echo "      status [TN]    Check the status of the ssh tunnel"
	echo "      show [TN]      Show the ssh tunnel configuration and there tunnel name"
	echo "      restart [TN]   Restart the ssh tunnels configured"
	echo "      "
	echo "      TN             Specify one tunnel to start/stop/... identified by its name"
	echo 
	echo 
	exit 1
fi



#
# Function to print out a string including a time and date info at the 
# beginning of the line. If the string is empty, only the timestamp is printed 
# out.
#
# @param $1 The string to print out
# @param $2 (optional) Option to echo like ">>logfile.log"
#
function echotime
{
	TIME=`date "+[%Y-%m-%d %H:%M:%S]"`
	if [ -z "$LOGFILE" ]; then
		#stdout for non-privileged user on systemd
		echo -e "$TIME - $@"
	else
		echo -e "$TIME - $@" >>$LOGFILE
	fi
}

#
# This function will search the index of the name provided to this function.
#
function get_id_from_name
{
	for (( idx=0; idx<${#TUNNEL_NAMES[@]}; idx++ ))
	do
		if [[ "$1" == "${TUNNEL_NAMES[$idx]}" ]]
		then
			echo $idx
			return
		fi
	done
	echo -1
}


# Execute function signal_terminate() receiving TERM signal
#
# Function to print out a string including a time and date info at the 
# beginning of the line. If the string is empty, only the timestamp is printed 
# out.
#
# @param $1 The string to print out
# @param $2 (optional) Option to echo like ">>logfile.log"
#
function signal_terminate
{
	echotime "MANAGER - Received TERM for tunnel ${TUNNEL_NAMES[$INDEX]} (ID $INDEX)"
	TERMINATE=1
}
trap 'signal_terminate' TERM

SCRIPT_PID=$$

#
# start procedure according to the action
#
case $COMMAND in
    restart)
		echotime "COMM - Execute RESTART procedure ... "
		$0 --config $CONFIG_FILE stop $COMMAND_INDEX_NAME
		sleep 2
		$0 --config $CONFIG_FILE start $COMMAND_INDEX_NAME
		echotime "COMM - Execute RESTART procedure ... Done"
		echotime ""
		;;

	stop)
		echotime "COMM - Execute STOP procedure ... "

		# check if a tunnel index has been provided
		if [[ "$COMMAND_INDEX_NAME" != '' ]]; then
			COMMAND_INDEX=$(get_id_from_name "$COMMAND_INDEX_NAME")
			if [[ "$COMMAND_INDEX" -eq "-1" ]]; then
				echo "The tunnel with the name '$COMMAND_INDEX_NAME' can not be found."
				exit 6
			fi
			IDX_START=$COMMAND_INDEX
			IDX_END=$((COMMAND_INDEX+1))
		else
			IDX_START=0
			IDX_END=${#TUNNELS[@]}
		fi

		for (( idx=$IDX_START; idx<$IDX_END; idx++ ));
		do
			# notify "manage" script of terminate request. This avoids the restart of the tunnel
			RESULT_PID=`ps aux | grep -v grep | grep "$0 --config $CONFIG_FILE manage $idx" | awk '{print $2}' | tr '\n' ' '`
			[ "$DBG" -gt "0" ] && echotime "STOP - *** DBG-CMD: ps aux | grep -v grep | grep \"$0 --config $CONFIG_FILE manage $idx\" | awk '{print \$2}'"
			for PID in $RESULT_PID; do
				kill $PID &>/dev/null
			done
			echotime "STOP - Stop sent manager of tunnel '${TUNNEL_NAMES[$idx]}' (ID $idx) ... PID: $RESULT_PID"

			# Terminate the ssh tunnel processes.
			RESULT_PID=`ps aux | grep -v grep | grep "ssh -N ${TUNNELS[$idx]}" | awk '{print $2}' | tr '\n' ' '`
			[ "$DBG" -gt "0" ] && echotime "STOP - *** DBG-CMD: ps aux | grep -v grep | grep \"ssh -N ${TUNNELS[$idx]}\" | awk '{print \$2}'"
			for PID in $RESULT_PID; do
				kill $PID &>/dev/null
			done

			echotime "STOP - Stopped tunnel '${TUNNEL_NAMES[$idx]}' (ID $idx) ... PID: $RESULT_PID"
			
			# check if the tunnels really down
			sleep "0.3"
			TUNNELS_COUNT=0
			TMANAGER_COUNT=0
			TUNNELS_COUNT=`ps aux | grep -v grep | grep "ssh -N ${TUNNELS[$idx]}" | awk '{print $2}' | wc -l`
			TMANAGER_COUNT=`ps aux | grep -v grep | grep "$0 --config $CONFIG_FILE manage $idx" | awk '{print $2}' | wc -l`
			if [[ "$TUNNELS_COUNT" -lt "1" ]] && [[ "$TUNNELS_COUNT" -lt "1" ]]; then
				echo "Stopping tunnel '${TUNNEL_NAMES[$idx]}' ... Done"
			else
				echo "Stopping tunnel '${TUNNEL_NAMES[$idx]}' ... Failed"
			fi
		done
		echotime "COMM - Execute STOP procedure ... Done"
		echotime ""
		;;

	status)
		echotime "COMM - Execute STATUS procedure ... "

		# check if a tunnel index has been provided
		if [[ "$COMMAND_INDEX_NAME" != '' ]]; then
			COMMAND_INDEX=$(get_id_from_name "$COMMAND_INDEX_NAME")
			if [[ "$COMMAND_INDEX" -eq "-1" ]]; then
				echo "The tunnel with the name '$COMMAND_INDEX_NAME' can not be found."
				exit 3
			fi
			IDX_START=$COMMAND_INDEX
			IDX_END=$((COMMAND_INDEX+1))
		else
			IDX_START=0
			IDX_END=${#TUNNELS[@]}
		fi

		EXIT_CODE=0
		for (( idx=$IDX_START; idx<$IDX_END; idx++ ));
		do
			# get the list of processs
			RESULT=0
			RESULT=`ps aux | grep -v grep | grep "ssh -N ${TUNNELS[$idx]}" | wc -l`
			# show the result
			if [[ "$RESULT" -gt "0" ]]; then
				echotime "STATUS - Status of Tunnel '${TUNNEL_NAMES[$idx]}' (ID $idx) is ... running"
				echo "Status of Tunnel '${TUNNEL_NAMES[$idx]}' is ... running"
			else
				echotime "STATUS - Status of Tunnel '${TUNNEL_NAMES[$idx]}' (ID $idx) is ... NOT running"
				echo "Status of Tunnel '${TUNNEL_NAMES[$idx]}' is ... NOT running"
				EXIT_CODE=3
			fi
		done
		echotime "COMM - Execute STATUS procedure ... Done"
		echotime ""
		exit $EXIT_CODE
		;;

	show)
		for (( idx=0; idx<${#TUNNELS[@]}; idx++ ));
		do
			# show the tunnel config
			echo "Configuration of Tunnel '${TUNNEL_NAMES[$idx]}' ... ${TUNNELS[$idx]}"
		done
		;;

	start)
		echotime "COMM - Execute START procedure ... "

		# check if a tunnel index has been provided
		if [[ "$COMMAND_INDEX_NAME" != '' ]]; then
			COMMAND_INDEX=$(get_id_from_name "$COMMAND_INDEX_NAME")
			if [[ "$COMMAND_INDEX" -eq "-1" ]]; then
				echo "The tunnel with the name '$COMMAND_INDEX_NAME' can not be found."
				exit 6
			fi
			IDX_START=$COMMAND_INDEX
			IDX_END=$((COMMAND_INDEX+1))
		else
			IDX_START=0
			IDX_END=${#TUNNELS[@]}
		fi

		for (( idx=$IDX_START; idx<$IDX_END; idx++ ));
		do
			RESULT_PID=0
			RESULT_PID=`ps aux | grep -v grep | grep "$0 --config $CONFIG_FILE manage $idx" | awk '{print $2}' | tr '\n' ' '`
			if [[ ! -z $RESULT_PID ]]; then
				echotime "START - Already running tunnel '${TUNNEL_NAMES[$idx]}' (ID $idx) ... PID: $RESULT_PID"
				echo "Starting tunnel '${TUNNEL_NAMES[$idx]}' ... Already running"
			else
				$0 --config $CONFIG_FILE manage $idx &
				sleep "0.2"
				RESULT_PID=`ps aux | grep -v grep | grep "$0 --config $CONFIG_FILE manage $idx" | awk '{print $2}' | tr '\n' ' '`
				[ "$DBG" -gt "0" ] && echotime "START - *** DBG-CMD: ps aux | grep -v grep | grep \"$0 --config $CONFIG_FILE manage $idx\" | awk '{print \$2}'"
				echotime "START - Starting tunnel '${TUNNEL_NAMES[$idx]}' (ID $idx) ... PID: $RESULT_PID"
				echo "Starting tunnel '${TUNNEL_NAMES[$idx]}' ... Done"
			fi
			# sleep before every cycle to aviod overloading 
		done
		echotime "COMM - Execute START procedure ... Done"
		echotime ""
		;;

	manage)
		echotime "MANAGE - Connecting tunnel ${TUNNEL_NAMES[$INDEX]} (ID $INDEX) with parameters ... ${TUNNELS[$INDEX]}"
		while [ "$TERMINATE" -eq "0" ]
		do
			SSH_RESULT=`ssh -N ${TUNNELS[$INDEX]} 2>&1`
			if [[ "$TERMINATE" -eq "0" ]]; then
				echotime "MANAGE - Detected tunnel '${TUNNEL_NAMES[$INDEX]}' (ID $INDEX) disconnected. $SSH_RESULT"
				sleep $RECONNECT_TIMER
				echotime "MANAGE - Reconnecting tunnel '${TUNNEL_NAMES[$INDEX]}' (ID $INDEX) with parameters ... ${TUNNELS[$INDEX]}"
			else
				echotime "MANAGE - Shutdown manager for tunnel '${TUNNEL_NAMES[$INDEX]}' (ID $INDEX) "
			fi
		done
		;;
esac

