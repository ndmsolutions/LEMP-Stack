# LEMP-Stack for Ubuntu 18.04 Tested on (DigitalOcean, Vultr, AWS)

LEMP-Stack is base TuxLite, this is new version modified to work only on Nginx (LEMP) and Ubuntu 18.04:

The following are installed:

* Nginx 1.14.0
* MySQL v5.7
* PHP 7.2.10-0ubuntu0.18.04.1 (cli) (built: Sep 13 2018 13:45:02) ( NTS )
* Postfix mail server (securely configured to be outgoing only)
* FTP Server
* PhpMyAdmin


New Features:

1. Add Database from CLI.
1. Add User For Domain and FTP access.
1. Add Automatic User after disabling root user for login.
1. Manage Swap Size
1. Manage Root Access

Installing:

```
#!shell

apt-get install git -y

```

Clone Repository

```
#!shell

git clone https://github.com/ndmsolutions/LEMP-Stack.git

```

CD to Directory and Change permission


```
#!shell

cd LEMP-Stack
chmod 700 *.sh
chmod 700 options.conf
```

Edit options to enter server IP, MySQL password, MySQL Version etc.

```
#!shell

nano options.conf
```

Install LAMP.

```
#!shell

./install.sh

```

When install is completed you will find user and password generated during install.


```
#!shell

cat info_install.txt
#### User with Sudo Access #####
User: sysadmin
Pass: 074VohJv9P6tx4hcFG8AzT2o
```

Install FTP and PhpMyAdmin

```
#!shell

./setup.sh ftp

./setup.sh dbgui
```
****************** AWS Ec2 *************************

Also for FTP if using on AWS Ec2 you need to open ports 

Port range 40000 - 40100

SERVER_IP from options.conf will be used for "pasv_address=$SERVER_IP"

****************** End AWS Ec2 **********************


Add User for Domain to be started.

```
#!shell

./add_domain_user.sh myuser

################# User Info ######################
The Account Is Setup
To Add Domain in this user use: ./domain.sh add myuser domain.com
To Remove Domain in this user use: ./domain.sh rem myuser domain.com
User: myuser
Pass: X9SEZu4ngaWzgnM7G0NgFsai
```

Add Domain to user we created.


```
#!shell

./domain.sh add myuser mydomain.com

php5.6-fpm stop/waiting
php5.6-fpm start/running, process 6726
Succesfully added "mydomain.com" to user "myuser" 
You can now upload your site to /home/myuser/domains/mydomain.com/public_html.
PhpMyAdmin is DISABLED by default. URL = http://mydomain.com/dbgui.
AWStats is ENABLED by default. URL = http://mydomain.com/stats.
Stats update daily. Allow 24H before viewing stats or you will be greeted with an error page.
```

Enable PhpMyAdmin if installed.

```
#!shell

./domain.sh dbgui on 

'/home/myuser/domains/mydomain.com/public_html/dbgui' -> '/usr/local/share/phpmyadmin/'
PhpMyAdmin enabled.
```

Disable PhpMyAdmin

```
#!shell

./domain.sh dbgui off

removed '/home/myuser/domains/mydomain.com/public_html/dbgui'
PhpMyAdmin disabled. If "removed" messages do not appear, it has been previously disabled.
```

Create MySQL User and Database.

```
#!shell

./database.sh add myusersql

 ################# DB Info ######################
 Database Added
 Host: localhost
 Port: 3306
 User: myusersql
 Pass: Ujtb8dC3O9dRhgmXe5rMCJUL
```

Drop MySQL User and Database.

```
#!shell

./database.sh drop myusersql

 ################# DB Info ######################
 Database Removed and User
 User: myusersql
```

Manage Swap Memory, added this to work on DigitalOcean as was Issue for low memory in 512MB you can change as per need Swap at options.conf:


```
#!shell

ADD_SWAP=yes
SWAP_SIZE=2G
```


Users wish SSL sites make sure you generate DHPARAM and not using existing one change this to options.conf from DHPARAM_SETUP=1 to DHPARAM_SETUP=2 this will take long time while install.
You can use DHPARAM_SETUP=1 only for testing server and destroy.

```
#!shell

#How to generate dhparam manually
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096
```

```
#!shell

DHPARAM_SETUP=2
```