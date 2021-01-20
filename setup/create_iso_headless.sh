#!/bin/bash

WAZIGATE=${1:-$HOME/waziup-gateway}
REPO=https://github.com/Waziup/WaziGate.git

################################################################################

echo '# Updating package registry ...'
sudo apt-get update -qq >/dev/null
echo '# Install support packages ...'
sudo apt-get install git gawk network-manager ntp ntpdate dnsmasq hostapd i2c-tools libopenjp2-7 libtiff5 avahi-daemon -y -qq >/dev/null

echo '# Install Docker ...'
curl -fsSL https://get.docker.com | bash
# Adding this user to the 'docker' group does not affect the current session.
# All following docker commands will still need 'sudo'.
sudo usermod -aG docker $USER
sudo apt-get install docker-compose -y -qq >/dev/null

################################################################################

# Download WaziGate repo
# git clone $REPO $WAZIGATE
cd $WAZIGATE
chmod a+x start.sh
chmod a+x stop.sh

################################################################################

echo '# Setup Access Point ...'
# Setup the Wifi Access Point
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

sudo systemctl unmask hostapd
sudo systemctl enable hostapd

sudo mv --backup=numbered /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo bash -c "echo -e 'interface=wlan0\n  dhcp-range=192.168.200.2,192.168.200.200,255.255.255.0,24h\n' > /etc/dnsmasq.conf"

MAC=$(cat /sys/class/net/eth0/address)
MAC=${MAC//:}
GWID="${MAC^^}"
cp --backup=numbered setup/hostapd.conf setup/hostapd.conf.orig
sed -i "s/^ssid=.*/ssid=WaziGate-$GWID/g" setup/hostapd.conf
sudo cp setup/hostapd.conf /etc/hostapd/hostapd.conf

if ! grep -qFx 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' /etc/default/hostapd; then
  sudo sed -i -e '$i \DAEMON_CONF="/etc/hostapd/hostapd.conf"\n' /etc/default/hostapd
fi

cp --backup=numbered /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.orig

sudo systemctl start hostapd
sudo systemctl start dnsmasq

################################################################################


sed -i 's/^DEVMODE.*/DEVMODE=0/g' start.sh

# run start.sh on startup
if ! grep -qF "start.sh" /etc/rc.local; then
  sudo sed -i -e '$i \cd '"$WAZIGATE"'; sudo bash ./start.sh &\n' /etc/rc.local
fi

################################################################################


# Setup I2C
# See http://www.runeaudio.com/forum/how-to-enable-i2c-t1287.html
echo "Configuring the system ..."
if ! grep -qFx "dtparam=i2c_arm=on" /boot/config.txt; then
  echo -e '\ndtparam=i2c_arm=on' | sudo tee -a /boot/config.txt
fi

# Setup the default state for GPIO 6 and 26 which are used for push buttons: WiFi/AP and PWR
if ! grep -qFx "gpio=6,26=ip,pd" /boot/config.txt; then
  echo -e '\n\ngpio=6,26=ip,pd' | sudo tee -a /boot/config.txt
fi

if ! grep -qF "bcm2708.vc_i2c_override=1" /boot/cmdline.txt; then
  sudo bash -c "echo -n ' bcm2708.vc_i2c_override=1' >> /boot/cmdline.txt"
fi
if ! grep -qFx "i2c-bcm2708" /etc/modules-load.d/raspberrypi.conf; then
  echo -e '\ni2c-bcm2708' | sudo tee -a /etc/modules-load.d/raspberrypi.conf
fi
if ! grep -qFx "i2c-dev" /etc/modules-load.d/raspberrypi.conf; then
  echo -e '\ni2c-dev' | sudo tee -a /etc/modules-load.d/raspberrypi.conf
fi

# Enable SPI (e.g. used by LoRa modules)
if ! grep -qFx "dtparam=spi=on" /boot/config.txt; then
  echo -e '\ndtparam=spi=on' | sudo tee -a /boot/config.txt
fi

################################################################################


echo "# Downloading Docker images..."

sudo docker network create wazigate

sudo docker-compose pull
sudo docker-compose up --no-start

cd $WAZIGATE/apps/waziup/wazigate-system
sudo docker-compose pull
sudo docker-compose up --no-start

cd $WAZIGATE/apps/waziup/wazigate-lora
sudo docker-compose pull
sudo docker-compose up --no-start

################################################################################

echo -e "\n192.168.200.1\twazigate\n" | sudo tee -a /etc/hosts
echo -e 'wazigate' | sudo tee /etc/hostname
echo -e "loragateway\nloragateway" | sudo passwd $USER

echo -e '\nstatic domain_name_servers=8.8.8.8' | sudo tee -a /etc/dhcpcd.conf

################################################################################


echo "Done"

for i in {10..01}; do
	echo -ne "Rebooting in $i seconds... \033[0K\r"
	sleep 1
done
sudo reboot

exit 0
