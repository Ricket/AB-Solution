#!/bin/sh

# Script name and version number
appName="AB-Solution"
appVersion="1.07"
appScript="ab-solution.sh"
releaseDate="20160402"

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
echo " Follow me on twitter:"
echo " https://twitter.com/ab_solution"
insert_dashed_line
echo ""
}

# say a few words about what we're going to do
script_welcome(){
echo ""
insert_dashed_line
echo  "  $appName $appVersion installation / upgrade"
insert_dashed_line
echo ""
echo  " This script will guide through the installation."
echo  " It will install files in the /$installDir/ directory on"
echo  " the device you select during install."
echo  ""
echo  " A previous $appName* installation will be upgraded."
echo  " Some entries will be written to $jScripts."
echo  ""
echo  " A backup of existing scripts will be made in the"
echo  " $backupDir directory on the device."
echo  ""
echo  " *) Includes Adblock WCHFA, the former name of this script"
echo  ""
insert_dashed_line
echo ""
}

# some colors
colorNone='\033[00m'
red='\033[0;31m'
ired='\033[49m\e[91m' #intense
green='\033[0;32m'
igreen='\033[0;92m' #intense
yellow='\033[0;33m'
iyellow='\033[0;93m' #intense

#----------#
# Routines #
#----------#

install_or_upgrade(){
basic_check
script_welcome
check_for_prev_install
check_for_manual_install
make_backup
write_update_hosts
log_install_or_upgrade
write_ab_dnsmasq_postconf
write_dnsmasq_postconf
write_b_w_list
finishing_steps
}

change_hosts_file_type(){
write_update_hosts
write_config_file
set_sane_permissions
}

#------ ----#
# Functions #
#---- ------#

# check requirements before attempting install
basic_check(){

case $(uname -m) in
	armv7l)
		PART_TYPES='ext2|ext3|ext4';;
	mips)
		PART_TYPES='ext2|ext3';;
	*)
		echo -e "\n$ired $(uname -m) is an unsupported platform to install"
		echo -e " $appName on.$colorNone\n\n Exiting...\n"
		exit 1;;
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
	echo -en " Would you like to reboot now? [1=Yes 2=Exit] " ;read RebootNow
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

# set todays date
dayOfWeek=`date +\%w` 			# 2 (for Tuesday)
hostsFileUpdateDay=`date +\%A`	# Tuesday, used for UI

# for updates only
if [ $prevInstall == "1" ] ;then

	echo -e " Found a previous installation to upgrade on:\n\n$igreen --> $adBlockingDevice$colorNone\n"
	echo -en " Please confirm to upgrade: [1=Yes 2=Exit] " ;read ConfirmDevice
	echo " Input: $ConfirmDevice"

	if [ $ConfirmDevice == "1" ];then
		echo ""
		echo -e " Using $adBlockingDevice to upgrade $appName\n"
		updating=1

	else
			echo " Exiting..."
			sleeptime=1
			reload_app
	fi

# for new install only
elif [ $prevInstall == "0" ] ;then

	i=1
	cd /tmp

	for mounted in `/bin/mount | grep -E "$PART_TYPES" | cut -d" " -f3` ; do
	  isPartitionFound="true"
	  echo "[$i] --> $mounted"
	  eval mounts$i=$mounted
	  i=`expr $i + 1`
	done

	if [ $i == "1" ] ;then
		echo ""
		echo -e "$ired No $PART_TYPES devices available. Exiting...$colorNone\n"
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

	
fi
}

# check for manual install of 'AdBlocking with combined hosts file'.
# ..doing my best to find the most obvious files and folders.
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

# remove services-start (entries)
remove_services_start(){

# remove entries from jffs/scripts/services-start, no longer needed
if [ -f $jScripts/services-start ];then
	# make a backup of the file
	cp -f $jScripts/services-start $installDirPath/$backupDir/services-start_$todayHour
	if grep -q "# generated by\|UpdateHosts\|restart_dnsmasq;logger" $jScripts/services-start;then
		# remove previous entries. no longer needed
		sed -i '/# generated by/d' $jScripts/services-start
		sed -i '/UpdateHosts/d' $jScripts/services-start
		sed -i '/restart_dnsmasq;logger/d' $jScripts/services-start
	fi
	# remove empty lines
	sed -i '/^[[:blank:]]*$/d' $jScripts/services-start
	# remove jffs/scripts/services-start if empty, no longer needed
	if ! [ -s $jScripts/services-start ];then
		echo " Removing $jScripts/services-start, empty file and no longer needed"
		rm $jScripts/services-start
	fi
fi
}

# write the post-mount file
write_post_mount(){

# writing post-mount, find out what to do 
if [ -f $jScripts/post-mount ];then
	# if latest file exists do nothing
	if grep -q "# generated by AB-Solution 1.07" $jScripts/post-mount;then
		echo -e "\n Found latest $jScripts/post-mount, leaving it alone"
	else
	# make a backup of the file
	cp -f $jScripts/post-mount  $jScripts/post-mount_$todayHour # important change this!!!!!!!
	echo " Existing $jScripts/post-mount was replaced."
	echo " A Backup of the file is located at $installDirPath/$backupDir"

cat > $jScripts/post-mount << EOF
#!/bin/sh

# generated by $appName $appVersion
if [ -d "$adBlockingDevice" ];then
	sleep 21
	service restart_dnsmasq
	logger "AB-Solution added entries via post-mount"
fi
EOF
	fi
else
echo " New $jScripts/post-mount written."
cat > $jScripts/post-mount  << EOF
#!/bin/sh

# generated by $appName $appVersion
if [ -d "$adBlockingDevice" ];then
	sleep 22
	service restart_dnsmasq
	logger "AB-Solution added entries via post-mount"
fi
EOF
fi
}

# make backups of previous installs
make_backup(){

installDirPath=$adBlockingDevice/$installDir

mkdir -p $installDirPath
mkdir -p $installDirPath/$logsDir
mkdir -p $installDirPath/$scriptsDir
mkdir -p $installDirPath/$confDir
mkdir -p $installDirPath/$backupDir

# move old backups from previous installs (backup location changed)
if [ -d $adBlockingDevice/adb-backup ];then
mv $adBlockingDevice/adb-backup $installDirPath/$backupDir/adb-backup
fi

# move /hosts/ from manual installs (white and blacklists may be in there)
if [ -d $adBlockingDevice/hosts ];then
mv $adBlockingDevice/hosts $installDirPath/$backupDir/hosts
fi

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

if [ -f $jScripts/post-mount ];then
	cp -f $jScripts/post-mount $installDirPath/$backupDir/post-mount_$todayHour
	echo " Backing up $jScripts/post-mount"
	echo -e " to $installDirPath/$backupDir/post-mount_$todayHour\n"
fi
}

# select the hosts file type
write_update_hosts(){

if [ $prevSettings == "1" ] && [ $updating == "1" ];then
	case $hostsFileType in
		Standard)		SelectHostsFileType=1;;
		Medium) 		SelectHostsFileType=2;;
		shooter40sw)	SelectHostsFileType=3;;
		Large)			SelectHostsFileType=4;;
	esac
else

	insert_dashed_line
	echo " Select the type of amalgamated hosts file to use."
	echo ""
	echo -e " Note: The file type can be changed anytime later.\n"

	echo " 1. Standard: Combines these hosts files:"
	echo "    winhelp2002.mvps.org, someonewhocares.org, pgl.yoyo.org."
	echo "    Restricted blocking of Ads. If unsure, start here."
	echo -e "    Filesize: ~680 KB, ~25'000 blocked hosts.\n"

	echo " 2. Medium: Standard files plus: malwaredomainlist.com."
	echo "    Blocks malware domains. A good choice."
	echo -e "    Filesize: ~720 KB, ~26'500 blocked hosts.\n"
	
	echo " 3. shooter40sw's choice: Medium files plus: "
	echo "    hosts-file.net: emd, grm, mmt, ad_servers."
	echo "    And adaway.org/hosts.txt"
	echo -e "    Filesize: ~5.8 MB, ~191'000 blocked hosts.\n"

	echo " 4. Large: Medium files plus: Two hpHosts files:"
	echo "    hosts-file.net and hphosts-partial (always latest)."
	echo "    Be careful, this blocks a lot! Use it only if you"
	echo "    know how to use the whitelist. You have been warned!"
	echo -e "    Filesize: ~11.9 MB, ~219'000 blocked hosts.\n"

	echo -en " Enter hosts file type: [1-4, 5=Exit] " ;read SelectHostsFileType
	echo " Input: $SelectHostsFileType"

	if [ $SelectHostsFileType == "5" ] ;then
		echo " Exiting..."
		sleeptime=5
		reload_app
	fi

fi

if [ -f $installDirPath/$updateHostsFile ];then
rm -f $installDirPath/$updateHostsFile
fi

# write the file header (part 1/3)
cat > $installDirPath/$scriptsDir/$updateHostsFile << EOF
#!/bin/sh
# generated by $appName $appVersion

# set directory
dir=$installDirPath

# removing blank, empty and Windows EOL in white- and blacklist
	sed -i '/^[[:blank:]]*$/d;s/\r$//' \$dir/whitelist.txt
	sed -i '/^[[:blank:]]*$/d;s/\r$//' \$dir/blacklist.txt

EOF

# write hosts file type (part 2/3)
if [ $SelectHostsFileType == "1" ];then

	echo -e " \n Writing standard $updateHostsFile file\n"

	hostsFileType=Standard

# standard hosts
cat >> $installDirPath/$scriptsDir/$updateHostsFile << EOF
# get hosts files and combine
wget -qO- \\
"http://winhelp2002.mvps.org/hosts.txt" \\
"http://someonewhocares.org/hosts/zero/hosts" \\
"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext&useip=0.0.0.0" \\
> \$dir/temp1

EOF

elif [ $SelectHostsFileType == "2" ];then

	echo -e " \n Writing medium $updateHostsFile file\n"

	hostsFileType=Medium

# medium hosts
cat >> $installDirPath/$scriptsDir/$updateHostsFile << EOF
# get hosts files and combine
wget -qO- \\
"http://winhelp2002.mvps.org/hosts.txt" \\
"http://someonewhocares.org/hosts/zero/hosts" \\
"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext&useip=0.0.0.0" \\
"http://www.malwaredomainlist.com/hostslist/hosts.txt" \\
> \$dir/temp1

EOF

elif [ $SelectHostsFileType == "3" ];then

	echo -e " \n Writing shooter40sw's $updateHostsFile file\n"

	hostsFileType=shooter40sw

# shooter40sw's hosts
cat >> $installDirPath/$scriptsDir/$updateHostsFile << EOF
# get hosts files and combine
wget -qO- \\
"http://winhelp2002.mvps.org/hosts.txt" \\
"http://someonewhocares.org/hosts/zero/hosts" \\
"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&startdate[day]=&startdate[month]=&startdate[year]=&mimetype=plaintext&useip=0.0.0.0" \\
"http://www.malwaredomainlist.com/hostslist/hosts.txt" \\
"http://adaway.org/hosts.txt" \\
"http://hosts-file.net/emd.txt" \\
"http://hosts-file.net/ad_servers.txt" \\
"http://hosts-file.net/grm.txt" \\
"http://hosts-file.net/mmt.txt" \\
> \$dir/temp1

EOF

elif [ $SelectHostsFileType == "4" ];then

	echo -e " \n Writing large $updateHostsFile file\n"

	hostsFileType=Large

# large hosts
cat >> $installDirPath/$scriptsDir/$updateHostsFile << EOF
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
cat >> $installDirPath/$scriptsDir/$updateHostsFile << EOF
# amalgamate the hosts files, removing duplicates and sort in alphabetical order
cat \$dir/temp1 | sed 's/127.0.0.1/0.0.0.0/g;s/\r$//' | grep -w ^0.0.0.0 | awk '{print \$1 " " \$2}' | sort -u > \$dir/temp2

# remove localhost and whitelisted entries
cat \$dir/temp2 | sed '/\b\(localhost\|local\)\b/d;/localhost.localdomain/d' | fgrep -vf \$dir/whitelist.txt > \$dir/hosts-adblock

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

# select logging on or off for install/upgrade
log_install_or_upgrade(){

if [ $prevSettings == "0" ] ;then

	insert_dashed_line
	echo " Dnsmasq can create a log file of all DNS queries."
	echo " The log is helpful for experienced users."
	echo ""
	echo -e " Note: Logging can be enabled or disabled anytime later.\n"
	echo -en " Do you want logging enabled now? [1=Yes 0=No] " ;read logActivate

	if [ $logActivate == "1" ];then
		# set logging disabled
		loggingState=on
	elif [ $logActivate == "0" ];then
		loggingState=off
	fi

	# set Adblocking to on for install and upgrade
	adBlockingState=on
fi 
}

# write the ab_dnsmasq_postconf.sh file
write_ab_dnsmasq_postconf(){

case $hostsFileUpdateDay in
    Monday )
        dayOfWeek=1 ;;
    Tuesday )
        dayOfWeek=2 ;;
    Wednesday )
        dayOfWeek=3 ;;
    Thursday )
        dayOfWeek=4 ;;
    Friday )
        dayOfWeek=5 ;;
    Saturday )
        dayOfWeek=6 ;;
    Sunday )
        dayOfWeek=0 ;;
esac

if [ $adBlockingState == "on" ];then
cru d UpdateHosts
cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$scriptsDir/$updateHostsFile"
elif [ $adBlockingState == "off" ];then
cru d UpdateHosts
fi

if [ $adBlockingState == "on" ] && [ $loggingState == "on" ];then

echo -e " \n Writing $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh\n (Adblocking and logging on)"

cat > $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh << EOF
#!/bin/sh
cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$scriptsDir/$updateHostsFile"
CONFIG=\$1
source /usr/sbin/helper.sh
logger "AB-Solution added entries via ab_dnsmasq_postconf.sh"
pc_append "address=/0.0.0.0/0.0.0.0" \$CONFIG
pc_append "ptr-record=0.0.0.0.in-addr.arpa,0.0.0.0" \$CONFIG
pc_append "addn-hosts=_installDirPath_/hosts-adblock" \$CONFIG
pc_append "addn-hosts=_installDirPath_/blacklist.txt" \$CONFIG
pc_append "log-facility=_installDirPath_/logs/dnsmasq.log" \$CONFIG
pc_append "log-async" \$CONFIG
pc_append "log-queries" \$CONFIG
EOF
fi

if [ $adBlockingState == "on" ] && [ $loggingState == "off" ];then

echo -e " \n Writing $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh\n (Adblocking on, logging off)"

cat > $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh << EOF
#!/bin/sh
cru a UpdateHosts "00 02 * * $dayOfWeek $installDirPath/$scriptsDir/$updateHostsFile"
CONFIG=\$1
source /usr/sbin/helper.sh
logger "AB-Solution added entries via ab_dnsmasq_postconf.sh"
pc_append "address=/0.0.0.0/0.0.0.0" \$CONFIG
pc_append "ptr-record=0.0.0.0.in-addr.arpa,0.0.0.0" \$CONFIG
pc_append "addn-hosts=_installDirPath_/hosts-adblock" \$CONFIG
pc_append "addn-hosts=_installDirPath_/blacklist.txt" \$CONFIG
EOF
fi

if [ $adBlockingState == "off" ] && [ $loggingState == "on" ];then

echo -e " \n Writing $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh\n (Adblocking off, logging on)"

cat > $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh << EOF
#!/bin/sh
CONFIG=\$1
source /usr/sbin/helper.sh
logger "AB-Solution added entries via ab_dnsmasq_postconf.sh"
pc_append "log-facility=_installDirPath_/logs/dnsmasq.log" \$CONFIG
pc_append "log-async" \$CONFIG
pc_append "log-queries" \$CONFIG
EOF
fi

if [ $adBlockingState == "off" ] && [ $loggingState == "off" ];then

echo -e " \n Writing $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh\n (Adblocking off, logging off)"

cat > $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh << EOF
#!/bin/sh
# Adblocking and logging is off, file empty
EOF
fi

eval sed -i 's,_installDirPath_,$installDirPath,g'  $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh

# message when logging is activated
if [ $loggingState == "on" ];then

	echo ""
	echo " The logfile will rotate every $hostsFileUpdateDay @ 2:00 a.m."
	echo -e " to dnsmasq.log.old\n"
fi

set_sane_permissions
}

# write the dnsmasq.postconf file
write_dnsmasq_postconf(){

# find out what to do 
if [ -f $jScripts/dnsmasq.postconf ];then
	# if file found, but not written by AB-Solution 1.06 version (note to self: leave this at 1.06, even if newer)
	if ! grep -q "# generated by AB-Solution 1.06" $jScripts/dnsmasq.postconf ;then
		# make a backup of it
		cp -f $jScripts/dnsmasq.postconf $installDirPath/$backupDir/dnsmasq.postconf_$todayHour
# file found but older version of script, write new dnsmasq.postconf file
cat > $jScripts/dnsmasq.postconf  << EOF
#!/bin/sh

# generated by $appName $appVersion
if [ -d "$adBlockingDevice" ];then
	source $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh
	logger "AB-Solution linked dnsmasq.postconf to ab_dnsmasq_postconf.sh"
fi
EOF
	fi
else
# no file found, write new dnsmasq.postconf file
cat > $jScripts/dnsmasq.postconf  << EOF
#!/bin/sh

# generated by $appName $appVersion
if [ -d "$adBlockingDevice" ];then
	source $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh
	logger "AB-Solution linked dnsmasq.postconf to ab_dnsmasq_postconf.sh"
fi
EOF
fi
}

# write the white- and blacklist.txt files if not existing
write_b_w_list(){

if [ ! -f $installDirPath/whitelist.txt ];then
echo " Writing the whitelist.txt to $installDirPath/"

cat > $installDirPath/whitelist.txt << EOF
# Please support SmallNetBuilder.com by leaving these in the whitelist. Thanks
# Add whitelisted Domains in the same format as these:
vma.tgdaily.net
tgdaily.net
assets.omidoo.com
z-na.amazon-adsystem.com
servedby.flashtalking.com
flashtalking.com
ad2.netshelter.net
EOF
fi

if [ ! -f $installDirPath/blacklist.txt ];then
echo " Writing the blacklist.txt to $installDirPath/"

cat > $installDirPath/blacklist.txt << EOF
# NO mapping of IP addresses such as: 0.0.0.0 123.123.12.3. This will NOT work in Dnsmasq
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
}

# read and process the white- and blacklist.
#thanks @faria for the really fast code!
process_b_w_list(){
if [ $prevSettings == "0" ];then
	error_config
elif [ $adBlockingState == "on" ];then
	echo " removing blank, empty and Windows EOL in white- and blacklist"
	sed -i '/^[[:blank:]]*$/d;s/\r$//' $installDirPath/whitelist.txt
	sed -i '/^[[:blank:]]*$/d;s/\r$//' $installDirPath/blacklist.txt
	cp $installDirPath/hosts-adblock $installDirPath/temp
	echo " removing whitelist entries in hosts file"
	cat $installDirPath/temp | fgrep -vf $installDirPath/whitelist.txt > $installDirPath/hosts-adblock
	rm $installDirPath/temp
	echo " restarting Dnsmasq to apply changes"
	service restart_dnsmasq
	echo -e " Dnsmasq restarted\n"
elif [ $adBlockingState == "off" ];then
	echo " Adblocking Is disabled. Enable it first."
fi
}

# make and write the amalgamated hosts file, write post-mount, cron and setup logfile
finishing_steps(){

insert_dashed_line

if [ $adBlockingState == "on" ];then
	# set sane permissions (1/2)
	set_sane_permissions
	echo " Amalgamating the $hostsFileType hosts file."
	echo -e " This may take a little while to process.\n Verbose output follows:\n"
	if [ $prevSettings == "0" ] ;then
		read -t 10 -p " Hit [Enter] or wait 10 seconds to start the process"; echo
	fi

	# run the hosts file amalgamater for the first time

	sh -x $installDirPath/$scriptsDir/$updateHostsFile
else
	echo " Not updating the hosts file, Adblocking is off"
fi

remove_services_start

write_post_mount

if [ $adBlockingState == "on" ];then
	echo -e " \n The hosts file will update every $hostsFileUpdateDay @ 2:00 a.m.\n"
fi

write_config_file

check_installation

insert_dashed_line

if [ $checkNok == "0" ];then
	echo -e "$igreen    $appName install or upgrade complete!$colorNone"
else
	echo -e "$ired    $appName install or upgrade failed!$colorNone"
fi

insert_dashed_line

echo ""
echo " The install log is saved here:"
echo -e " $installDirPath/$logsDir/$installLog\n"

# move install log to log dir, delete old install logs
rm -f $installDirPath/$logsDir/*install.log
mv -f /tmp/$installLog $installDirPath/$logsDir/$installLog
set_sane_permissions

if [ $checkNok == "0" ];then
	sleeptime=5
	reload_app_install
else
	sleeptime=10
	reload_app
fi

#Phew! all done.
}

# check installation
check_installation(){
checkNok=0
echo -e " \n Doing final checks if $appName installed properly\n"

echo " checking /jffs/scripts/dnsmasq.postconf"
if [ -f $jScripts/dnsmasq.postconf ];then
	echo " OK, file found"
	if grep -q "source /tmp/mnt" $jScripts/dnsmasq.postconf;then
		echo " OK, file looks good"
	else echo " dnsmasq.postconf is NOT OK, missing entries";checkNok=1
	fi
else echo " dnsmasq.postconf is NOT OK, file missing";checkNok=1
fi

echo -e "\n checking /jffs/scripts/post-mount"
if [ -f $jScripts/post-mount ];then
	echo " OK, file found"
	if grep -q "service restart_dnsmasq" $jScripts/post-mount;then
		echo " OK, file looks good"
	else echo " post-mount is NOT OK, missing entries";checkNok=1
	fi
else echo " post-mount is NOT OK, file missing";checkNok=1
fi

echo -e "\n checking ab_dnsmasq_postconf.sh"
if [ -f $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh ];then
	echo " OK, file found"
	if [ $adBlockingState == "on" ] ;then
		if grep -q "UpdateHosts" $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh;then
			echo " OK, file looks good"
		else echo " ab_dnsmasq_postconf.sh is NOT OK, missing entries";checkNok=1
		fi
	elif [ $loggingState == "on" ] ;then
		if grep -q "log-facility" $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh;then
			echo " OK, file looks good"
		else echo " ab_dnsmasq_postconf.sh is NOT OK, missing entries";checkNok=1
		fi
	elif [ $adBlockingState == "off" ] && [ $loggingState == "off" ];then
		if grep -q "logging is off" $installDirPath/$scriptsDir/ab_dnsmasq_postconf.sh;then
			echo " OK, file looks good"
		else echo " ab_dnsmasq_postconf.sh is NOT OK, missing entries";checkNok=1
		fi
	fi
else echo " ab_dnsmasq_postconf.sh is NOT OK, file missing";checkNok=1
fi

echo -e "\n checking hosts-adblock"
if [ -f $installDirPath/hosts-adblock ];then
	echo " OK, file found"
	if grep -q "0.0.0.0" $installDirPath/hosts-adblock;then
		echo " OK, file looks good"
	else echo " hosts-adblock is NOT OK, missing entries";checkNok=1
	fi
else echo " hosts-adblock is NOT OK, file missing";checkNok=1
fi

echo -e "\n checking ab-solution.cfg"
if [ -f $installDirPath/.config/ab-solution.cfg ];then
	echo " OK, file found"
	if grep -q "/tmp/mnt/" $installDirPath/.config/ab-solution.cfg;then
		echo " OK, file looks good"
	else echo " ab-solution.cfg is NOT OK, missing entries";checkNok=1
	fi
else echo " ab-solution.cfg is NOT OK, file missing";checkNok=1
fi

echo -e "\n checking update-hosts.sh"
if [ -f $installDirPath/$scriptsDir/update-hosts.sh ];then
	echo " OK, file found"
	if grep -q "/tmp/mnt/" $installDirPath/$scriptsDir/update-hosts.sh;then
		echo " OK, file looks good"
	else echo " update-hosts.sh is NOT OK, missing entries";checkNok=1
	fi
else echo " update-hosts.sh is NOT OK, file missing";checkNok=1
fi

if [ $checkNok == "0" ];then
	echo -e " \n $igreen--> Looking good, no problems found.$colorNone\n"
else
	sleeptime=20
	echo -e " \n $ired--> Errors found.\n Please copy this final check's output and\n post it to the AB-Solution forum thread.$colorNone\n"
fi
}

# write and update config file
write_config_file(){
	confFileLink=$installDirPath/$confDir/$confFile
	
	appScriptPath_=$(dirname "$(readlink -f "$0")")
	architecture=$(uname -m)
	routerName=$(nvram get productid)
	firmwareVersion=$(nvram get buildno)
	lan_ipaddr=$(nvram get lan_ipaddr)
	jffs2_scripts=$(nvram get jffs2_scripts)
	lan_dns_fwd_local=$(nvram get lan_dns_fwd_local)
	dhcp_dns1_x=$(nvram get dhcp_dns1_x)
	dhcp_dns2_x=$(nvram get dhcp_dns2_x)
	dhcp_gateway_x=$(nvram get dhcp_gateway_x)
	wan_dns1_x=$(nvram get wan_dns1_x)
	wan_dns2_x=$(nvram get wan_dns2_x)


	lastConfUpdate=`date +\%c` 	# Tue Feb 16 09:22:23 2016, used for conf file

	echo "# DO NOT EDIT THIS FILE! DANGER ZONE #" > $confFileLink
	echo "# Settings:" >> $confFileLink
	echo "appName_=\"$appName\"" >> $confFileLink
	echo "appVersionInstalled=\"$appVersion\"" >> $confFileLink
	echo "appScriptPath_=\"$appScriptPath\"" >> $confFileLink
	echo "adBlockingDevice_=\"$adBlockingDevice\"" >> $confFileLink
	echo "adBlockingState=\"$adBlockingState\"" >> $confFileLink
	echo "loggingState=\"$loggingState\"" >> $confFileLink
	if [ "$loggingState" == "on" ];then
		echo "loggingFile=\"$installDirPath/$logsDir/dnsmasq.log\"" >> $confFileLink
	fi
	echo "hostsFileType=\"$hostsFileType\"" >> $confFileLink
	echo "hostsFileUpdateDay=\"$hostsFileUpdateDay\"" >> $confFileLink
	echo "hostsFileUpdateScript=\"$installDirPath/$scriptsDir/$updateHostsFile\"" >> $confFileLink
	echo "" >> $confFileLink
	echo "# Router info:" >> $confFileLink
    echo "routerName=\"$routerName\"" >> $confFileLink
    echo "firmwareVersion=\"$firmwareVersion\"" >> $confFileLink
	echo "architecture=\"$architecture\"" >> $confFileLink
	echo "lan_ipaddr=\"$lan_ipaddr\"" >> $confFileLink
	echo "" >> $confFileLink
	echo "# Backup settings (not used yet):" >> $confFileLink
	echo "jffs2_scripts=\"$jffs2_scripts\"" >> $confFileLink
	echo "lan_dns_fwd_local=\"$lan_dns_fwd_local\"" >> $confFileLink
	echo "dhcp_dns1_x=\"$dhcp_dns1_x\"" >> $confFileLink
	echo "dhcp_dns2_x=\"$dhcp_dns2_x\"" >> $confFileLink
	echo "dhcp_gateway_x=\"$dhcp_gateway_x\"" >> $confFileLink
	echo "wan_dns1_x=\"$wan_dns1_x\"" >> $confFileLink
	echo "wan_dns2_x=\"$wan_dns2_x\"" >> $confFileLink
	echo "" >> $confFileLink
    echo "lastConfUpdate=\"$lastConfUpdate\"" >> $confFileLink
}

# follow the logfile (advanced)
follow_log_file(){

if [ $prevSettings == "0" ];then
	error_config
elif [ $loggingState == "off" ];then
	echo " Logging is disabled. Enable it first"
elif [ $loggingState == "on" ];then
	echo -e " Select log verbosity to follow:\n"
	echo " [1] Unfiltered log"
	echo " [2] Filtered by blocked domains (0.0.0.0)"
	   echo " [3] Filtered by term"
	echo -e "     e.g by IP address or parts thereof, google.com\n    $ired No spaces in filter term!$colorNone\n"
	echo -e "$yellow Hit CTRL-C to exit logging $colorNone"
	echo -en " Select log verbosity [1-3 4=Exit] " ;read loggingType
	if [ $loggingType == "1" ];then
		echo -e " --> following the logfile now (tail -F):\n"
		tail -F $installDirPath/$logsDir/dnsmasq.log
	elif [ $loggingType == "2" ];then
		echo -e " --> following the logfile now (tail -F | grep 0.0.0.0):\n"
		tail -F $installDirPath/$logsDir/dnsmasq.log | grep 0.0.0.0
	elif [ $loggingType == "3" ];then
		echo -en "\n Enter term to filter by: " ;read filterTerm
		case ${filterTerm} in
			*\ * ) echo -e "\n Filter term may not contain spaces" 
			echo -en "\n Enter term to filter by: " ;read filterTerm;; 
		esac
		echo -e " --> following the logfile now (tail -F | grep $filterTerm):\n"
		tail -F $installDirPath/$logsDir/dnsmasq.log | grep $filterTerm
	elif [ $loggingType == "4" ];then
		echo ""
		sleeptime=5
		reload_app
	fi
fi
sleeptime=5
reload_app
}

# Show content of white- or blacklist
show_wh_bl_list(){
if [ $prevSettings == "1" ];then
	echo " ${show}.txt has these entries:"
	insert_dashed_line
	cat  $installDirPath/${show}.* | sed -e 's/^/ /'
	insert_dashed_line
	echo -e " $show end\n"
	hint_overhead
	noclear=1
	show_menu
else
	error_config
	sleeptime=5
	reload_app
fi
}

# Show content of settings file
show_conf_content(){
if [ $prevSettings == "1" ];then
	echo " $confFile has these entries:"
	insert_dashed_line
	cat  $installDirPath/$confDir/$confFile | sed -e 's/^/ /; 1d'
	insert_dashed_line
	echo -e " $confFile end\n"
	hint_overhead
	noclear=1
	show_menu
else
	error_config
	sleeptime=5
	reload_app
fi
}

# enable or disable Adblocking
on_off_adblocking(){
if [ $prevSettings == "1" ];then
	if [ $adBlockingState == "on" ];then
		echo -e " \n Ad-blocking is active at the moment.\n"
		echo -en " Disable Ad-blocking? [1=Yes 2=Exit] " ;read adBlockingState
		if [ $adBlockingState == "1" ];then
			# set Adblocking disabled
			adBlockingState=off
			write_ab_dnsmasq_postconf
			write_config_file
			service restart_dnsmasq
			echo -e " \n Ad-blocking disabled.\n"
		else
			echo "  Exiting..."
		fi
	elif [ $adBlockingState == "off" ];then
		echo -e " \n Ad-blocking is inactive at the moment.\n"
		echo -en " Would you like to enable it? [1=Yes 2=Exit] " ;read adBlockingState
		if [ $adBlockingState == "1" ];then
			# set Adblocking enabled
			adBlockingState=on
			write_ab_dnsmasq_postconf
			write_config_file
			service restart_dnsmasq
			echo -e " \n Ad-blocking enabled.\n"
		else
			echo "  Exiting..."
		fi
	fi
	set_sane_permissions
else
	error_config
fi
}

# enable or disable dnsmasq logging
on_off_logging(){
if [ $prevSettings == "1" ];then
	if [ $loggingState == "on" ];then
		echo -e " \n Logging is active at the moment.\n"
		echo -en " Would you like to disable it? [1=Yes 2=Exit] " ;read logActivate
		if [ $logActivate == "1" ];then
			# set logging disabled
			loggingState=off
			write_ab_dnsmasq_postconf
			write_config_file
			service restart_dnsmasq
			echo -e " \n Logging disabled.\n"
		else
			echo "  Exiting..."
		fi
	elif [ $loggingState == "off" ];then
		echo -e " \n Logging is inactive at the moment.\n"
		echo -en " Would you like to enable it? [1=Yes 2=Exit] " ;read logActivate
		if [ $logActivate == "1" ];then
			# set logging enabled
			loggingState=on
			write_ab_dnsmasq_postconf
			write_config_file
			service restart_dnsmasq
			echo -e " \n Logging enabled.\n"
		else
			echo "  Exiting..."
		fi
	fi
	set_sane_permissions
else
	error_config
fi
}

# set sane directories and files permissions
set_sane_permissions(){
# to files on installDir
if [ -d $installDirPath ];then
	chmod -R a=r,a+X,u+w $installDirPath
	chmod 0755 $installDirPath/$scriptsDir/*
fi
# to files in jffs/scripts
chmod 0755 $jScripts/*
}

# reload the app
reload_app(){

echo -e " Refreshing Menu in a few seconds\n"
sleep $sleeptime

if [ -f $adBlockingDevice/$appScript ];then
	sh $adBlockingDevice/$appScript
else
	appScriptPath=$(dirname "$(readlink -f "$0")")
	sh $appScriptPath/$appScript
fi
}

# reload the app after install or upgrade
reload_app_install(){

cp_app_script

echo -e "\n No reboot required. Ads be gone now!\n"

echo -e " Refreshing Menu in a few seconds\n"

if [ -f $adBlockingDevice/$appScript ];then
	sleep $sleeptime
	sh $adBlockingDevice/$appScript
else
	appScriptPath=$(dirname "$(readlink -f "$0")")
	sleep $sleeptime
	sh $appScriptPath/$appScript
fi
}

# copy appScript to adblocking device
cp_app_script(){

appScriptPath=$(dirname "$(readlink -f "$0")")
echo " Copying $appScript to $adBlockingDevice"
if [ $adBlockingDevice != $appScriptPath ];then
	cp -f $appScriptPath/$appScript $adBlockingDevice/$appScript
	echo -e " $appScript copied to $adBlockingDevice\n"
else
	echo -e " $appScript is already on $adBlockingDevice\n"
fi
}

# Sorry to see you go! (uninstall app)
rm_ab_solution(){
if [ $prevSettings == "1" ] || [ $news == "0" ];then

	echo -e "$ired You are about to uninstall $appName. $colorNone\n"
	echo -en " Are you sure you want to do that? [1=Yes 2=Exit] " ;read UninstallNow
	if [ $UninstallNow == "1" ];then
		insert_dashed_line
		echo -e "\n Sorry to see you go...\n"

		# move post-mount
		if [ -f $jScripts/post-mount ];then
		mv $jScripts/post-mount $adBlockingDevice/post-mount_$todayHour
		echo -e " moved $jScripts/post-mount to $adBlockingDevice/post-mount_$todayHour\n"
		fi
		
		# move dnsmasq.postconf
		if [ -f $jScripts/dnsmasq.postconf ];then
		mv $jScripts/dnsmasq.postconf $adBlockingDevice/dnsmasq.postconf_$todayHour
		echo -e " moved $jScripts/dnsmasq.postconf to $adBlockingDevice/dnsmasq.postconf_$todayHour\n"
		fi
		
		# remove cron job
		cru d UpdateHosts
		echo -e " Cron job to update hosts is removed.\n"
		
		# restarting dnsmasq
		service restart_dnsmasq
		loggingState=off
		adBlockingState=off
		write_config_file
		
		echo -e " Dnsmasq restarted, $appName is removed from system."
		insert_dashed_line
		
		# remove adblocking dir
		echo -e "\n Do you want to remove all $appName files on $adBlockingDevice?"
		echo -e " This will also remove the white- and blacklist you may have customized.\n"
		echo -en " Remove all files? [1=Yes 2=No] " ;read RemoveAppFiles
		if [ $RemoveAppFiles == "1" ];then
		
			rm -rf $adBlockingDevice/$installDir
			
			# remove script
			echo " Removing this script now."
			echo -e " $appName uninstall complete.\n Good bye."
			appScriptPath=$(dirname "$(readlink -f "$0")")
			rm -rf $appScriptPath/$appScript
			exit 0
		
		else
			# remove script
			echo -e " \n $appName files remain on $adBlockingDevice\n"
			echo " Removing this script now."
			echo -e " $appName uninstall complete.\n Good bye."
			appScriptPath=$(dirname "$(readlink -f "$0")")
			rm -rf $appScriptPath/$appScript
			exit 0
		fi
		
	else
		echo -e " \n$igreen How good of you... $colorNone\n"
		sleeptime=5
		reload_app
	fi
else
	error_config
	sleeptime=5
	reload_app
fi
}

# hmm...
insert_dashed_line(){
echo " --------------------------------------------------"
}

# errors
error_config(){
echo -e " Error: No configuration file found.\n Install or upgrade $appName first.\n"
}

# hints
hint_overhead(){
echo -e "     ${ired}^^^^ Look up for the output ^^^^${colorNone}"
echo -e " ${yellow}Type 11 and hit Enter to bring the Menu back to\n the top of the screen.${colorNone}"
}

# essential settings
installDir=adblocking
backupDir=backup
scriptsDir=scripts
logsDir=logs
confDir=.config
updateHostsFile=update-hosts.sh
installLog=$appName-$appVersion-install.log
jScripts=/jffs/scripts
jConfigs=/jffs/configs
todayHour=`date +\%F_\%H` 	# 2016-02-16_08 used for backup files
confFile=ab-solution.cfg
noclear=0
firmwareVersionAct=$(nvram get buildno)

# find adblock device, conf file and set status
find_adblock_device(){

# the path to this script
appScriptPath=$(dirname "$(readlink -f "$0")")

if [ $(find /tmp/mnt/ -name $confFile) ];then
	# found conf file, lets see if the location is in the defined dir
	tmpDevice=$(find /tmp/mnt/ -name $confFile | sed 's/ab-solution.cfg//g; s/\/.config//g; s/\/adblocking\///g')

	if [ -f $tmpDevice/$installDir/$confDir/$confFile ] && [ -f $tmpDevice/$installDir/$scriptsDir/$updateHostsFile ] || [ -f $tmpDevice/$installDir/$updateHostsFile ];then
		if [ -f $tmpDevice/$installDir/$updateHostsFile ];then
		needsUpdate=1;else needsUpdate=0
		fi
		# found essential files to be present, linking conf file
		source $tmpDevice/$installDir/$confDir/$confFile

		if [ $adBlockingDevice_ == $tmpDevice ];then
			# conf file settings match with $find results. proper installation found
			prevInstall=1
			prevSettings=1
			updating=0
			adBlockingDevice=$adBlockingDevice_
			installDirPath=$adBlockingDevice/$installDir
			confFileLink=$installDirPath/$confDir/$confFile
		else
			# conf file settings do not match with $find results
			prevInstall=1
			prevSettings=0
			adBlockingDevice=$tmpDevice
			installDirPath=$adBlockingDevice/$installDir
		fi
	else
		# conf file not in proper location or update-hosts file missing
		prevInstall=1
		prevSettings=0
	fi

elif [ $(find /tmp/mnt/ -name $updateHostsFile) ];then
	# found update-hosts file
	tmpDevice=$(find /tmp/mnt/ -name $updateHostsFile | sed 's/update-hosts.sh//g; s/\/adblocking\///g')

	if [ -f $tmpDevice/$installDir/$scriptsDir/$updateHostsFile ] || [ -f $tmpDevice/$installDir/$updateHostsFile ];then
		# found update-hosts file in proper location
		prevInstall=1
		prevSettings=0
		adBlockingDevice=${tmpDevice%$installDir}
		installDirPath=$adBlockingDevice/$installDir
	else
		# update-hosts file not in proper location
		prevInstall=0
		prevSettings=0
	fi
else
	# nada, nothing usable found
	prevInstall=0
	prevSettings=0
fi

#  install or upgrade message
if [ $prevInstall == "0" ];then
	news=1
	message=" Type [i] to install Ad-blocking now"
elif [ $prevInstall == "1" ] && [ $prevSettings == "0" ];then
	news=1
	message=" Enter [i] to upgrade your Ad-blocking installation"
elif [ $needsUpdate == "1" ];then
	news=1
	message=" Some file locations have changed in this version.\n Enter [i] to upgrade your Ad-blocking installation"
else
	news=0
fi

case $adBlockingState in
	on)	
		adColor=$igreen
		updateDay="updates every ${igreen}$hostsFileUpdateDay$colorNone @ 2:00 a.m.";;
	off)
		adColor=$red
		updateDay="auto-update ${red}off$colorNone: Ad-blocking is disabled";;
	*)	
		adColor=$yellow
		updateDay="auto-updates ${yellow}Unknownday$colorNone"
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
	shooter40sw) 	hostColor=$igreen;;
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
	echo -e "  $appName $appVersion		 by thelonelycoder"
	insert_dashed_line
	if [ $prevSettings == "1" ];then
		echo "  $routerName ($architecture) fw-$firmwareVersionAct @ $lan_ipaddr"
	fi
	echo ""
	echo " [i]  Install or upgrade Ad-blocking"
	echo ""
	echo -e " [a]  Toggle Ad-blocking [${adColor}$adBlockingState${colorNone}]"
	echo -e " [l]  Toggle logging     [${logColor}$loggingState${colorNone}]"
	echo ""
	echo -e " [h]  Change hosts file type [${hostColor}$hostsFileType${colorNone}]"
	echo " [u]  Update hosts file manually"
	echo -e "      ($updateDay)"
	echo " [p]  Process white- and blacklist files"

	echo ""
	echo " [f]  Follow the logfile (select verbosity)"
	echo ""
	echo " [wl] Show whitelist or [bl] blacklist"
	echo " [c]  Show config file or [il] install log"
	echo ""
	echo " [s]  Show AB-Solution info"
	echo " [rm] Uninstall AB-Solution"
	echo ""
	echo " [e]  Exit script"
	if [ $news == "1" ];then
		echo ""
		echo -e " ${yellow}-------------------- Message ---------------------${colorNone}"
		echo -e "${iyellow}$message${colorNone}"
		echo -e " ${yellow}--------------------------------------------------${colorNone}"
	else
		echo  " __________________________________________________"
	fi
	echo ""
	while true; do
		read -p " What do you want to do? " menuSelect
		case $menuSelect in

		[Ii] )	# start install or upgrade, start logging
				install_or_upgrade | tee /tmp/$installLog
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
					sh -x $installDirPath/$scriptsDir/$updateHostsFile
					echo -e " hosts file type changed.\n"
				elif [ $adBlockingState == "off" ];then
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
					echo -e " Manually updating amalgamated hosts file\n"
					sh -x $installDirPath/$scriptsDir/$updateHostsFile
					echo -e " hosts file updated\n"
				elif [ $adBlockingState == "off" ];then
					echo " Adblocking Is disabled. Enable it first."
				fi
				sleeptime=5
				reload_app
						break;;

		[Pp])	# read and process the white- and blacklist
				insert_dashed_line
				process_b_w_list
				sleeptime=5
				reload_app
						break;;

		[Ff])	# follow the dnsmasq.log
				insert_dashed_line
				follow_log_file
						break;;

		[Ww][Ll])	# show content of whitelist
				insert_dashed_line
				show=whitelist
				show_wh_bl_list
						break;;
		[Bb][Ll])	# show content of blacklist
				insert_dashed_line
				show=blacklist
				show_wh_bl_list
						break;;

		[Cc])	# show content of config file
				insert_dashed_line
				show_conf_content
						break;;
						
		[Ii][Ll])	# show content of config file
				insert_dashed_line
				show=$logsDir/*-install
				show_wh_bl_list
						break;;

		[Ss])	# show script infos
				insert_dashed_line
				script_info
				script_welcome
				hint_overhead
				noclear=1
				show_menu
						break;;
						
		[Rr][Mm])	# uninstall app
				insert_dashed_line
				rm_ab_solution
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
						
		666)	# hidden, move appScript to adBlockingDevice (done during install)
				insert_dashed_line
				cp_app_script
				sleeptime=5
				reload_app
						break;;

		[Ee])	# exit and see ya
				echo -e " \n See you later...\n"
				echo "          ____        _____       _       _   _             "
				echo "    /\   |  _ \      / ____|     | |     | | (_)            "
				echo "   /  \  | |_) |____| (___   ___ | |_   _| |_ _  ___  _ __  "
				echo "  / /\ \ |  _ < ____ \___ \ / _ \| | | | | __| |/ _ \| '_ \ "
				echo " / ____ \| |_) |     ____) | (_) | | |_| | |_| | (_) | | | |"
				echo "/_/    \_\____/     |_____/ \___/|_|\__,_|\__|_|\___/|_| |_|"
				echo ""
						exit 0;;

		*) 	echo -e " \n Your input is not an option.\n"

		esac
	done
}
# Find previous install and then show the menu
find_adblock_device
show_menu
#eof