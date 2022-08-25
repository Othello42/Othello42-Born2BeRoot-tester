#! /bin/bash

# set Username, will stop script from asking for it.
USERNAME=""
FILE="debian_test.sh"

# =====================================||===================================== #
#																			   #
#							 Managing passed flags							   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
for FLAG in "$@"; do
	case "$FLAG" in
		help|-h|--help)
			ACTION=${ACTION:-help};;
		test|-t|--test)
			ACTION=${ACTION:-test};;
		copy|-c|--copy)
			ACTION=${ACTION:-copy};;
		nocolor|--nocolor)
			COLOR=${COLOR:-nocolor};;
		color|--color)
			COLOR=${COLOR:-color};;
		*)
			USERNAME=${USERNAME:-$FLAG};
			if [ "$USERNAME" != "$FLAG" ]; then
				ACTION=error;
				ERROR=${ERROR:-$FLAG};
				break;
			fi;			
	esac
done

COLOR=${COLOR:-color};
ACTION=${ACTION:-test};

# =====================================||===================================== #
#																			   #
#									Functions								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_head()
{
	NAME="$1"
	
	printf	$C_RESET"\t"
	printf	"\x1b[48;2;85;85;85m "
	printf	"\x1b[48;2;139;139;139m "
	printf	"\x1b[48;2;192;192;192m "
	printf	"\x1b[48;2;255;128;0m "
	printf	"\x1b[1m\x1b[38;2;0;0;0m "
	printf	"Othello's $NAME Tester "
	printf	$C_RESET"\n"
}

print_subhead()
{
	NAME="$1"

	printf	"\n\t"
	printf	"\x1b[48;2;85;85;85m "
	printf	"\x1b[48;2;139;139;139m "
	printf	"\x1b[48;2;192;192;192m "
	printf	"\x1b[1m\x1b[38;2;0;0;0m"
	printf	"$NAME "
	printf	$C_RESET
}

print_test_name()
{
	NAME="$1"

	printf	"\n"$C_BOLD"%-16.16s"$C_RESET	"$NAME"
}

print_to_errorlog()
{
	CHECK="$1";
	COMMAND="$2";
	ERRORMSG="$3";

	printf	"\nTest error" >> $ERRORLOG;
	if [ -n "$CHECK" ]; then
		printf	" (type $CHECK)" >> $ERRORLOG;
	fi
	printf	"\n" >> $ERRORLOG
	if [ -n "$COMMAND" ]; then
		printf	"\t$COMMAND\n" >> $ERRORLOG;
	fi
	if [ -n "$ERRORMSG" ]; then
		printf	"\t$ERRORMSG\n" >> $ERRORLOG;
	fi
}

check_ok()
{
	CHECK="$1";
	COMMAND="$2";
	ERRORMSG="$3";
	PACKAGE="$4";

	if [ -n "$CHECK" ]; then
		if [ $CHECK -eq 1 ]; then
			printf	$C_OK"[OK]"$C_RESET"\t";
		elif [ $CHECK -eq 0 ] && [ "$PACKAGE" == "true" ]; then
			printf	$C_RED"[PACKAGE NOT FOUND]"$C_RESET"\t";
			print_to_errorlog	"$CHECK"	"$COMMAND"	"$ERRORMSG";
		elif [ $CHECK -eq 0 ]; then
			printf	$C_RED"[KO]"$C_RESET"\t";
			print_to_errorlog	"$CHECK"	"$COMMAND"	"$ERRORMSG";
		elif [ $CHECK -gt 1 ]; then
			printf	$C_YELLOW"[OK]"$C_RESET"\t";
			print_to_errorlog	"$CHECK"	"$COMMAND"	"Unexpect return value, might be okay.";
		elif [ $CHECK -lt 0 ]; then
			printf	$C_ORANGE"[KO]"$C_RESET"\t";
			print_to_errorlog	"$CHECK"	"$COMMAND"	"Unexpect return value, it seems wrong.";
		fi
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t";
	fi
	unset ERRORMSG;
	unset PACKAGE;
}

check_install()
{
	PACK="$1";
	INSTALL="$2";

	dpkg -s $PACK &> /dev/null;
	if [ $? -eq 0 ]; then
		if [ "$INSTALL" == "true" ]; then
			VALUE=$(dpkg -s $PACK | grep -w Status: | grep -w install | wc -l);
			if [ $VALUE -eq 1 ]; then
				CHECK=1;
			elif [ $VALUE -eq 0 ]; then
				CHECK=0;
			else
				CHECK=2;
			fi
		elif [ "$INSTALL" == "false" ]; then
			VALUE=$(dpkg -s $PACK | grep -w Status: | wc -l);
			if [ $VALUE -eq 0 ]; then
				CHECK=1;
			elif [ $VALUE -eq 1 ]; then
				CHECK=0;
			else
				CHECK=-1;
			fi
		fi
	else
		if [ "$INSTALL" == "true" ]; then
			CHECK=0;
		elif [ "$INSTALL" == "false" ]; then
			CHECK=1;
		fi
	fi
	COMMAND="dpkg -s $PACK | grep -w Status:"
	ERRORMSG="Incorrect install status for $PACK"
	check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"	"true"
	unset PACK;
	unset INSTALL;
	unset VALUE;
}

check_service_active()
{
	SERVICE="$1";

	service "$SERVICE" status &> /dev/null
	if [[ $? -eq 0 || $? -eq 3 ]]; then
		COMMAND="service $SERVICE status";
		CHECK=$(service $SERVICE status | grep -w "Active:" | grep -w "active" | wc -l);
		CHECK=1;
		ERRORMSG="Service $SERVICE is not properly activated."
		check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"
	else
		printf	$C_RED"[SERVICE NOT FOUND]"$C_RESET"\t";
	fi
}

check_for_line()
{
	FILE="$1";
	LINE="$2";
	VALUE="$3";

	CHECK=$(grep "^$LINE" $FILE | grep -w "$VALUE" | wc -l)
	if [ $CHECK -ge 1 ]; then
		CHECK=1;
	fi
	ERRORMSG="Did not find value '$VALUE' in line(s) '$LINE'."
	check_ok	"$CHECK"	"grep \"^$LINE\" $FILE"	"$ERRORMSG"
}

check_for_unique_line()
{
	FILE="$1";
	LINE="$2";
	VALUE="$3";

	CHECK=$(grep "^$LINE" $FILE | wc -l)
	if [ $CHECK -eq 0 ]; then
		printf	$C_RED"[KO]"$C_RESET"\t";
		print_to_errorlog	""	"$FILE"	"Line '$LINE' not found.";
	elif [ $CHECK -eq 1 ]; then
		CHECK=$(grep "^$LINE" $FILE | grep -w "$VALUE" | wc -l);
		ERRORMSG="$(grep "^$LINE" $FILE) contains a wrong value. Expected '$VALUE'.";
		check_ok	"$CHECK"	"$FILE"	"$ERRORMSG"
	else
		printf	$C_RED"[KO]"$C_RESET"\t";
		print_to_errorlog	""	"$FILE"	"To many occurences of line '$LINE' found.";
	fi
}

check_chage()
{
	NAME="$1";

	unset CHECK;
	VALUE=$(chage -l $NAME | grep -w Minimum | awk '{printf	$NF}');
	if [ $VALUE -ne 2 ]; then
		CHECK=0;
	fi
	VALUE=$(chage -l $NAME | grep -w Maximum | awk '{printf	$NF}');
	if [ $VALUE -ne 30 ]; then
		CHECK=0;
	fi
	VALUE=$(chage -l $NAME | grep -w warning | awk '{printf	$NF}');
	if [ $VALUE -ne 7 ]; then
		CHECK=0;
	fi
	CHECK=${CHECK:-1};
	check_ok	"$CHECK"	"chage -l $NAME"	"chage contained wrong settings for user $NAME."
}

set_colors()
{
	C_RESET="\x1b[0m"
# =====================================||===================================== #
#									 Styles									   #
# ================colors===============||==============©Othello=============== #
	C_BOLD="\x1b[1m"
	C_WEAK="\x1b[2m"
	C_CURS="\x1b[3m"
	C_UNDL="\x1b[4m"
	C_BLNK="\x1b[5m"
	C_REV="\x1b[7m"
	C_HIDDEN="\x1b[8m"
# =====================================||===================================== #
#								  Font Colors								   #
# ================colors===============||==============©Othello=============== #
	C_WHITE="\x1b[38;2;255;255;255m"
	C_LGRAY="\x1b[38;2;192;192;192m"
	C_GRAY="\x1b[38;2;128;128;128m"
	C_DGRAY="\x1b[38;2;64;64;64m"
	C_BLACK="\x1b[38;2;0;0;0m"
	C_LRED="\x1b[38;2;255;128;128m"
	C_RED="\x1b[38;2;255;0;0m"
	C_DRED="\x1b[38;2;128;0;0m"
	C_LORANGE="\x1b[38;2;255;192;128m"
	C_ORANGE="\x1b[38;2;255;128;0m"
	C_DORANGE="\x1b[38;2;128;64;0m"
	C_LYELLOW="\x1b[38;2;255;255;128m"
	C_YELLOW="\x1b[38;2;255;255;0m"
	C_DYELLOW="\x1b[38;2;128;128;0m"
	C_LCHRT="\x1b[38;2;192;255;128m"
	C_CHRT="\x1b[38;2;128;255;0m"	#chartreuse
	C_DCHRT="\x1b[38;2;64;128;0m"
	C_LGREEN="\x1b[38;2;128;255;128m"
	C_GREEN="\x1b[38;2;0;255;0m"
	C_DGREEN="\x1b[38;2;0;128;0m"
	C_LSPRGR="\x1b[38;2;128;255;192m"
	C_SPRGR="\x1b[38;2;0;255;128m"	#spring green
	C_DSPRGR="\x1b[38;2;0;128;64m"
	C_LCYAN="\x1b[38;2;128;255;255m"
	C_CYAN="\x1b[38;2;0;255;255m"
	C_DCYAN="\x1b[38;2;0;128;128m"
	C_LAZURE="\x1b[38;2;0;192;255m"
	C_AZURE="\x1b[38;2;0;128;255m"
	C_DAZURE="\x1b[38;2;0;64;128m"
	C_LBLUE="\x1b[38;2;128;128;255m"
	C_BLUE="\x1b[38;2;0;0;255m"
	C_DBLUE="\x1b[38;2;0;0;128m"
	C_LVIOLET="\x1b[38;2;192;0;255m"
	C_VIOLET="\x1b[38;2;128;0;255m"
	C_DVIOLET="\x1b[38;2;64;0;255m"
	C_LMGNT="\x1b[38;2;255;128;255m"
	C_MGNT="\x1b[38;2;255;0;255m"	#magenta
	C_DMGNT="\x1b[38;2;128;0;128m"
	C_LROSE="\x1b[38;2;255;128;192m"
	C_ROSE="\x1b[38;2;255;0;128m"
	C_DROSE="\x1b[38;2;128;0;64m"
	C_LBROWN="\x1b[38;2;192;144;96m"
	C_BROWN="\x1b[38;2;128;64;0m" #hue 30
	C_DBROWN="\x1b[38;2;64;32;0m"
	C_LPURPLE="\x1b[38;2;192;96;192m"
	C_PURPLE="\x1b[38;2;128;0;128m" #hue 300
	C_DPURPLE="\x1b[38;2;64;0;64m"
	C_LPINK="\x1b[38;2;255;224;229m"
	C_PINK="\x1b[38;2;255;192;203m" #hue 350
	C_DPINK="\x1b[38;2;128;48;62m"
	C_BRONZE="\x1b[38;2;205;127;50m"
	C_SILVER="\x1b[38;2;192;192;192m"
	C_GOLD="\x1b[38;2;255;215;0m"
# =====================================||===================================== #
#							   Background Colors							   #
# ================colors===============||==============©Othello=============== #
	CB_WHITE="\x1b[48;2;255;255;255m"
	CB_LGRAY="\x1b[48;2;192;192;192m"
	CB_GRAY="\x1b[48;2;128;128;128m"
	CB_DGRAY="\x1b[48;2;64;64;64m"
	CB_BLACK="\x1b[48;2;0;0;0m"
	CB_LRED="\x1b[48;2;255;128;128m"
	CB_RED="\x1b[48;2;255;0;0m"
	CB_DRED="\x1b[48;2;128;0;0m"
	CB_LORANGE="\x1b[48;2;255;192;128m"
	CB_ORANGE="\x1b[48;2;255;128;0m"
	CB_DORANGE="\x1b[48;2;128;64;0m"
	CB_LYELLOW="\x1b[48;2;255;255;128m"
	CB_YELLOW="\x1b[48;2;255;255;0m"
	CB_DYELLOW="\x1b[48;2;128;128;0m"
	CB_LCHRT="\x1b[48;2;192;255;128m"
	CB_CHRT="\x1b[48;2;128;255;0m" #chartreuse
	CB_DCHRT="\x1b[48;2;64;128;0m"
	CB_LGREEN="\x1b[48;2;128;255;128m"
	CB_GREEN="\x1b[48;2;0;255;0m"
	CB_DGREEN="\x1b[48;2;0;128;0m"
	CB_LSPRGR="\x1b[48;2;128;255;192m"
	CB_SPRGR="\x1b[48;2;0;255;128m"	#spring green
	CB_DSPRGR="\x1b[48;2;0;128;64m"
	CB_LCYAN="\x1b[48;2;128;255;255m"
	CB_CYAN="\x1b[48;2;0;255;255m"
	CB_DCYAN="\x1b[48;2;0;128;128m"
	CB_LAZURE="\x1b[48;2;0;192;255m"
	CB_AZURE="\x1b[48;2;0;128;255m"
	CB_DAZURE="\x1b[48;2;0;64;128m"
	CB_LBLUE="\x1b[48;2;128;128;255m"
	CB_BLUE="\x1b[48;2;0;0;255m"
	CB_DBLUE="\x1b[48;2;0;0;128m"
	CB_LVIOLET="\x1b[48;2;192;0;255m"
	CB_VIOLET="\x1b[48;2;128;0;255m"
	CB_DVIOLET="\x1b[48;2;64;0;255m"
	CB_LMGNT="\x1b[48;2;255;128;255m"
	CB_MGNT="\x1b[48;2;255;0;255m"	#magenta
	CB_DMGNT="\x1b[48;2;128;0;128m"
	CB_LROSE="\x1b[48;2;255;128;192m"
	CB_ROSE="\x1b[48;2;255;0;128m"
	CB_DROSE="\x1b[48;2;128;0;64m"
	CB_LBROWN="\x1b[48;2;192;144;96m"
	CB_BROWN="\x1b[48;2;128;64;0m" #hue 30
	CB_DBROWN="\x1b[48;2;64;32;0m"
	CB_LPURPLE="\x1b[48;2;192;96;192m"
	CB_PURPLE="\x1b[48;2;128;0;128m" #hue 300
	CB_DPURPLE="\x1b[48;2;64;0;64m"
	CB_LPINK="\x1b[48;2;255;224;229m"
	CB_PINK="\x1b[48;2;255;192;203m" #hue 350
	CB_DPINK="\x1b[48;2;128;48;62m"
	CB_BRONZE="\x1b[48;2;205;127;50m"
	CB_SILVER="\x1b[48;2;192;192;192m"
	CB_GOLD="\x1b[48;2;255;215;0m"
# =====================================||===================================== #
#								  Miscelaneous								   #
# ================colors===============||==============©Othello=============== #
	C_HEADER="\x1b[48;2;85;85;85m \x1b[48;2;139;139;139m \
	\x1b[48;2;192;192;192m \x1b[48;2;255;128;0m \x1b[1m\x1b[38;2;0;0;0m"
	C_SUBHEAD="\x1b[48;2;85;85;85m \x1b[48;2;139;139;139m \
	\x1b[48;2;192;192;192m \x1b[1m\x1b[38;2;0;0;0m"
	C_OK="\x1b[38;2;16;223;16m"
}

# =====================================||===================================== #
#																			   #
#						 Managing passed flags (cont.)						   #
#							   Setting up colors							   #
#							 	Errors and help								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
if [ "$COLOR" == "color" ]; then
	set_colors;
	C_HEADER=$CB_ORANGE$C_BLACK$C_BOLD
fi

printf	$C_RESET

if [ "$ACTION" == "error" ]; then
	printf	$C_RED"Bad flag "$C_YELLOW"$ERROR"$C_RED" passed.";
	printf	"Try "$C_YELLOW"--help"$C_RED"."$C_RESET"\n";
	printf	$C_RESET"\n";
	exit;
fi

if [ "$ACTION" == "help" ]; then
	printf	$C_HEADER"%-66.66s"$C_RESET"\n"	"Othello42's Born2BeRoot tester";
	printf	$C_YELLOW"%2.2s %-9s"$C_RESET"\t%s.\n"	"-t"	"--test"	"Tests script from Hypervisor";
	printf	$C_YELLOW"%2.2s %-9s"$C_RESET"\t%s.\n"	"-c"	"--copy"	"Copies script from Hypervisor to the Virtual Machine";
	printf	$C_RESET"\n";
	exit;
fi

if [ -z "$USERNAME" ]; then
	printf	"Please enter Username: "
	read -r USERNAME;
	printf	$C_ORANGE"You can edit the script to stop requesting the username"$C_RESET"\n"

fi

ERRORLOG="/home/$USERNAME/errorlog.txt";

# =====================================||===================================== #
#																			   #
#							   Location & Copying							   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
if [ "$(uname)" == "Linux" ]; then
	if [ "$(hostnamectl | grep -w Chassis: | grep -w vm)" ]; then
		LOCATION="virtual machine";
	fi
fi
LOCATION=${LOCATION:-hypervisor}

if [ "$ACTION" == "copy" ]; then
	if [ "$LOCATION" == "virtual machine" ]; then
		printf	$C_RED"Trying to copy from the "$C_YELLOW"virtual machine"$C_RED"."$C_RESET"\n"
		exit;
	fi
	printf	$C_DGREEN"Copying tester..."$C_RESET"\n"
	scp -P 4242 -r ./"$FILE" "$USERNAME"@localhost:/home/"$USERNAME"/"$FILE"
	if [ $? -eq 0 ]; then
		printf	$C_DGREEN"Tester has been copied to "$C_RESET"/home/$USERNAME/$FILE\n"
	else
		printf	$C_RED"Tester failed to copy."$C_RESET"\n"
	fi
	exit;
fi

# =====================================||===================================== #
#																			   #
#						Test activation from Hypervisor						   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
if [ "$LOCATION" == "hypervisor" ]; then
	FILE=$(find . -name debian_test.sh)
	printf	$C_DGREEN"Running tester through ssh..."$C_RESET"\n"
	ssh -p4242 "$USERNAME"@localhost 'export TERM=xterm-256color; bash -s' "$USERNAME" "$COLOR" < "$FILE";
	if [ $? -ne 0 ]; then
		printf	$C_RED"Tester failed to run."$C_RESET"\n"
	fi
	exit;
fi

# =====================================||===================================== #
#																			   #
# =====================================||===================================== #
#																			   #
#									  Tests									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
#									  Frame									   #
# =====================================||===================================== #
printf	"Othello42's Born2BeRoot tester\n" > $ERRORLOG;
date >> $ERRORLOG

printf	$C_RESET"\n"
print_head	"Born2BeRoot"
printf	"Designed for Debian\n"
print_subhead	"Legend"
printf	"\n"
printf	$C_OK"[OK]"$C_RESET"\tTest checks out.\n"
printf	$C_YELLOW"[OK]"$C_RESET"\tTest probably checks out, but requires checking.\n"
printf	$C_ORANGE"[KO]"$C_RESET"\tTest might have failed, but requires checking.\n"
printf	$C_RED"[KO]"$C_RESET"\tTest Failed on basic functionallity."$C_RESET"\n"
printf	$C_GRAY"[KO]"$C_RESET"\tTest failed to execute."$C_RESET"\n"

# =====================================||===================================== #
#																			   #
#								   Mandatory								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_subhead	"Mandatory part"

# =====================================||===================================== #
#																			   #
#								 Users & Groups								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"User & Group"

COMMAND="getent group {1000..60000} | cut -d: -f1 | grep -x $USERNAME | wc -l";
CHECK=$(getent group {1000..60000} | cut -d: -f1 | grep -x $USERNAME | wc -l);
ERRORMSG="Username '$USERNAME' not found.";
check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"

GROUP="sudo"
COMMAND="groups $USERNAME | cut -d: -f2 | grep -w $GROUP | wc -l";
CHECK=$(groups $USERNAME | cut -d: -f2 | grep -w $GROUP | wc -l);
ERRORMSG="$USERNAME does not appear to be part of group '$GROUP'";
check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"

GROUP="user42"
COMMAND="groups $USERNAME | cut -d: -f2 | grep -w $GROUP | wc -l";
CHECK=$(groups $USERNAME | cut -d: -f2 | grep -w $GROUP | wc -l);
ERRORMSG="$USERNAME does not appear to be part of group '$GROUP'";
check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"

# =====================================||===================================== #
#																			   #
#									Password								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"Password"

check_install	"libpam-pwquality"	"true";
if [ $CHECK -ge 1 ]; then
	check_chage	"$USERNAME"

	if [ $(whoami) == "root" ]; then
		check_chage	"root";
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t";
	fi

	FILE="/etc/login.defs"
	if [ -f $FILE ]; then
		LINE="PASS_MIN_DAYS	"
		VALUE="2"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="PASS_MAX_DAYS	"
		VALUE="30"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="PASS_WARN_AGE	"
		VALUE="7"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";
	else
		printf	$C_RED"[FILE NOT FOUND]"$C_RESET"\t";
	fi

	printf	"\n%-16.16s"	""

	FILE="/etc/security/pwquality.conf"
	if [ -f $FILE ]; then
		LINE="difok = "
		VALUE="7"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="minlen = "
		VALUE="10"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="dcredit = "
		VALUE="\\-1"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="ucredit = "
		VALUE="\\-1"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="lcredit = "
		VALUE="\\-1"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="maxrepeat = "
		VALUE="3"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="usercheck = "
		VALUE="1"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="enforce_for_root"
		VALUE="enforce_for_root"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";
	else
		printf	$C_RED"[FILE NOT FOUND]"$C_RESET"\t";
	fi
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#									Hostname								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"Hostname"

COMMAND="hostname";
NAME=$(hostname)
CHECK=$(echo $NAME | grep -x "$USERNAME"42 | wc -l);
ERRORMSG="Wrong hostname '$NAME' found. Expected '"$USERNAME"42'.";
check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG";

COMMAND="hostnamectl | grep \"Static hostname:\"";
NAME=$(hostnamectl | grep "Static hostname:" | awk '{printf	$NF}')
CHECK=$(echo $NAME | grep -w "$USERNAME"42 | wc -l);
ERRORMSG="Wrong static hostname '$NAME' found. Expected '"$USERNAME"42'.";
check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG";

# =====================================||===================================== #
#																			   #
#									  Sudo									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"Sudo"

check_install	"sudo"	"true";
if [ $CHECK -ge 1 ]; then
	DIR="/var/log/sudo"
	COMMAND="ls -l $DIR";
	CHECK=0;
	if [ -d "$DIR" ]; then
		if [ $( ls -l $DIR | grep -v '^d' | wc -l) -ge 1 ]; then
			CHECK=1;
		fi
		ERRORMSG="No potential log for sudo found.";
	else
		ERRORMSG"Directory '$DIR' not found."
	fi
	check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG";

	if [ $(whoami) == "root" ]; then
		FILE="/etc/sudoers"

		printf	"\n%-16.16s"	""

		LINE="Defaults	passwd_tries"
		VALUE="3"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="Defaults	badpass_message"
		VALUE=""
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="Defaults	logfile"
		VALUE="/var/log/sudo/*"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="Defaults	log_.*"
		VALUE="log_input"
		check_for_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="Defaults	log_.*"
		VALUE="log_output"
		check_for_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="Defaults	requiretty"
		VALUE="requiretty"
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";

		LINE="Defaults	secure_path"
		VALUE=""
		check_for_unique_line	"$FILE"	"$LINE"	"$VALUE";
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t"
	fi
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#									   UFW									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"UFW"
SERVICE="ufw"

check_install	"ufw"	"true"
if [ $CHECK -ge 1 ]; then
	if [ $(whoami) == "root" ]; then
		check_service_active	"$SERVICE"

		COMMAND="$SERVICE status";
		CHECK=$($SERVICE status | grep "Status:" | grep -w "active" | wc -l);
		ERRORMSG="ufw is inactive";
		check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"

		COMMAND="$SERVICE status | grep -w 4242";
		CHECK=$(ufw status | grep -w 4242 | wc -l);
		if [ $CHECK -eq 2 ]; then
			CHECK=1;
		fi
		ERRORMSG="No ufw port 4242 found.";
		check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t"
	fi
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#									   SSH									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"SSH"
SERVICE="ssh";

check_install	"openssh-server"	"true"
if [ $CHECK -ge 1 ]; then
	if [ $(whoami) == "root" ]; then
		check_service_active	"$SERVICE"
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t"
	fi

	FILE="/etc/ssh/sshd_config"

	LINE="Port"
	VALUE="4242"
	check_for_line	"$FILE"	"$LINE"	"$VALUE";

	LINE="PermitRootLogin"
	VALUE="no"
	check_for_line	"$FILE"	"$LINE"	"$VALUE";
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#									  Cron									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"Cron"
SERVICE="cron";

check_install	"cron"	"true"
if [ $CHECK -ge 1 ]; then
	if [ $(whoami) == "root" ]; then
		check_service_active	"$SERVICE";

		FILE="/var/spool/cron/crontabs/root"
		LINE="\*/10 \* \* \* \*"
		VALUE="monitoring.sh"
		check_for_line	"$FILE"	"$LINE"	"$VALUE";
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t"
	fi
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#									  Bonus									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_subhead	"Bonus part"

# =====================================||===================================== #
#																			   #
#								   WordPress								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"WordPress"

CHECK=0
if [ $(whoami) == "root" ]; then
	COMMAND="find / -iname wp-config.php"
	CHECK=$(find / -iname wp-config.php | wc -l);
else
	COMMAND="WordPress (/var/www/html/)"
	if [ -d /var/www/html ]; then
		if [ -f /var/www/html/wp-config.php ]; then
			CHECK=1;
		else
			CHECK=-1;
		fi
	fi
fi
ERRORMSG="WordPress configuration file (wp-config.php) not found."
check_ok	"$CHECK"	"$COMMAND"	"$ERRORMSG"

# =====================================||===================================== #
#																			   #
#									Lighttpd								   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"lighttpd"
SERVICE="lighttpd";

check_install	"lighttpd"	"true"
if [ $CHECK -ge 1 ]; then
	if [ $(whoami) == "root" ]; then
		check_service_active	"$SERVICE";
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t"
	fi
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#									MariaDB									   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"MariaDB"
SERVICE="mariadb";

check_install	"mariadb-server"	"true"
if [ $CHECK -ge 1 ]; then
	if [ $(whoami) == "root" ]; then
		check_service_active	"$SERVICE";
	else
		printf	$C_GRAY"[KO]"$C_RESET"\t"
	fi
else
	printf	$C_GRAY"[KO]"$C_RESET"\t";
fi

# =====================================||===================================== #
#																			   #
#							   Forbidden Packages							   #
#																			   #
# =============Born2BeRoot=============||==============©Othello=============== #
print_test_name	"Forbidden"

check_install	"apache2"	"false";

check_install	"nginx"	"false";

# =====================================||===================================== #
# =============Born2BeRoot=============||==============©Othello=============== #
printf	"\n"
print_subhead	"Notes"
printf	"\n"
NAME=$(whoami)
if [ "$NAME" != "root" ]; then
	printf	"For complete tests, run tester on "$C_BLUE"virtual machine"$C_RESET" as "$C_BLUE"root"$C_RESET"\n"
	printf	"\tCurrently ran as "$C_BLUE"$(whoami)"$C_RESET"\n"
	printf	"\t$> bash debian_test.sh --copy\n"
fi
printf	"Read "$C_BLUE"$ERRORLOG"$C_RESET" for more information.\n"
printf	"There are different methods to do Born2BeRoot.\n"
printf	"\tThis might lead to "$C_ORANGE"false negative"$C_RESET" results\n"

printf	$C_RESET"\n\n"
