#!/bin/bash

source ./options.conf

bold=$(tput bold)
normal=$(tput sgr0)
ROOT_UID=0
passgen=$(openssl rand -base64 18)

# Run as root, of course. (this might not be necessary, because we have to run the script somehow with root anyway)
if [ "$UID" -ne "$ROOT_UID" ]
then
  echo "Must be root to run this script."
  exit $E_NOTROOT
fi  

#test, if both argument are there
if [ $# -eq 2 ]; then

	dbname=$2
	pass=$passgen
	
	if [ "$1" == "drop" ]; then

		mysql -u root -p$MYSQL_ROOT_PASSWORD -e "REVOKE ALL PRIVILEGES, GRANT OPTION FROM '$dbname'@'localhost';DROP DATABASE IF EXISTS $dbname;DROP USER '$dbname'@'localhost';FLUSH PRIVILEGES;"
	    echo  " ################# DB Info ######################"
		echo  " ${bold}Database Removed and User"
		echo  " ${normal}User: $dbname"
		
	else

		mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $dbname; CREATE USER '$dbname'@'localhost' IDENTIFIED BY '$pass'; GRANT ALL PRIVILEGES ON $dbname.* TO '$dbname'@'localhost';FLUSH PRIVILEGES;"
		
	    echo  " ################# DB Info ######################"
		echo  " ${bold}Database Added"
		echo  " Database Name: $dbname"
		echo  " ${normal}Host: localhost"
		echo  " Port: 3306"
		echo  " User: $dbname"
		echo  " Pass: $pass"
	
	fi

else
        echo  " This programm needs 2 arguments you have given $# "
        echo  " You have to call the script $0 drop/add dbname"
fi

exit 0