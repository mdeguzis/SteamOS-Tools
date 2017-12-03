# Simple network monitor for checking up connections to outside networks
# This is for those that have periodic wlan disconnects or even far in-between disconnects
# Written for Debian Jessie/Stretch
# Usage: ./wlan-monitor.sh 
# Usage to backgroud to run continuously: ./wlan-monitor.sh &
# Log: /tmp/network-status.log

net_type="wlan"
log="/tmp/network-status"
max_entries=250

run_ipv4_test()
{
	echo -n "IPv4 DNS test: "
	if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
		echo -n "[OK]"
		return 0
	else
		echo -n "[FAILURE]"
		return 1
	fi

}

run_web_test()
{
	echo -ne "\nWeb connectivity: "

	case "$(curl -s --max-time 2 -I http://google.com | sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')" in
		[23])
			echo -n "HTTP connectivity is up"
			return 0
			;;
		5)
			echo -n "The web proxy won't let us through"
			return 1
			;;
		*)  echo -n "The network is down or very slow"
			return 1
			;;
	esac
}

start_loop()
{
	# When the network is back up, it will restart this function

	run_ipv4_test
	while [[ $? == "1" ]];
	do
		echo -e "\nAttempting reconnect"
		failure_counter=$((failure_counter+1))
		sleep 3s
		# use nmcli (network manager cli, easiest here, no sudo required)
		nmcli d connect wlan0

		start=1
		end=5
		echo -e "\nSleeping 5 seconds and checking status again"
		for ((i=start; i<=end; i++))
		do
			echo -n "."
			sleep 1s
		done
		echo ""
		run_ipv4_test
		reconnect_counter=$((reconnect_counter+1))

	done

	run_web_test
	while [[ $? == "1" ]];
	do
		echo -e "\nAttempting reconnect"
		sleep 3s
		# use nmcli (network manager cli, easiest here, no sudo required)
		nmcli d connect wlan0

		start=1
		end=5
		echo -e "\nSleeping 5 seconds and trying again"
		for ((i=start; i<=end; i++))
		do
			echo -n "."
			sleep 1s
		done
		echo ""
		# COMMAND HERE
		run_web_test

	done
	echo ""

}

main()
{
	echo -e "\nNetwork info: "
	lspci -nnk | grep -A2 0280

	failure_counter=0
	reconnect_counter=0
	counter=1
	while true;
	do
		echo -e "\nRunning network test: $counter"
		echo "Failure count: ${failure_counter}"
		echo -e "Reconnect count: ${reconnect_counter}"
		start_loop
		echo "Sleeping for 15 seconds"
		sleep 15s
		counter=$((counter+1))
		# at count 250 roll the log to "old" and start new
		if [[ ${counter} > 250 ]]; then
			echo -e "\n=== Rolling log over (${max_entries} reached) ===\n"
			cp ${log}.log ${log}.old.log
			# Save for network information
			cp ${log}.old.log ${log}.orig
			echo -e "\n<=== Starting new log ===>\n" > ${log}.log
		fi

	done
}

# main
main 2>&1 | tee ${log}.log

