#!/bin/bash

bold=$(tput bold)
normal=$(tput sgr0)
ROOT_UID=0
SUCCESS=0
E_USEREXISTS=70
passgen=$(openssl rand -base64 18)

# Run as root, of course. (this might not be necessary, because we have to run the script somehow with root anyway)
if [ "$UID" -ne "$ROOT_UID" ]
then
  echo "Must be root to run this script."
  exit $E_NOTROOT
fi  

#test, if both argument are there
if [ $# -eq 1 ]; then
username=$1
pass=$passgen

	# Check if user already exists.
	grep -q "$username" /etc/passwd
	if [ $? -eq $SUCCESS ] 
	then	
	echo "User $username does already exist."
  	echo "please chose another username."
	exit $E_USEREXISTS
	fi  

	adduser --disabled-password --gecos "" $username --shell=/bin/false
    echo "$username:$pass" | chpasswd
    echo  " ################# User Info ######################"
	echo  " The Account Is Setup, note: this user will not be able to access SSH will be using FTP on port 21"
	echo  " To Add Domain in this user use: ${bold}./domain.sh add $username domain.com"
	echo  " ${normal}To Remove Domain in this user use: ${bold}./domain.sh rem $username domain.com"
	echo  " ${normal}User: $username"
	echo  " Pass: $pass"

else
        echo  " This programm needs 1 arguments you have given $# "
        echo  " You have to call the script $0 username"
fi

exit 0