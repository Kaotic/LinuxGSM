#!/bin/bash
# LGSM commanf_update.sh function
# Author: Daniel Gibbs
# Website: https://gameservermanagers.com
# Description:Handles updating of teamspeak 3 servers.

local modulename="Update"
local function_selfname="$(basename $(readlink -f "${BASH_SOURCE[0]}"))"

fn_update_ts3_dl(){
	fn_fetch_file "http://dl.4players.de/ts/releases/${ts3_version_number}/teamspeak3-server_linux_${ts3arch}-${ts3_version_number}.tar.bz2" "${lgsmdir}/tmp" "teamspeak3-server_linux_${ts3arch}-${ts3_version_number}.tar.bz2"
	fn_dl_extract "${lgsmdir}/tmp" "teamspeak3-server_linux_${ts3arch}-${ts3_version_number}.tar.bz2" "${filesdir}"
}


# Checks for server update from teamspeak.com using a mirror dl.4players.de.
fn_print_dots "Checking for update: teamspeak.com"
fn_script_log_info "Checking for update: teamspeak.com"
sleep 1

fn_update_ts3_currentbuild(){
	# Gets currentbuild info
	# Checks currentbuild info is available, if fails a server restart will be forced to generate logs.
	if [ -z "$(find ./* -name 'ts3server*_0.log')" ]; then
		fn_print_fail "Checking for update: teamspeak.com"
		sleep 1
		fn_print_fail_nl "Checking for update: teamspeak.com: No logs with server version found"
		fn_script_log_warn "Checking for update: teamspeak.com: No logs with server version found"
		sleep 2
		fn_print_info_nl "Checking for update: teamspeak.com: Forcing server restart"
		fn_script_log_warn "Checking for update: teamspeak.com: Forcing server restart"
		sleep 2
		exitbypass=1
		command_stop.sh
		exitbypass=1
		command_start.sh
		sleep 1
		# Check again and exit on failure.
		if [ -z "$(find ./* -name 'ts3server*_0.log')" ]; then
			fn_print_fail_nl "Checking for update: teamspeak.com: Still No logs with server version found"
			fn_script_log_fatal "Checking for update: teamspeak.com: Still No logs with server version found"
			core_exit.sh
		fi
	fi

	currentbuild=$(cat $(find ./* -name 'ts3server*_0.log' 2> /dev/null | sort | egrep -E -v '${rootdir}/.ts3version' | tail -1) | egrep -o 'TeamSpeak 3 Server ((\.)?[0-9]{1,3}){1,3}\.[0-9]{1,3}' | egrep -o '((\.)?[0-9]{1,3}){1,3}\.[0-9]{1,3}')
}

fn_update_ts3_arch(){
# Gets the teamspeak server architecture.
info_distro.sh
if [ "${arch}" == "x86_64" ]; then
	ts3arch="amd64"
elif [ "${arch}" == "i386" ]||[ "${arch}" == "i686" ]; then
	ts3arch="x86"
else
	echo ""
	fn_print_failure "unknown or unsupported architecture: ${arch}"
	fn_script_log_fatal "unknown or unsupported architecture: ${arch}"
	core_exit.sh
fi
}

fn_update_ts3_availablebuild(){
# Gets availablebuild info.

# Creates tmp dir if missing
if [ ! -d "${lgsmdir}/tmp" ]; then
	mkdir -p "${lgsmdir}/tmp"
fi

# Grabs all version numbers but not in correct order.
wget "http://dl.4players.de/ts/releases/?C=M;O=D" -q -O -| grep -i dir | egrep -o '<a href=\".*\/\">.*\/<\/a>' | egrep -o '[0-9\.?]+'|uniq > "${lgsmdir}/tmp/.ts3_version_numbers_unsorted.tmp"

# Sort version numbers
cat "${lgsmdir}/tmp/.ts3_version_numbers_unsorted.tmp" | sort -r --version-sort -o "${lgsmdir}/tmp/.ts3_version_numbers_sorted.tmp"

# Finds directory with most recent server version.
while read ts3_version_number; do
	wget --spider -q "http://dl.4players.de/ts/releases/${ts3_version_number}/teamspeak3-server_linux_${ts3arch}-${ts3_version_number}.tar.bz2"
	if [ $? -eq 0 ]; then
		availablebuild="${ts3_version_number}"
		# Break while-loop, if the latest release could be found.
		break
	fi
done < "${lgsmdir}/tmp/.ts3_version_numbers_sorted.tmp"

# Tidy up
rm -f "${lgsmdir}/tmp/.ts3_version_numbers_unsorted.tmp"
rm -f "${lgsmdir}/tmp/.ts3_version_numbers_sorted.tmp"

# Checks availablebuild info is available
if [ -z "${availablebuild}" ]; then
	fn_print_fail "Checking for update: teamspeak.com"
	sleep 1
	fn_print_fail "Checking for update: teamspeak.com: Not returning version info"
	fn_script_log_fatal "Failure! Checking for update: teamspeak.com: Not returning version info"
	core_exit.sh
else
	fn_print_ok "Checking for update: teamspeak.com"
	fn_script_log_pass "Checking for update: teamspeak.com"
	sleep 1
fi
}

fn_update_ts3_compare(){
	# Removes dots so if can compare version numbers
	currentbuilddigit=$(echo "${currentbuild}"|tr -cd '[:digit:]')
	availablebuilddigit=$(echo "${availablebuild}"|tr -cd '[:digit:]')

	if [ "${currentbuilddigit}" -ne "${availablebuilddigit}" ]; then
		echo -e "\n"
		echo -e "Update available:"
		sleep 1
		echo -e "	Current build: \e[0;31m${currentbuild} ${architecture}\e[0;39m"
		echo -e "	Available build: \e[0;32m${availablebuild} ${architecture}\e[0;39m"
		echo -e ""
		sleep 1
		echo ""
		echo -en "Applying update.\r"
		sleep 1
		echo -en "Applying update..\r"
		sleep 1
		echo -en "Applying update...\r"
		sleep 1
		echo -en "\n"
		fn_script_log "Update available"
		fn_script_log "Current build: ${currentbuild}"
		fn_script_log "Available build: ${availablebuild}"
		fn_script_log "${currentbuild} > ${availablebuild}"

		unset updateonstart

		check_status.sh
		if [ "${status}" == "0" ]; then
			fn_update_ts3_dl
			exitbypass=1
			command_start.sh
			exitbypass=1
			command_stop.sh
		else
			exitbypass=1
			command_stop.sh
			fn_update_ts3_dl
			exitbypass=1
			command_start.sh
		fi
		alert="update"
		alert.sh
	else
		echo -e "\n"
		echo -e "No update available:"
		echo -e "	Current version: \e[0;32m${currentbuild}\e[0;39m"
		echo -e "	Available version: \e[0;32m${availablebuild}\e[0;39m"
		echo -e ""
		fn_print_ok_nl "No update available"
		fn_script_log_info "Current build: ${currentbuild}"
		fn_script_log_info "Available build: ${availablebuild}"
	fi
}

if [ "${installer}" == "1" ]; then
	fn_update_ts3_availablebuild
	fn_update_ts3_dl
else
	fn_update_ts3_currentbuild
	fn_update_ts3_availablebuild
	fn_update_ts3_compare
fi