#
# @ Moji July 25th 2019
#
#---------------------------------#

from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306, ssd1325, ssd1331, sh1106
from PIL import ImageFont
import urllib.request
import time
import os
import subprocess
import json
import re

#---------------------------------#

linespace = 15;
dispWidth = 16; # Display width in terms of character w.r.t the selected font

PATH	= os.path.dirname(os.path.abspath(__file__));

serial	= i2c( port = 1, address = 0x3C);
device	= ssd1306( serial, rotate = 0);
font	= ImageFont.truetype( PATH +'/fonts/FreePixel.ttf', 15); # (font, size)

#---------------------------------#

def main():
	clearExtMsg();
	allOK = False;

	heartbeat = False;
	while True:
		msg = [];

		#------------#
		
		msg = getExtMsg();
		if( len( msg) > 0):
			oledWrite( msg);
			msg = [];
			time.sleep( 1);
			continue;
		
		#------------#
		
		heartTxt = '  ';
		heartbeat = not heartbeat;
		if( heartbeat):
			heartTxt = '* ';

		netTxt = "[Internet XX]";
		if( internetAccessible()):
			netTxt = "[Internet OK]";
		msg.append( heartTxt + netTxt);
		msg.append( " ");

		#------------#

		eip, wip = getIPs();
		if( len( eip) > 0):
			#msg.append( "Ethernet: "+ eip);
			msg.append( eip);

		if( len( wip) > 0):
			#msg.append( "Wi IP: ");
			msg.append( wip);

		#------------#

		oledWrite( msg);
		time.sleep( 1);
		
		if( not allOK):
			allOK, res = getGWstatus();
			oledWrite( res);
			time.sleep( 1);
		
#---------------------------------#

def oledClean():
	oledWrite( []);

#---------------------------------#

def oledWrite( msg):
	line = 0;
	try:
		with canvas(device) as draw:
			for txt in msg:
				draw.text( ( 0, line), txt, font = font, fill = "white");
				line += linespace;
	except:
		print( "Some error, probably a push button ;)");


#---------------------------------#

def getIPs():
	#cmd = 'ip -4 addr show eth0 | grep -oP \'(?<=inet\s)\d+(\.\d+){3}\'';
	cmd = 'status=$(ip addr show eth0 | grep "state UP"); if [ "$status" == "" ]; then echo "NO Ethernet IP"; else echo $(ip -4 addr show eth0 | grep -oP \'(?<=inet\s)\d+(\.\d+){3}\');  fi;';
	res = subprocess.run( cmd, shell=True, check=True, executable='/bin/bash', stdout=subprocess.PIPE);
	eip = str( res.stdout.strip(), 'utf-8')
	
	#cmd = 'ip -4 addr show wlan0 | grep -oP \'(?<=inet\s)\d+(\.\d+){3}\'';
	cmd = 'status=$(ip addr show wlan0 | grep "state UP"); if [ "$status" == "" ]; then echo "NO WiFi IP"; else echo $(ip -4 addr show wlan0 | grep -oP \'(?<=inet\s)\d+(\.\d+){3}\');  fi;';
	res = subprocess.run( cmd, shell=True, check=True, executable='/bin/bash', stdout=subprocess.PIPE);
	wip = str( res.stdout.strip(), 'utf-8')

	#cmd = "top -bn1 | grep load | awk '{printf \"CPU:  %.2f\", $(NF-2)}'";
	#CPU = os.popen( cmd).read().strip();
	
	return eip, wip

#---------------------------------#

def getGWstatus():
	
	cmd = 'curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json?all=true';
	#res = subprocess.run( cmd, shell=False, check=True, executable='/bin/bash', stdout=subprocess.PIPE, stderr=subprocess.DEVNULL);
	#res = subprocess.run( cmd, shell=False, check=True, executable='/bin/bash', stdout=subprocess.PIPE);
	#res = json.loads( str( res.stdout.strip(), 'utf-8'));
	res = json.loads( os.popen( cmd).read().strip());

	allOk = True;
	out = [];
	for item in res:
		cName = re.findall( "(/\w+)-(\w+)", item['Names'][0])[0][1];
		item['State'] = item['State'].upper();
		out.append( ( cName + ": ").ljust( dispWidth - len( item['State'])) + item['State']);
		if( item['State'] != 'RUNNING'):
			allOk = False;

	return allOk, out;

#---------------------------------#

def internetAccessible():
	try:
		res = urllib.request.urlopen( "https://waziup.io").getcode();
		return res == 200;
	except:
		return False;

#---------------------------------#

def getExtMsg():

	res = [];
	msgF = PATH + '/msg.txt';
	if( not os.path.isfile( msgF)):
		return res;

	try:
		with open( msgF) as f:
			#res = f.read().strip().split( os.linesep);
			res = f.read().split( os.linesep);
		if( len( res) == 1 and len( res[0]) == 0):
			return [];
	except:
		return res;

	return res;

#---------------------------------#

def clearExtMsg():
	
	msgF = PATH + '/msg.txt';
	if( not os.path.isfile( msgF)):
		return 0;
	try:
		with open( msgF, 'w') as f:
			f.write( "");
	except:
		print( "Error: Could not clear the OLED buffer file!");


#---------------------------------#

if __name__ == "__main__":
	main();

#---------------------------------#