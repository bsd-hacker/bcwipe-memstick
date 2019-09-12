#!/bin/sh

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

do_setup () {
	kbdcontrol -d >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		# Syscons: use xterm
		TERM=xterm
	else   
		# Serial or other console
		echo
		echo "Welcome to FreeBSD!"
		echo
		echo "Please choose the appropriate terminal type for your system."  
		echo "Common console types are:"
		echo "   ansi     Standard ANSI terminal"
		echo "   vt100    VT100 or compatible terminal"
		echo "   xterm    xterm terminal emulator (or compatible)"
		echo
		echo -n "Console type [vt100]: "
		read TERM
		TERM=${TERM:-vt100}
	fi
	export TERM
}

cmd_bcwipe="bcwipe -I -b"
#cmd_bcwipe="./date.sh -I -b"

workdir="/tmp/bcwipe"
mkdir -p ${workdir}

tmpdir="${workdir}/tmp"
mkdir -p ${tmpdir}

taskdir="${workdir}/task"
mkdir -p ${taskdir}

tmp_result="${tmpdir}/result"

for i in calendar checklist dselect editbox form fselect gauge \
	infobox inputbox inputmenu menu mixedform mixedgauge \
	msgbox passwordbox passwordform pause prgbox \
	programbox progressbox radiolist tailbox tailboxbg textbox \
	timebox yesno
do
	eval "dialog_${i}=\"${tmpdir}/dialog.${i}\""
done

isa_task_working () {
	local	disk=$1
	local	result=0
	local	tpid=''

	if [ -s ${taskdir}/${disk}.pid ]; then
		tpid=`cat ${taskdir}/${disk}.pid`
		if kill -0 ${tpid}; then
			if ps axw | grep "^[ ]*${tpid} " | grep "${cmd_bcwipe}" > /dev/null 2>&1 ; then
				result=0
			else
				result=255
			fi
		else
			result=255
		fi
	else
		result=255
	fi

	if [ "X${result}" != "X0" ]; then
		rm -f ${taskdir}/${disk}.pid
	fi

	return ${result}
}

wiping_method="g"
wiping_method_option="-mg"
wiping_pass="7"
wiping_scheme_file=""

wiping_algorithms="
b/German BCI/VISTR 7-pass wiping/
d/U.S. DoD 5220-22M 7-pass extended character rotation wiping/
e/U.S. DoE 3-pass wiping/
f<file>/read wiping scheme from file. See *notes below/file
g/(default) 35-pass wiping by Peter Gutmann/
s/7-pass wiping by Bruce Schneier/
t/1-pass test mode: fill the start of 512-byte block with block number/
z/1-pass zero wiping/
N/U.S. DoD 5220-22M N-pass extended character rotation wiping/N-pass
"

isa_wiping_algorithm_method () {
	local result=0

	if [ "X${1}" != "X" ]; then
		if [ `echo "${wiping_algorithms}" | awk -F/ '{ if ($1 == "'"${1}"'") print "YES" }'` == "YES" ]; then
			result=0
		else
			result=255
		fi
	else
		result=255
	fi

	return ${result}
}

wiping_algorithm_method () {
	local result=""

	if [ "X${1}" != "X" ]; then
		result=`echo "${wiping_algorithms}" | awk -F/ '{ if ($1 == "'"${1}"'") print $1 }'`
	else
		result=`echo "${wiping_algorithms}" | awk -F/ '{ if ($1 != "") print $1 }'`
	fi

	echo "${result}"
}

wiping_algorithm_description () {
	local result=""

	result=`echo "${wiping_algorithms}" | awk -F/ '{ if ($1 == "'"${1}"'") print "\""$2"\"" }'`

	echo "${result}"
}

wiping_algorithm_option () {
	local result=""

	result=`echo "${wiping_algorithms}" | awk -F/ '{ if ($1 == "'"${1}"'") print $3 }'`

	echo ${result}
}

max_hight () {
	dialog --print-maxsize 2>&1 | sed -e 's/,//g' | awk '{ print $2 }'
}

max_width () {
	dialog --print-maxsize 2>&1 | sed -e 's/,//g' | awk '{ print $3 }'
}

exec_shell () {
	dialog --infobox "execute $1" 0 0
	$1
}

exec_bcwipe () {
	local	disk=$1

	dialog --msgbox \
	"${cmd_bcwipe} ${wiping_method_option} -l ${taskdir}/${disk}.log /dev/${disk} &" \
	0 0

	${cmd_bcwipe} ${wiping_method_option} -l ${taskdir}/${disk}.log /dev/${disk} > ${taskdir}/${disk}.log &
	echo "$!" > ${taskdir}/${disk}.pid
}

bcwipe_start () {
	local	disk=$1

	if isa_task_working ${disk} ; then
	else
		exec_bcwipe ${disk}
	fi
}

bcwipe_stop () {
	local	disk=$1

	dialog --yesno "Do you want to stop wiping for ${disk}?" 0 0 2> ${tmp_result}
	case $? in
	0)
		kill `cat ${taskdir}/${disk}.pid`
		;;
	1)
		;;
	*)
		;;
	esac
}

do_reboot () {
	local	dialog_file=${dialog_menu}
	local	op=''

	cat <<EOM > ${dialog_file}
    --menu \\
    "reboot or power off" \\
    0 0 0 \\
    Reboot "reboot (shutdown -r now)" \\
    PowerOff "power off (shutdown -p now)" \\
    Shutdown "shotdown (shutdown -h now)" \\
EOM

	dialog --file ${dialog_file} 2> ${tmp_result}
	case $? in
	0)
		op=`cat ${tmp_result}`
		case "${op}" in
		Reboot)
			shutdown -r now
			;;

		PowerOff)
			shutdown -p now
			;;

		Shutdown)
			shutdown -h now
			;;

		*)
			;;
		esac
		;;
	*)
		;;
	esac
}

menu_shell () {
	local	dialog_file=${dialog_menu}
	local	sh=""

	cat <<EOM > ${dialog_file}
    --menu \\
    "select shell" \\
    0 0 0 \\
EOM

	for sh in `grep '^\/' /etc/shells`
	do
		echo " ${sh} \"`basename ${sh}`\" \\" >> ${dialog_file}
	done

	dialog --file ${dialog_file} 2> ${tmp_result}

	sh=`cat ${tmp_result}`
	case "${sh}" in
	\"\")
		;;

	*)
		exec_shell "${sh}"
		;;
	esac
}

show_log () {
	local log_file=$1

	dialog --tailbox ${log_file} 0 0
}

show_env_values () {
	local	dialog_file=${dialog_inputmenu}

	cat <<EOM > ${dialog_file}
    --title "show values" \\
    --inputmenu \\
    "show values" \\
    `max_hight` `max_width` `max_hight` \\
EOM

	echo " \"maxsize\" \"`max_hight` x `max_width`\"\\" >> ${dialog_file}

	echo " \"cmd_bcwipe\" \"${cmd_bcwipe}\"\\" >> ${dialog_file}
	echo " \"workdir\" \"${workdir}\"\\" >> ${dialog_file}
	echo " \"tmpdir\" \"${tmpdir}\"\\" >> ${dialog_file}
	echo " \"taskdir\" \"${taskdir}\"" >> ${dialog_file}
	echo " \"tmp_result\" \"${tmp_result}\"\\" >> ${dialog_file}

	echo " \"wiping_method\" `wiping_algorithm_description ${wiping_method}`\\" >> ${dialog_file}
	echo " \"wiping_method_option\" \"${wiping_method_option}\"\\" >> ${dialog_file}
	echo " \"wiping_pass\" \"${wiping_pass}\"\\" >> ${dialog_file}
	echo " \"wiping_scheme_file\" \"${wiping_scheme_file}\"\\" >> ${dialog_file}

	dialog --file ${dialog_file} 2> ${tmp_result}
}

menu_wiping_method () {
	local	dialog_file=${dialog_radiolist}
	local	m=''
	local	desc=''

	cat <<EOM > ${dialog_file}
    --radiolist \\
    "wiping method" \\
    0 0 0 \\
EOM

	for m in `wiping_algorithm_method ""`
	do
		desc=`wiping_algorithm_description ${m}`
		echo -n " ${m} ${desc}" >> ${dialog_file}
		if [ "X${wiping_method}" != "X${m}" ]; then
			echo ' "off" \' >> ${dialog_file}
		else
			echo ' "on" \' >> ${dialog_file}
		fi
	done

	dialog --file ${dialog_file} 2> ${tmp_result}

	m=`cat ${tmp_result}`
	if isa_wiping_algorithm_method ${m} ; then
		wiping_method=${m}

		case `wiping_algorithm_option ${m}` in
		file)
			dialog --fselect "${wiping_scheme_file}" 0 0 2> ${tmp_result}
			wiping_method_option="-mf${wiping_scheme_file}"
			;;

		N-pass)
			dialog --inputbox "N-pass" 0 0 "${wiping_pass}" 2> ${tmp_result}
			case $? in
			0)
				wiping_pass=`cat ${tmp_result}`
				wiping_method_option="-m ${wiping_pass}"
				;;
			esac
			;;

		*)
			wiping_method_option="-m${m}"
			;;
		esac
	fi
}

menu_config () {
	local	result=0
	local	dialog_file=${dialog_menu}

	while : ;
	do
		cat <<EOM > ${dialog_file}
    --menu \\
    "environment values" \\
    0 0 0 \\
    "EXIT" "exit from system" \\
    "SHOW" "show environe values" \\
    "METHOD" "set wiping method" \\
EOM
		dialog --file ${dialog_file} 2> ${tmp_result}

		case `cat ${tmp_result}` in
		EXIT|"")
			result=1;
			break;
			;;

		SHOW)
			show_env_values;
			result=0;
			;;

		METHOD)
			menu_wiping_method;
			result=0;
			;;

		*)
			result=0;
			;;
		esac
	done

	return ${result}
}

system_disk_names () {
	sysctl -n kern.geom.conftxt | awk '{ if ($1 == 0 && $4 > 1) print $3 }' | sort
}

disk_names () {
	local disk=''
	local md=''
	local _d=''

	for disk in `system_disk_names`
	do
		_d=${disk}

		for md in `mdconfig -l`
		do
			if [ "X${disk}" != "X${md}" ]; then
				:
			else
				_d=''
			fi
		done

		if [ "X${_d}" != "X" ]; then
			echo ${_d}
		fi
	done
}

disk_desc () {
	sysctl -n kern.geom.conftxt | awk '{ if ($1 == 0 && $4 > 1 && $3 == "'$1'") print $0 }' | sort | sed -e 's/0 \([[:alnum:]]*\) \([[:alnum:]]*\)/\1/'
}

menu_wipe () {
	local	result=0
	local	dialog_file=${dialog_checklist}
	local	geom_list=''

	cat <<EOM > ${dialog_file}
    --checklist \\
    "wiping disks" \\
    0 0 0 \\
EOM

	for d in `disk_names`
	do
		echo -n " ${d} \"`disk_desc ${d}`\"" >> ${dialog_file}
		echo " \"off\" \\" >> ${dialog_file}
	done

	dialog --file ${dialog_file} 2> ${tmp_result}

	for disk in `cat ${tmp_result} | sed -e 's/\"//g'`
	do
		if isa_task_working ${disk} ; then
			bcwipe_stop ${disk}
		else
			bcwipe_start ${disk}
		fi
	done

	return ${result}
}

show_log () {
	local	disk=$1

	if [ -f ${taskdir}/${disk}.log ]; then
		dialog --tailbox ${taskdir}/${disk}.log 0 0
	else
		dialog --msgbox "no wiping task for ${disk}" 0 0
	fi
}

menu_view_log () {
	local	result=0
	local	dialog_file=${dialog_menu}
	local	geom_list=''

	cat <<EOM > ${dialog_file}
    --menu \\
    "wiping tasks" \\
    0 0 0 \\
EOM

	for d in `disk_names`
	do
		echo -n " ${d} \"`disk_desc ${d}`\" \\" >> ${dialog_file}
	done

	dialog --file ${dialog_file} 2> ${tmp_result}

	for disk in `cat ${tmp_result} | sed -e 's/\"//g'`
	do
		show_log ${disk}
	done

	return ${result}
}

view_tasks () {
	local	result=0
	local	dialog_file=${dialog_msgbox}
	local	tpid=''

	cat <<EOM > ${dialog_file}
    --msgbox \\
"
EOM

	for disk in `disk_names`
	do
		if isa_task_working "${disk}" ; then
			echo "${disk}: wiping" >> ${dialog_file}

			tpid=`cat ${taskdir}/${disk}.pid`
			ps axw | grep "^[ ]*${tpid} " | grep "${cmd_bcwipe}" >>  ${dialog_file}
		else
			echo "${disk}: no task" >> ${dialog_file}
		fi
	done

	cat <<EOM >> ${dialog_file}
"
    0 0 \\
EOM

	dialog --file ${dialog_file} 2> ${tmp_result}
}

menu_view () {
	local	result=0
	local	dialog_file=${dialog_menu}

	while : ;
	do
		cat <<EOM > ${dialog_file}
    --menu \\
    "main menu" \\
    0 0 0 \\
    "Exit" "Exit from system" \\
    "Task" "show tasks" \\
    "Log" "show task log" \\
EOM

		dialog --file ${dialog_file} 2> ${tmp_result}

		case `cat ${tmp_result}` in
		Exit|"")
			result=1;
			break;
			;;

		Task)
			view_tasks;
			result=0;
			;;

		Log)
			menu_view_log;
			result=0;
			;;

		*)
			result=0;
			;;
		esac

	done

	return ${result}
}

menu_top () {
	local	result=0
	local	dialog_file=${dialog_menu}

	while : ;
	do
		cat <<EOM > ${dialog_file}
    --no-cancel \\
    --menu \\
    "main menu" \\
    0 0 0 \\
    "Wipe" "wipe whole disk" \\
    "Config" "configuration" \\
    "View" "view values" \\
    "Shell" "exec external shell" \\
    "Reboot" "reboot system" \\
EOM

#    "Exit" "Exit from system" \\

		dialog --file ${dialog_file} 2> ${tmp_result}

		case `cat ${tmp_result}` in
		Exit)
			result=1;
			break;
			;;

		Config)
			menu_config;
			result=$?;
			;;

		Status)
			#menu_status;
			result=0;
			;;

		View)
			menu_view;
			result=0;
			;;

		Wipe)
			menu_wipe;
			result=0;
			;;

		Shell)
			menu_shell;
			result=0;
			;;

		Reboot)
			do_reboot;
			result=0;
			;;

		*)
			result=0;
			;;
		esac
	done

	return ${result}
}


##
# main
##

do_setup

menu_top

