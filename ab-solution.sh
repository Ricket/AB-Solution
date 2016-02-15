#!/bin/sh

# Script name and version number
appName="AB-Solution"
appVersion="1.0"
appScript="ab-solution.sh"
releaseDate="20160215"

# script info
script_info(){
echo " AB-Solution is a shell script to install"
echo " \"AdBlocking with combined hosts file\""
echo " for Asus routers using Asuswrt-Merlin firmware."
echo ""
echo " See http://www.snbforums.com/forums/asuswrt-merlin.42/"
echo ""
echo " Script by thelonelycoder"
echo " http://www.snbforums.com/members/thelonelycoder.25480/"
echo ""
echo " Download the latest version from GitHub:"
echo " https://github.com/decoderman"
insert_dashed_line
echo ""
}

# say a few words about what we're going to do
script_welcome(){
echo  " __________________ $appName $appVersion __________________"
echo ""
echo  " This script will guide through the installation."
echo  " It will install files in the /$installDir/ directory on"
echo  " the device you select during install."
echo  ""
echo  " A previous $appName* installation will be updated."
echo  " Some start scripts will be written to $jScripts."
echo  ""
echo  " A backup of existing scripts will be made in the"
echo  " $backupDir directory on the device."
echo  ""
echo  " *) Includes Adblock WCHFA, the former name of this script"
echo  " __________________________________________________________"
echo ""
}

# some colors
colorNone='\033[00m'
red='\033[0;31m'
green='\033[0;32m'
igreen='\033[0;92m' #intense
yellow='\033[0;33m'

#----------#
# Routines #
#----------#

install_or_update(){
basic_check
check_for_prev_install
}

install_adblock(){
script_welcome
select_device
check_for_manual_install
make_backup
write_hosts_update_file
log_install_or_update
write_dnsmasq_file
write_b_w_list
finishing_steps
}

update_adblock(){
check_for_manual_install
make_backup
write_hosts_update_file
log_install_or_update
write_dnsmasq_file
write_b_w_list
finishing_steps
}

change_hosts_file_type(){
write_hosts_update_file
set_sane_perms
write_config_file
}

#------ ----#
# Functions #
#---- ------#

# check requirements before attempting install
basic_check(){
case $(uname -m) in
	armv7l)
		PART_TYPES='ext2|ext3|ext4'
		;;
	mips)
		PART_TYPES='ext2|ext3'
		;;
	*)
		echo " This is an unsupported platform. Exiting..."
		exit 1
		;;
esac

if [ "$(nvram get jffs2_scripts)" != "1" ] ;then
	echo " - Custom scripts in /jffs/ were enabled"
	nvram set jffs2_scripts=1
	nvram commit
	needsReboot=1
else
	needsReboot=0
fi

if [ "$(nvram get jffs2_format)" = "1" ] ;then
	echo " - A /jffs/ format is sheduled"
	needsReboot=1
fi

if [ ! -d $jScripts ];then
	echo " - /jffs/ needs a reboot"
	needsReboot=1
fi

if [ "$(nvram get lan_dns_fwd_local)" != "0" ] ;then
	echo " - Setting upstream DNS needs activation"
	nvram set lan_dns_fwd_local=0
	nvram commit
	needsReboot=1
fi

if [ "$(nvram get dhcp_dns1_x)" != "" ] || [ "$(nvram get dhcp_dns2_x)" != "" ];then
	echo -e " Removing LAN DNS Server(s): \n -$(nvram get dhcp_dns1_x) \n -$(nvram get dhcp_dns2_x)"
	echo -e " Otherwise AdBlock will not work."
	echo -e " You can add them in WAN Settings by setting the"
	echo -e " "Connect to DNS Server automatically" to "No""
	echo -e " and then entering your DNS Server(s) there."
	nvram set dhcp_dns1_x=
	nvram set dhcp_dns2_x=
	nvram commit
	needsReboot=1
fi

if [ $needsReboot == "1" ] ;then
	echo -e " \n Changes were made that require to reboot the router."
	echo -e " These are necessary for adBlocking to work afterwards.\n"
	echo -en " Would you like to reboot now?\n [1=Yes 2=Exit] " ;read RebootNow
	if [ $RebootNow == "1" ];then
		echo " Rebooting router..."
		reboot
		exit 0
	else
		echo -e " \n You'll have to reboot the router manually.\n"
		exit 0
	fi
fi
}

# look for a previous install by this script
check_for_prev_install(){
i=1
cd /tmp
insert_dashed_line
echo -e " Looking for compatible devices...\n"
for mounted in `/bin/mount | grep -E "$PART_TYPES" | cut -d" " -f3` ; do
	if [ -d $mounted/$installDir ] && [ -f $mounted/$installDir/$updateHostsFile ];then
		echo " [$i] --> $mounted  <-- previous installation"
		prevInstall=1
		adBlockingDevice=$mounted
		isPartitionFound="true"
		eval mounts$i=$mounted
		i=`expr $i + 1`
		elif [ $prevInstall == "0" ] ;then
			install_adblock
		else
			echo " [$i] --> $mounted"
			isPartitionFound="true"
			eval mounts$i=$mounted
			i=`expr $i + 1`
	fi
done

if [ $i == "1" ] ;then
	echo " No $PART_TYPES devices available. Exiting..."
	exit 1
fi

if [ $prevInstall == "1" ] ;then
	echo ""
	insert_dashed_line
	echo -e " Found a previous AdBlock installation on:\n\n --> $adBlockingDevice\n"
	echo -en " Do you want to update now? (recommended)\n [1=Update 2=New install 3=Exit] ";read UpdateConfirm
	if [ $UpdateConfirm == "1" ];then
		echo " Input: $UpdateConfirm"
		echo -e " \n Continuing with update on $adBlockingDevice\n"

		update_adblock

	elif [ $UpdateConfirm == "2" ];then
		echo -e " \n Continue with new installation\n"

		install_adblock

	else
		echo " Exiting..."
		cd
		sleeptime=1
		reload_app
	fi
fi
}

# check for manual install of 'AdBlocking with combined hosts file'.
# doing my best to find the most obvious files and folders.
check_for_manual_install(){
if [ -d $adBlockingDevice/hosts ] || [ -f $adBlockingDevice/hosts.clean ] || [ -f $jScripts/update-hosts.sh ];then
	echo ""
	insert_dashed_line
	echo -e " Found manual install file(s) or directory of\n 'AdBlocking with combined hosts file'.\n"
	echo " For details go to:"
	echo -e " http://www.snbforums.com/threads/adblocking-with-combined-hosts-file.15309\n"
	echo -e " These files or directories need to be removed\n before continuing:"
	echo -e " $adBlockingDevice/hosts/\n $adBlockingDevice/hosts.clean\n $jScripts/update-hosts.sh\n"
	echo -en " Should the script remove these now? (recommended) [1=Yes 2=Exit] " ;read RemoveManInstall
	if [ $RemoveManInstall == "1" ];then
		echo " Input: $RemoveManInstall"
		echo " Removing files..."
		rm -R $adBlockingDevice/hosts/
		rm -f $adBlockingDevice/hosts.clean
		rm -f $jScripts/update-hosts.sh
		echo " Done."

		else
			echo -e " \n You'll have to remove them manually\n"
			exit 0
	fi
fi

if [ -f $jConfigs/dnsmasq.conf.add ];then
	if grep -q "log-facility\|log-queries\|addn-hosts\|ptr-record\|address=/0.0.0.0/0.0.0.0" $jConfigs/dnsmasq.conf.add;then
	echo ""
	insert_dashed_line
	echo " Found entries in $jConfigs/dnsmasq.conf.add"
	echo -e " that will not work with $appName.\n"
	echo " Lines with these entries need to be removed before continuing:"
	echo -e " log-facility\n log-queries\n addn-hosts\n ptr-record\n address=/0.0.0.0/0.0.0.0\n"
	echo " The script can remove these lines now."
	echo -e " A backup will be made of the file.\n"
	echo -en " Remove the entries now? (recommended) [1=Yes 2=Exit] " ;read RemoveConfAdd
		if [ $RemoveConfAdd == "1" ];then
			echo " Input: $RemoveConfAdd"
			cp -r $jConfigs/dnsmasq.conf.add $jConfigs/dnsmasq.conf.add.old
			echo " Removing entries..."
			sed -i "/\b\(log-facility\|log-queries\|addn-hosts\|ptr-record\|address=\/0.0.0.0\/0.0.0.0\)\b/d" $jConfigs/dnsmasq.conf.add
			echo -e " Done\n"

		else
			echo -e " \n You'll have to remove them manually\n"
			exit 0
		fi
	fi
fi

if [ -f $jScripts/init-start ];then
	if grep -q "UpdateHosts" $jScripts/init-start;then
	echo ""
	insert_dashed_line
	echo " Found cron job in $jScripts/init-start"
	echo -e " that is no longer needed.\n"
	echo -e " Remove all lines with these entries (if they exist)\n before continuing:"
	echo -e " UpdateHosts\n"
	echo -e " The script can remove these now."
	echo -en " A backup will be made\n"
	echo -en " Remove the entries now? (recommended) [1=Yes 2=Exit] " ;read RemoveInitStart
		if [ $RemoveInitStart == "1" ];then
		echo " Input: $RemoveInitStart"
		cp -r $jffsScripts/init-start $jffsScripts/init-start.old
		echo " Removing entries..."
		sed -i '/UpdateHosts/d' $jffsScripts/init-start
		echo " Done."

		else
			echo -e " \n You'll have to remove them manually\n"
			exit 0
		fi
	fi
fi

}

# find a device to install on
select_device(){
i=1
cd /tmp
insert_dashed_line
echo -e " Looking for compatible devices...\n"
for mounted in `/bin/mount | grep -E "$PART_TYPES" | cut -d" " -f3` ; do
  isPartitionFound="true"
  echo " [$i] --> $mounted"
  eval mounts$i=$mounted
  i=`expr $i + 1`
done

if [ $i == "1" ] ;then
	echo " No $PART_TYPES devices available. Exiting..."
	exit 1
fi

echo -e " \n Select the device to install $appName on. (0 to Exit)\n "
echo -en " Enter device: [0-`expr $i - 1`] " ;read device
echo " Input: $device"

if [ "$device" -eq 0 ];then
	echo " Exiting..."
	exit 1
fi

if [ "$device" -gt `expr $i - 1` ] 2>/dev/null;then
	echo " Invalid device number! Exiting..."
	exit 0
	elif [ "$device" -eq "$device" ] 2>/dev/null;then
	echo ""
	else
	echo " Not a number! Exiting..."
	exit 1
fi

eval adBlockingDevice=\$mounts$device

insert_dashed_line
echo " Installing $appName on: $adBlockingDevice"
echo -en " \n Please confirm: [1=Yes 2=Exit] " ;read ConfirmDevice
echo " Input: $ConfirmDevice"

if [ $ConfirmDevice == "1" ];then
	echo ""
	echo -e " Using $adBlockingDevice to install $appName\n"

	else
		echo " Exiting..."
		exit 1
fi
}

# write the services-start file
make_services_start_file(){
if [ -f $jScripts/services-start ];then

# remove empty trailing lines
sed -i '/^[[:blank:]]*$/d' $jScripts/services-start
	if grep -q "#!/bin/sh" $jScripts/services-start;then
		# remove previous entries and empty lines. for clarity sed's are on separate lines
		sed -i '/# generated by/d' $jScripts/services-start
		sed -i '/UpdateHosts/d' $jScripts/services-start
		sed -i '/2;service restart_dnsmasq;logger/d' $jScripts/services-start
		sed -i '/^[[:blank:]]*$/d' $jScripts/services-start
# dude, check out that sleep timer with timeout for the limited shell!
cat >> $jScripts/services-start << EOF

# generated by $appName $appVersion
cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$updateHostsFile"
t=0;while [ \$t -lt 4 ] && [ ! -d "$adBlockingDevice" ];do sleep 5;let t=t+1;done;sleep 2;service restart_dnsmasq;logger "$appName: services-start has restarted dnsmasq"
EOF
	else
cat >> $jScripts/services-start << EOF
#!/bin/sh
# generated by $appName $appVersion
cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$updateHostsFile"
t=0;while [ \$t -lt 4 ] && [ ! -d "\$adBlockingDevice" ];do sleep 5;let t=t+1;done;sleep 2;service restart_dnsmasq;logger "$appName: services-start has restarted dnsmasq"
EOF
	fi
else
cat > $jScripts/services-start << EOF
#!/bin/sh
# generated by $appName $appVersion
cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$updateHostsFile"
t=0;while [ \$t -lt 4 ] && [ ! -d "$adBlockingDevice" ];do sleep 5;let t=t+1;done;sleep 2;service restart_dnsmasq;logger "$appName: services-start has restarted dnsmasq"
EOF
fi
chmod a+rx $jScripts/*
}

# make backups of previous installs
make_backup(){
installDirPath=$adBlockingDevice/$installDir

# remove old backups from previous installs (backup location changed)
if [ -d $adBlockingDevice/adb-backup ];then
rm -r $adBlockingDevice/adb-backup
fi

mkdir -p $installDirPath
mkdir -p $installDirPath/logs
mkdir -p $installDirPath/$confDir
mkdir -p $installDirPath/$backupDir

if [ -f $jConfigs/dnsmasq.conf.add.old ];then
	mv -f $jConfigs/dnsmasq.conf.add.old $installDirPath/$backupDir/dnsmasq.conf.add_$todayHour
fi

if [ -f $jScripts/init-start.old ];then
	mv -f $jScripts/init-start.old $installDirPath/$backupDir/init-start_$todayHour
fi

if [ -f $jScripts/dnsmasq.postconf ];then
	cp -f $jScripts/dnsmasq.postconf $installDirPath/$backupDir/dnsmasq.postconf_$todayHour
	if ! grep -q "# generated by" $jScripts/dnsmasq.postconf;then
		insert_dashed_line
		echo " Found an existing dnsmasq.postconf file in $jScripts/"
		echo -e " that was not created by this script.\n"
		echo " This file will be replaced."
		echo -e " A Backup of the file is located at $installDirPath/$backupDir/.\n"
		echo -en " Would you like to continue (recommended)? [1=Yes 2=Exit] " ;read ConfirmPostconfRem

		if [ $ConfirmPostconfRem == "1" ];then
		echo " Input: $ConfirmPostconfRem"
		echo -e " Continuing...\n"

		else
			echo ""
			echo " Exiting..."
			exit 0
		fi
	fi
	echo " Backing up $jScripts/dnsmasq.postconf"
	echo -e " to $installDirPath/$backupDir/dnsmasq.postconf_$todayHour\n"
fi

if [ -f $jScripts/services-start ];then
	cp -f $jScripts/services-start $installDirPath/$backupDir/services-start_$todayHour
	echo " Backing up $jScripts/services-start"
	echo -e " to $installDirPath/$backupDir/services-start_$todayHour\n"
fi
}

# select the hosts file type
write_hosts_update_file(){

insert_dashed_line

echo " Select the type of amalgamated hosts file to use."
echo ""
echo -e " Note: The file type can be changed anytime later.\n"

echo " 1. Standard: Combines these hosts files:"
echo "    winhelp2002.mvps.org, someonewhocares.org, pgl.yoyo.org."
echo "    Restricted blocking of Ads. If unsure, start here."
echo -e "    Filesize: ~750 KB, ~28'000 blocked hosts.\n"

echo " 2. Medium: Standard files plus: malwaredomainlist.com."
echo "    Blocks malware domains. A good choice."
echo -e "    Filesize: ~800 KB, ~30'000 blocked hosts.\n"

echo " 3. Large: Medium files plus: Two hpHosts files:"
echo "    hosts-file.net and hphosts-partial (always latest)."
echo "    Be careful, this blocks a lot! Use it only if you"
echo "    know how to use the whitelist. You have been warned!"
echo -e "    Filesize: ~12 MB, ~384'000 blocked hosts.\n"

echo -en " Enter hosts file type: [1-3, 4=Exit] " ;read HostsfileType
echo " Input: $HostsfileType"

if [ $HostsfileType == "4" ] ;then
	sleeptime=5
	reload_app
fi

# write the file header (part 1/3)
cat > $installDirPath/$updateHostsFile << EOF
#!/bin/sh
# generated by $appName $appVersion

# set directory
dir=$installDirPath

# remove blank and empty lines in black- and whitelist.txt files
sed -i '/^[[:blank:]]*$/d' \$dir/whitelist.txt
sed -i '/^[[:blank:]]*$/d' \$dir/blacklist.txt

EOF

# write hosts file type (part 2/3)
if [ $HostsfileType == "1" ] ;then

	echo -e " \n Writing standard $updateHostsFile file\n"

	hostsFileType=Standard

# standard hosts
cat >> $installDirPath/$updateHostsFile << EOF
# get hosts files and combine
wget -qO- \\
"http://winhelp2002.mvps.org/hosts.txt" \\
"http://someonewhocares.org/hosts/zero/hosts" \\
"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext&useip=0.0.0.0" \\
> \$dir/temp1

EOF

elif [ $HostsfileType == "2" ] ;then

	echo -e " \n Writing medium $updateHostsFile file\n"

	hostsFileType=Medium

# medium hosts
cat >> $installDirPath/$updateHostsFile << EOF
# get hosts files and combine
wget -qO- \\
"http://winhelp2002.mvps.org/hosts.txt" \\
"http://someonewhocares.org/hosts/zero/hosts" \\
"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext&useip=0.0.0.0" \\
"http://www.malwaredomainlist.com/hostslist/hosts.txt" \\
> \$dir/temp1

EOF

elif [ $HostsfileType == "3" ] ;then

	echo -e " \n Writing large $updateHostsFile file\n"

	hostsFileType=Large

# large hosts
cat >> $installDirPath/$updateHostsFile << EOF
# get hosts files and combine
wget -qO- \\
"http://winhelp2002.mvps.org/hosts.txt" \\
"http://someonewhocares.org/hosts/zero/hosts" \\
"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext&useip=0.0.0.0" \\
"http://www.malwaredomainlist.com/hostslist/hosts.txt" \\
"http://support.it-mate.co.uk/downloads/hosts.txt" \\
"http://hosts-file.net/hphosts-partial.txt" \\
> \$dir/temp1

EOF
fi

# write the file tail (part 3/3)
cat >> $installDirPath/$updateHostsFile << EOF
# amalgamate the hosts files, removing duplicates
cat \$dir/temp1 | sed s/127.0.0.1/0.0.0.0/g | sed \$'s/\r\$//' | grep -w ^0.0.0.0 | awk '{print \$1 " " \$2}' > \$dir/temp2

# remove whitelisted entries
cat \$dir/temp2 | fgrep -vf \$dir/whitelist.txt > \$dir/hosts-adblock

#remove temp files
rm \$dir/temp*

#rotate the logs when logging is enabled
if [ -f \$dir/logs/dnsmasq.log ];then
	mv \$dir/logs/dnsmasq.log \$dir/logs/dnsmasq.log.old
	logger "$appName rotated dnsmasq log file"
fi

#restart dnsmasq to reload the files
service restart_dnsmasq
logger "$appName updated hosts file and restarted dnsmasq"
EOF
}

# select logging on or off for install/update
log_install_or_update(){

insert_dashed_line

echo " Dnsmasq can create a log file of all DNS queries."
echo " The log is helpful for experienced users."
echo ""
echo -e " Note: Logging can be enabled or disabled anytime later.\n"
echo -en " Do you want logging enabled now? [1=Yes 0=No] " ;read logActivate

# set Adblocking to on for install and update
adBlockingState=on
}

# select logging on or off for install/update
log_install_or_update(){

insert_dashed_line

echo " Dnsmasq can create a log file of all DNS queries."
echo " The log is helpful for experienced users."
echo ""
echo -e " Note: Logging can be enabled or disabled anytime later.\n"
echo -en " Do you want logging enabled now? [1=Yes 0=No] " ;read logActivate

# set Adblocking to on for install/update
adBlockingState=on
}

# write the dnsmasq.postconf file
write_dnsmasq_file(){

if [ $logActivate == "1" ] || [ $adBlockingState == "on" ];then

# write the file header (part 1/2)
cat > $jScripts/dnsmasq.postconf << EOF
#!/bin/sh
# generated by $appName $appVersion

CONFIG=\$1
source /usr/sbin/helper.sh

if [ -d "__adBlockingDevice__" ];then
logger "$appName added entries via dnsmasq.postconf"
EOF
fi

# write status part (log, adblocking on or off) (part 2/2)

# logging on, adblocking on
if [ $logActivate == "1" ] && [ $adBlockingState == "on" ];then

	echo -e " \n Writing $jScripts/dnsmasq.postconf\n (Adblocking and logging on)"

	loggingState=on

cat >> $jScripts/dnsmasq.postconf << EOF
pc_append "address=/0.0.0.0/0.0.0.0" \$CONFIG
pc_append "ptr-record=0.0.0.0.in-addr.arpa,0.0.0.0" \$CONFIG
pc_append "addn-hosts=__installDir__/hosts-adblock" \$CONFIG
pc_append "addn-hosts=__installDir__/blacklist.txt" \$CONFIG
pc_append "log-facility=__installDir__/logs/dnsmasq.log" \$CONFIG
pc_append "log-async" \$CONFIG
pc_append "log-queries" \$CONFIG
else
logger "$appName: dnsmasq.postconf continues looking for __adBlockingDevice__"
fi
EOF

# logging on, adblocking off
elif [ $logActivate == "1" ] && [ $adBlockingState == "off" ];then

	echo -e " \n Writing $jScripts/dnsmasq.postconf\n (Adblocking off, logging on)"

	loggingState=on

cat >> $jScripts/dnsmasq.postconf << EOF
pc_append "log-facility=__installDir__/logs/dnsmasq.log" \$CONFIG
pc_append "log-async" \$CONFIG
pc_append "log-queries" \$CONFIG
else
logger "$appName: dnsmasq.postconf continues looking for __adBlockingDevice__"
fi
EOF

elif [ $logActivate == "0" ] && [ $adBlockingState == "on" ];then

	echo -e " \n Writing $jScripts/dnsmasq.postconf\n (Adblocking on, logging off)"

	loggingState=off

# logging off, adblocking on
cat >> $jScripts/dnsmasq.postconf << EOF
pc_append "address=/0.0.0.0/0.0.0.0" \$CONFIG
pc_append "ptr-record=0.0.0.0.in-addr.arpa,0.0.0.0" \$CONFIG
pc_append "addn-hosts=__installDir__/hosts-adblock" \$CONFIG
pc_append "addn-hosts=__installDir__/blacklist.txt" \$CONFIG
else
logger "$appName: dnsmasq.postconf continues looking for __adBlockingDevice__"
fi
EOF

rm -f $installDirPath/logs/dnsmasq.log*

fi

eval sed -i 's,__adBlockingDevice__,$adBlockingDevice,g' $jScripts/dnsmasq.postconf
eval sed -i 's,__installDir__,$installDirPath,g' $jScripts/dnsmasq.postconf

# message when logging is activated
if [ $logActivate == "1" ];then

	echo " To follow the dnsmasq.log run this in a terminal:"
	echo -e " tail -f $installDirPath/logs/dnsmasq.log\n"
	hostsFileUpdateDay=$weekDay
	echo " The logfile will rotate every $hostsFileUpdateDay @ 2:00 a.m."
	echo -e " to dnsmasq.log.old\n"
fi

# removing dnsmasq.postconf when Adblocking and logging off
if [ $logActivate == "0" ] && [ $adBlockingState == "off" ];then

	loggingState=off

	echo -e " \n Removing $jScripts/dnsmasq.postconf\n (Adblocking and logging off)"

	rm $jScripts/dnsmasq.postconf
	rm -f $installDirPath/logs/dnsmasq.log*
fi

chmod a+rx $jScripts/*
}

# write the white- and blacklist.txt files
write_b_w_list(){
echo " Writing the whitelist.txt and blacklist.txt files"
echo " to: $installDirPath/"

if [ ! -f $installDirPath/whitelist.txt ];then
cat > $installDirPath/whitelist.txt << EOF
# Add whitelisted Domains as follows, without the leading #
# kickass.to
# kat.cr
# Support SmallNetBuilder.com and snbforums.com by leaving these in the whitelist:
vma.tgdaily.net
tgdaily.net
z-na.amazon-adsystem.com
servedby.flashtalking.com
flashtalking.com
ad2.netshelter.net
EOF
fi

if [ ! -f $installDirPath/blacklist.txt ];then
cat > $installDirPath/blacklist.txt << EOF
# Add blacklisted Domains as follows, without the leading #
# 0.0.0.0 pricegrabber.com
# 0.0.0.0 www.pricegrabber.com
EOF
fi

echo ""

insert_dashed_line

echo " To support SmallNetBuilder.com, some entries were"
echo " added in the whitelist.txt file to allow ads on"
echo -e " their websites. Please do not remove them. Thanks.\n"
sleep 2
}

# read and process the white- and blacklist.
#thanks @faria for the really fast code!
process_b_w_list(){
if [ $prevSettings == "0" ];then
	error_config
elif [ $adBlockingState == "on" ];then
	echo " removing blank lines in white- and blacklist"
	sed -i '/^[[:blank:]]*$/d' $installDirPath/whitelist.txt
	sed -i '/^[[:blank:]]*$/d' $installDirPath/blacklist.txt
	cp $installDirPath/hosts-adblock $installDirPath/temp
	echo " removing whitelist entries in hosts file"
	cat $installDirPath/temp | fgrep -vf $installDirPath/whitelist.txt > $installDirPath/hosts-adblock
	rm $installDirPath/temp
	echo " restarting Dnsmasq to apply changes"
	service restart_dnsmasq
	echo -e " Dnsmasq restarted\n"
elif [ $adBlockingState == off ];then
	echo " Adblocking Is disabled. Enable it first."
fi
}

# make and write the amalgamated hosts file, write services-start, cron and setup logfile
finishing_steps(){
insert_dashed_line
# set sane permissions (1/2)
set_sane_perms
echo " Amalgamating the $hostsFileType hosts file."
echo -e " This may take a little while to process.\n Verbose output follows:\n"

read -t 10 -p " Hit [Enter] or wait 10 seconds to start the process"; echo

# run the hosts file amalgamater for the first time
sh -x $installDirPath/$updateHostsFile

make_services_start_file

cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$updateHostsFile"

echo -e " \n The hosts file will update every $hostsFileUpdateDay @ 2:00 a.m.\n"
echo " To update manually, run this in a terminal:"
echo -e " sh $installDirPath/$updateHostsFile\n"

write_config_file

check_installation
sleep 3
insert_dashed_line
echo "    $appName install or update complete!"
insert_dashed_line
echo ""
echo " The install log is saved here:"
echo -e " $installDirPath/logs/$installog\n"
echo -e " No reboot required. Ads be gone now!\n"

# move install log to log dir, delete old install logs
rm -f $installDirPath/logs/*install.log
mv -f /tmp/$installog $installDirPath/logs/$installog
set_sane_perms
#Phew! all done.
}

# check installation
check_installation(){
checkNok=0
echo -e " Doing final checks if $appName is installed properly\n"

if [ $loggingState == "on" ];then
	echo " checking /jffs/scripts/dnsmasq.postconf"
	if [ -f $jScripts/dnsmasq.postconf ];then
		echo " OK"
		if grep -q "pc_append" $jScripts/dnsmasq.postconf;then
			echo " OK"
		else echo " dnsmasq.postconf is NOT OK";checkNok=1
		fi
	else echo " dnsmasq.postconf is NOT OK";checkNok=1
	fi
fi

echo " checking /jffs/scripts/services-start"
if [ -f $jScripts/services-start ];then
	echo " OK"
	if grep -q "adblocking/update-hosts.sh" $jScripts/services-start;then
		echo " OK"
	else echo " services-start is NOT OK";checkNok=1
	fi
else echo " services-start is NOT OK";checkNok=1
fi

echo " checking hosts-adblock"
if [ -f $installDirPath/hosts-adblock ];then
	echo " OK"
	if grep -q "0.0.0.0" $installDirPath/hosts-adblock;then
		echo " OK"
	else echo " hosts-adblock is NOT OK";checkNok=1
	fi
else echo " hosts-adblock is NOT OK";checkNok=1
fi

echo " checking ab-solution.cfg"
if [ -f $installDirPath/.config/ab-solution.cfg ];then
	echo " OK"
	if grep -q "# DO NOT" $installDirPath/.config/ab-solution.cfg;then
		echo " OK"
	else echo " ab-solution.cfg is NOT OK";checkNok=1
	fi
else echo " ab-solution.cfg is NOT OK";checkNok=1
fi

if [ $checkNok == "0" ];then
	echo -e " \n Looking good, no problems found.\n"
else
	echo -e " \n Errors found.\n Please copy this final check's output and\n post it to the AB-Solution forum thread.\n"
fi
}

# write and update config file
write_config_file(){

	theConfFile=$installDirPath/$confDir/$confFile

	appScriptPath=$(dirname "$(readlink -f "$0")")
	architecture=$(uname -m)
	jffs2_scripts=$(nvram get jffs2_scripts)
	lan_dns_fwd_local=$(nvram get lan_dns_fwd_local)
	routerName=$(nvram get productid)
	firmwareVersion=$(nvram get buildno)
	lan_ipaddr=$(nvram get lan_ipaddr)
	dhcp_dns1_x=$(nvram get dhcp_dns1_x)
	dhcp_dns2_x=$(nvram get dhcp_dns2_x)
	dhcp_gateway_x=$(nvram get dhcp_gateway_x)
	wan_dns1_x=$(nvram get wan_dns1_x)
	wan_dns2_x=$(nvram get wan_dns2_x)
	lastConfUpdate=$(date)

	echo "# DO NOT EDIT THIS FILE! DANGER ZONE #" > $theConfFile
	echo "# Settings:" >> $theConfFile
	echo "appName_=\"$appName\"" >> $theConfFile
	echo "appVersionInstalled=\"$appVersion\"" >> $theConfFile
	echo "appScriptPath_=\"$appScriptPath\"" >> $theConfFile
	echo "adBlockingDevice_=\"$adBlockingDevice\"" >> $theConfFile
	echo "adBlockingState=\"$adBlockingState\"" >> $theConfFile
	echo "loggingState=\"$loggingState\"" >> $theConfFile
	if [ "$loggingState" == "on" ];then
		echo "loggingFile=\"$installDirPath/logs/dnsmasq.log\"" >> $theConfFile
	fi
	echo "hostsFileType=\"$hostsFileType\"" >> $theConfFile
	echo "hostsFileUpdateDay=\"$hostsFileUpdateDay\"" >> $theConfFile
	echo "hostsFileUpdateScript=\"$installDirPath/$updateHostsFile\"" >> $theConfFile
	echo "" >> $theConfFile
	echo "# Router info:" >> $theConfFile
    echo "routerName=\"$routerName\"" >> $theConfFile
    echo "firmwareVersion=\"$firmwareVersion\"" >> $theConfFile
	echo "architecture=\"$architecture\"" >> $theConfFile
	echo "" >> $theConfFile
	echo "# Backup settings (not used yet):" >> $theConfFile
	echo "jffs2_scripts=\"$jffs2_scripts\"" >> $theConfFile
	echo "lan_dns_fwd_local=\"$lan_dns_fwd_local\"" >> $theConfFile
	echo "lan_ipaddr=\"$lan_ipaddr\"" >> $theConfFile
	echo "dhcp_dns1_x=\"$dhcp_dns1_x\"" >> $theConfFile
	echo "dhcp_dns2_x=\"$dhcp_dns2_x\"" >> $theConfFile
	echo "dhcp_gateway_x=\"$dhcp_gateway_x\"" >> $theConfFile
	echo "wan_dns1_x=\"$wan_dns1_x\"" >> $theConfFile
	echo "wan_dns2_x=\"$wan_dns2_x\"" >> $theConfFile
    echo "lastConfUpdate=\"$lastConfUpdate\"" >> $theConfFile
}

# Show content of settings file
show_conf_content(){
if [ $prevSettings == "1" ];then
	echo " $confFile has these entries:"
	insert_dashed_line
	cat  $installDirPath/$confDir/$confFile | sed -e 's/^/ /; s/file!//; 1d'
	insert_dashed_line
	echo -e " $confFile end\n"
else
	error_config
fi
}

# Enable or disable Adblocking without unistall
on_off_adblocking(){
if [ $prevSettings == "1" ];then
	if [ $adBlockingState == "on" ];then
		echo -e " \n Ad-blocking is active at the moment.\n"
		echo -en " Disable Ad-blocking? [1=Yes 2=Exit] " ;read DisableAdblocking
		if [ $DisableAdblocking == "1" ];then
			if [ $loggingState == "on" ];then
				logActivate=1
				adBlockingState=off
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking disabled.\n"
			fi
			if [ $loggingState == "off" ];then
				logActivate=0
				adBlockingState=off
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking disabled.\n"
			fi
		else
			echo "  Exiting..."
		fi
	elif [ $adBlockingState == "off" ];then
		echo -e " \n Ad-blocking is inactive at the moment.\n"
		echo -en " Would you like to enable it? [1=Yes 2=Exit] " ;read EnableAdblocking
		if [ $EnableAdblocking == "1" ];then
			if [ $loggingState == "on" ];then
				logActivate=1
				adBlockingState=on
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking enabled.\n"
			fi
			if [ $loggingState == "off" ];then
				logActivate=0
				adBlockingState=on
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking enabled.\n"
			fi
		else
			echo "  Exiting..."
		fi
	fi
else
	error_config
fi

set_sane_perms
}

# enable or disable dnsmasq logging
on_off_logging(){
if [ $prevSettings == "1" ];then
	if [ $loggingState == "on" ];then
		echo -e " \n Logging is active at the moment.\n"
		echo -en " Would you like to disable it? [1=Yes 2=Exit] " ;read logActivate
		if [ $logActivate == "1" ];then
			if [ $adBlockingState == "on" ];then
				logActivate=0
				adBlockingState=on
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking disabled.\n"
			fi
			if [ $adBlockingState == "off" ];then
				logActivate=0
				adBlockingState=off
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking disabled.\n"
			fi
		else
			echo "  Exiting..."
		fi
	elif [ $loggingState == "off" ];then
		echo -e " \n Logging is inactive at the moment.\n"
		echo -en " Would you like to enable it? [1=Yes 2=Exit] " ;read logActivate
		if [ $logActivate == "1" ];then
			if [ $adBlockingState == "on" ];then
				logActivate=1
				adBlockingState=on
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking enabled.\n"
			fi
			if [ $adBlockingState == "off" ];then
				logActivate=1
				adBlockingState=off
				write_dnsmasq_file
				service restart_dnsmasq
				write_config_file
				echo -e " \n Ad-blocking enabled.\n"
			fi
		else
			echo "  Exiting..."
		fi
	fi
else
	error_config
fi

set_sane_perms
}

# set sane directories and files permissions
set_sane_perms(){
if [ -d $installDirPath ];then
	chmod -R a=r,a+X,u+w $installDirPath
	chmod a+rx $installDirPath/$updateHostsFile
fi

chmod a+rx $jScripts/*
}

# reload the app
reload_app(){
echo -e " Refreshing Menu in a few seconds\n"
sleep $sleeptime
sh $appScriptPath/$appScript
}

# show debug
show_debug(){
echo " $debug"
}

# hmm...
insert_dashed_line(){
echo " --------------------------------------------------"
}

# errors
error_config(){
echo -e " Error: No configuration file found.\n Install or Update $appName first.\n"
}

# hints
hint_overhead(){
echo -e "     ${green}^^^^ Look up for the output ^^^^${colorNone}"
echo -e " ${yellow}Type 11 and hit Enter to bring the Menu back to\n the top of the screen.${colorNone}"
}

# experimental, mv of appScript to device
mv_app_script(){
if [ $prevSettings == "1" ] && [ $adBlockingDevice != $appScriptPath ];then
	mv $appScriptPath/$appScript $adBlockingDevice/$appScript
	cd $adBlockingDevice/
	write_config_file
	news=1
	message=" App moved!"
else
news=0
fi
}

# Some essential settings
installDir=adblocking
backupDir=backup
updateHostsFile=update-hosts.sh
installog=$appName-$appVersion-install.log
jScripts=/jffs/scripts
jConfigs=/jffs/configs
dayOfWeek=`date +\%u`
weekDay=`date +\%A`
todayHour=`date +\%F_\%H`
logDate=`date +\%c`
confDir=.config
confFile=ab-solution.cfg
noclear=0

# find adblock device, conf file and set status
find_adblock_device(){

# the path to this script
appScriptPath=$(dirname "$(readlink -f "$0")")

# find inststall dir or config file, set the status
configFile=$(find /tmp/mnt/ -name $confFile)
if [ $(find /tmp/mnt/ -name $confFile | sed 's#.*/##') == "$confFile" ];then
	source $configFile
	prevInstall=1
	prevSettings=1
	adBlockingDevice=$adBlockingDevice_
	installDirPath=$adBlockingDevice/$installDir
elif [ -d /tmp/mnt ];then
	_installDir=$(find /tmp/mnt/* -name $installDir)
	if [ -f $_installDir/$updateHostsFile ];then
		prevInstall=1
		prevSettings=0
		adBlockingDevice=${_installDir%$installDir}
		installDirPath=$adBlockingDevice/$installDir
		#tempconfigFile=/jffs/temp-$confFile
	else
		prevInstall=0
		prevSettings=0
		#tempconfigFile=/jffs/temp-$confFile
	fi
fi

#  install or update message
if [ $prevInstall == "0" ];then
	news=1
	hostsFileUpdateDay="Unknownday"
	message=" Enter [i] to install Ad-blocking now"
elif [ $prevInstall == "1" ] && [ $prevSettings == "0" ];then
	news=1
	hostsFileUpdateDay="Unknownday"
	message=" Enter [i] to update your Ad-blocking installation"
else
	news=0
fi

case $adBlockingState in
	on)	adColor=$igreen;;
	off) 	adColor=$red;;
	*)	adColor=$yellow
	adBlockingState="status unknown";;
esac

case $loggingState in
	on)	logColor=$igreen;;
	off) 	logColor=$red;;
	*)	logColor=$yellow
	loggingState="status unknown";;
esac

case $hostsFileType in
	Standard)	hostColor=$igreen;;
	Medium) 	hostColor=$igreen;;
	Large) 	hostColor=$igreen;;
	*)	hostColor=$yellow
	hostsFileType="type unknown";;
esac
}

#-------------#
# Start menu  #
#-------------#

show_menu(){
if [ $noclear == "0" ];then
	clear
fi
	insert_dashed_line
	echo "  A B - S O L U T I O N   A D B L O C K I N G"
	insert_dashed_line
	echo "  $appName $appVersion	         by thelonelycoder"
	insert_dashed_line
	if [ $prevSettings != "0" ];then
		echo "  $routerName ($architecture) fw-$firmwareVersion @ $lan_ipaddr"
	fi
	echo ""
	echo " [i] Install or update Ad-blocking"
	echo ""
	echo -e " [a] Toggle Ad-blocking [${adColor}$adBlockingState${colorNone}]"
	echo -e " [l] Toggle logging     [${logColor}$loggingState${colorNone}]"
	echo ""
	echo -e " [h] Change hosts file type [${hostColor}$hostsFileType${colorNone}]"
	echo " [u] Update hosts file manually"
	echo "     (auto-updates $hostsFileUpdateDay @ 2:00 a.m.)"
	echo " [p] Process the whitelist and"
	echo "     reload the blacklist"
	echo ""
	echo " [f] Follow the logfile (CTRL-C to exit)"
	echo ""
	echo " [c] Show config file"
	echo " [s] Show AB-Solution info"
	echo " $pwd"
	echo " [e] Exit script"
	if [ $news != "0" ];then
		echo -e " ${yellow}--------------------------------------------------${colorNone}"
		echo -e " ${yellow}$message${colorNone}"
	fi		
	echo  " __________________________________________________"
	echo ""
	while true; do
		read -p " What do you want to do? " menuSelect
		case $menuSelect in

		[Ii] )	# start install or update, start logging
				install_or_update | tee /tmp/$installog
				sleeptime=5
				reload_app
						break;;

		[Aa])	# Enable/disable Ad-blocking
				insert_dashed_line
				on_off_adblocking
				sleeptime=5
				reload_app
						break;;

		[Ll])	# Enable/disable Logging
				insert_dashed_line
				on_off_logging
				sleeptime=5
				reload_app
						break;;

		[Hh])	# Change hosts file type
				insert_dashed_line
				if [ $prevSettings == "0" ];then
					error_config
				elif [ $adBlockingState == "on" ];then
					echo " changing the hosts file type."
					change_hosts_file_type
					sh -x $installDirPath/update-hosts.sh
					echo -e " hosts file type changed.\n"
				elif [ $adBlockingState == off ];then
					echo " Adblocking Is disabled. Enable it first."
				fi
				sleeptime=5
				reload_app
						break;;

		[Uu])	# run the update-hosts.sh
				insert_dashed_line
				if [ $prevSettings == "0" ];then
					error_config
				elif [ $adBlockingState == "on" ];then
					echo " updating amalgamated hosts file"
					sh -x $installDirPath/update-hosts.sh
					echo -e " hosts file updated\n"
				elif [ $adBlockingState == off ];then
					echo " Adblocking Is disabled. Enable it first."
				fi
				sleeptime=5
				reload_app
						break;;

		[Pp])	# read and process the white- and blacklist.
				insert_dashed_line
				process_b_w_list
				sleeptime=5
				reload_app
						break;;

		[Ff])	# follow the dnsmasq.log
				insert_dashed_line
				if [ $prevSettings == "0" ];then
					error_config
				elif [ $loggingState == "on" ];then
					tail -F $installDirPath/logs/dnsmasq.log
				elif [ $loggingState == "off" ];then
					echo " Logging is disabled. Enable it first"
				fi
				sleeptime=5
				reload_app
						break;;

		[Cc])	# show content of config file
				insert_dashed_line
				show_conf_content
				hint_overhead
				noclear=1
				show_menu
						break;;

		[Ss])	# show script infos
				insert_dashed_line
				script_info
				script_welcome
				hint_overhead
				noclear=1
				show_menu
						break;;

		11)		# hidden, script reload menu
				sleeptime=0
				reload_app
						break;;

		22)		# hidden, check installation
				insert_dashed_line
				check_installation
				sleeptime=5
				reload_app
						break;;
		666)	# hidden, move appScript to adBlockingDevice
				insert_dashed_line
				mv_app_script
				sleeptime=5
				reload_app
						break;;

		[Ee])	# exit and good bye
				echo -e " \n See you later...\n"
						exit;;

		*) 	echo -e " \n Your input is not an option.\n"

		esac
	done
}
# Find previous install and then show the menu
find_adblock_device
show_menu

#eof