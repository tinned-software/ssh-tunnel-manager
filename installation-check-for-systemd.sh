#!/bin/bash

function check {
	_chknm="$1"
	shift
	_msg="$1"
	shift
	if $1 > /dev/null 2>&1 ; then
		echo "${_chknm} : OK" 1>&2
	else
		echo "${_chknm} : NG" 1>&2
		echo "${_msg}" 1>&2
	fi
}

USERNAME=ssh-tunnel-manager
GROUPNAME=ssh-tunnel-manager

NCHECKS=5
check "1/${NCHECKS} service user" "A user named '${USERNAME}' must exist." "id -u ${USERNAME}"
check "2/${NCHECKS} service group" "A group named '${GROUPNAME}' must exist." "id -g ${GROUPNAME}"

MANAGERPGM=/usr/sbin/ssh-tunnel-manager
check "3/${NCHECKS} ssh-tunnel-manager.sh installation" "The '# install -m 555 ssh-tunnel-manager.sh ${MANAGERPGM}' must be done." "test -x ${MANAGERPGM}"


SYSTEMDUNIT=/etc/systemd/system/ssh-tunnel-manager.service
check "4/${NCHECKS} ssh-tunnel-manager.service installation" "The '# install -m 444 ssh-tunnel-manager.service ${SYSTEMDUNIT}' must be done." "test -r ${SYSTEMDUNIT}"

CONF_FROM=ssh-tunnel-manager.conf.example
CONF_TO=/etc/ssh-tunnel-manager.conf
check "5/${NCHECKS} ${CONF_FROM} installation" "The '# install -m 444 ${CONF_FROM} ${CONF_TO}' must be done." "test -r ${CONF_TO}"


echo "Caution: the systemd serice start command is '# systemctl daemon-reload && systemctl enable ssh-tunnel-manager && systemctl start ssh-tunnel-manager'.";
