#!/bin/bash
# This file initiates the wazigate preparation


# Please add the follwing command at the end of /etc/rc.local file right before exit 0;
#
# cd /home/pi/wazigate/; sudo bash ./start.sh &


# Uncomment these to have the logs
# exec 1>./wazigate-start.log 2>&1		# send stdout and stderr to a log file
# set -x                         		# tell sh to display commands before execution

DEVMODE=0

WAZIGATE=$(dirname $(realpath $0))

#------------#

service ntp stop
ntpdate -u pool.ntp.org
service ntp start

#------------#

# In AP mode we need this fix, otherwise RPi kicks the clients out after a while.
if ! grep -qFx "wifi.scan-rand-mac-address=no" /etc/NetworkManager/NetworkManager.conf; then 
	echo -e '\n[device]\nwifi.scan-rand-mac-address=no' | tee -a /etc/NetworkManager/NetworkManager.conf
fi

# We need this because when you remove the cable it does not work
# ip link set eth0 down
# sleep 1
# ip link set eth0 up

#------------#

# Resolving the issue of not having internet within the containers
if ! grep -qFx "nameserver 8.8.8.8" /etc/resolv.conf; then 
	echo -e '\nnameserver 8.8.8.8' | tee -a /etc/resolv.conf
fi

#------------#

# check if the server is accessible
acc=$(curl -Is https://waziup.io | head -n 1 | awk '{print $2}')
if [ "$acc" != "200" ]; then
	echo "[ Warning ]: Waziup.io is not accessible!"
fi

#------------#

# Launch the wazigate-host service
bash $WAZIGATE/wazigate-host/start.sh $DEVMODE &


docker container start $(docker ps -aq -f='status=created')


#------------#

exit 0;