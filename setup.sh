###############################################################################################
# LEMP Stack - Complete LEMP setup script for Ubuntu                                            #
# Nginx + PHP7.2-FPM + MySQL                                                             #
# Stack is optimized/tuned for a 256MB server                                                 #
###############################################################################################

source ./options.conf

# Detect distribution Ubuntu
DISTRO=`lsb_release -i -s`
# Distribution's release. precise etc
RELEASE=`lsb_release -c -s`
if  [ $DISTRO = "" ]; then
    echo -e "\033[35;1mPlease run 'aptitude -y install lsb-release' before using this script.\033[0m"
    exit 1
fi

#### Functions Begin ####

function basic_server_setup {
    
    if [ $ADD_SWAP = 'yes' ]; then
        fallocate -l $SWAP_SIZE /swapfile
        fallocate -l 1G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        free -h
    fi

    aptitude update && aptitude -y safe-upgrade
    
    # Reconfigure sshd - change port and disable root login
    sed -i 's/^Port [0-9]*/Port '${SSHD_PORT}'/' /etc/ssh/sshd_config
    if [ $DISABLE_ROOT_LOGIN = 'yes' ]; then
        sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    fi
    service ssh reload

    # Set hostname and FQDN
    sed -i 's/'${SERVER_IP}'.*/'${SERVER_IP}' '${HOSTNAME_FQDN}' '${HOSTNAME}'/' /etc/hosts
    echo "$HOSTNAME" > /etc/hostname

    # Ubuntu system, use hostname
    service hostname start

    # Basic hardening of sysctl.conf
    sed -i 's/^#net.ipv4.conf.all.accept_source_route = 0/net.ipv4.conf.all.accept_source_route = 0/' /etc/sysctl.conf
    sed -i 's/^net.ipv4.conf.all.accept_source_route = 1/net.ipv4.conf.all.accept_source_route = 0/' /etc/sysctl.conf
    sed -i 's/^#net.ipv6.conf.all.accept_source_route = 0/net.ipv6.conf.all.accept_source_route = 0/' /etc/sysctl.conf
    sed -i 's/^net.ipv6.conf.all.accept_source_route = 1/net.ipv6.conf.all.accept_source_route = 0/' /etc/sysctl.conf

    echo -e "\033[35;1m Root login disabled, SSH port set to $SSHD_PORT. Hostname set to $HOSTNAME and FQDN to $HOSTNAME_FQDN. \033[0m"
    echo -e "\033[35;1m Remember to create a normal user account for login or you will be locked out from your box! \033[0m"

    passgen=$(openssl rand -base64 18)
    user=$SUDO_USER
    
    useradd -m $user
    echo "$user:$passgen" | chpasswd
    
    echo "###### System Users for LEMP ######" >> /etc/sudoers
    echo "$user    ALL=(ALL) PASSWD: ALL" >> /etc/sudoers

    echo "#### User with Sudo Access #####" >> info_install.txt
    echo "User: $user" >> info_install.txt
    echo "Pass: $passgen" >> info_install.txt

} # End function basic_server_setup

function install_webserver {

    service apache2 stop
    update-rc.d -f apache2 remove
    apt-get remove apache2 nginx php* -y
    apt-get -y install nginx

    service nginx start
    
    apt autoremove -y

} # End function install_webserver

function install_php {
    
    # Install PHP packages and extensions specified in options.conf
    aptitude -y install $PHP_BASE
    aptitude -y install $PHP_EXTRAS
	
	apt autoremove -y

} # End function install_php

function install_extras {

    # Install any other packages specified in options.conf
    aptitude -y install $MISC_PACKAGES
    
    apt autoremove -y

} # End function install_extras

function install_ftp {
    
        echo "Installing FTP Server:"
        
        apt-get install vsftpd -y
        
        echo "Configure FTP Server:"
        
        sed -i 's/^#write_enable.*/write_enable=YES/' /etc/vsftpd.conf
        
        sed -i 's/^#local_umask.*/local_umask=022/' /etc/vsftpd.conf
        
        sed -i 's/^#chroot_local_user.*/chroot_local_user=YES/' /etc/vsftpd.conf
        
        sed -i '/pam_shells.so/s/^/#/g' /etc/pam.d/vsftpd
        
        echo 'allow_writeable_chroot=YES' >> /etc/vsftpd.conf
        echo 'pasv_enable=Yes' >> /etc/vsftpd.conf
        echo 'pasv_min_port=40000' >> /etc/vsftpd.conf
        echo 'pasv_max_port=40100' >> /etc/vsftpd.conf
        echo "pasv_address=$SERVER_IP" >> /etc/vsftpd.conf
        echo 'tcp_wrappers=YES' >> /etc/vsftpd.conf
        echo 'check_shell=NO' >> /etc/vsftpd.conf
        
        service vsftpd restart
        
        echo "FTP Server Installed"
        echo "Please add a user with no login for FTP using the cli: \"./add_domain_user.sh username\" command."
        
        apt autoremove -y
        
} # End Installation FTP Server

function install_mysql {
        
export DEBIAN_FRONTEND=noninteractive

# Install MySQL
debconf-set-selections <<< "mysql-server-5.7 mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server-5.7 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
apt-get -qq install mysql-server > /dev/null # Install MySQL quietly

# Install Expect
apt-get -qq install expect > /dev/null

# Build Expect script
tee ./secure_mysql.sh > /dev/null << EOF
spawn $(which mysql_secure_installation)

expect "Enter password for user root:"
send "$MYSQL_ROOT_PASSWORD\r"

expect "Press y|Y for Yes, any other key for No:"
send "y\r"

expect "Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:"
send "2\r"

expect "Change the password for root ? ((Press y|Y for Yes, any other key for No) :"
send "n\r"

expect "Remove anonymous users? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Disallow root login remotely? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Remove test database and access to it? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Reload privilege tables now? (Press y|Y for Yes, any other key for No) :"
send "y\r"

EOF

# Run Expect script.
# This runs the "mysql_secure_installation" script which removes insecure defaults.
expect ./secure_mysql.sh

# Cleanup
rm -v ./secure_mysql.sh # Remove the generated Expect script

apt-get -qq purge expect > /dev/null # Uninstall Expect, commented out in case you need Expect

echo "MySQL setup completed. Insecure defaults are gone. Please remove this script manually when you are done with it (or at least remove the MySQL root password that you put inside it."

apt autoremove -y

} # End function install_mysql

function optimize_stack {
    
    # Change logrotate for nginx log files to keep 10 days worth of logs
    nginx_file=`find /etc/logrotate.d/ -maxdepth 1 -name "nginx*"`
    sed -i 's/\trotate .*/\trotate 10/' $nginx_file
    
    cat ./config/nginx.conf > /etc/nginx/nginx.conf

    /etc/init.d/php7.2-fpm stop
    php_fpm_conf="/etc/php/7.2/fpm/pool.d/www.conf"
    # Limit FPM processes
    sed -i 's/^pm.max_children.*/pm.max_children = '${FPM_MAX_CHILDREN}'/' $php_fpm_conf
    sed -i 's/^pm.start_servers.*/pm.start_servers = '${FPM_START_SERVERS}'/' $php_fpm_conf
    sed -i 's/^pm.min_spare_servers.*/pm.min_spare_servers = '${FPM_MIN_SPARE_SERVERS}'/' $php_fpm_conf
    sed -i 's/^pm.max_spare_servers.*/pm.max_spare_servers = '${FPM_MAX_SPARE_SERVERS}'/' $php_fpm_conf
    sed -i 's/\;pm.max_requests.*/pm.max_requests = '${FPM_MAX_REQUESTS}'/' $php_fpm_conf
    # Change to socket connection for better performance
    sed -i 's/^listen =.*/listen = \/var\/run\/php\/php7.2-fpm.sock/' $php_fpm_conf

    php_ini_dir="/etc/php/7.2/fpm/php.ini"
    # Tweak php.ini based on input in options.conf
    sed -i 's/^max_execution_time.*/max_execution_time = '${PHP_MAX_EXECUTION_TIME}'/' $php_ini_dir
    sed -i 's/^memory_limit.*/memory_limit = '${PHP_MEMORY_LIMIT}'/' $php_ini_dir
    sed -i 's/^max_input_time.*/max_input_time = '${PHP_MAX_INPUT_TIME}'/' $php_ini_dir
    sed -i 's/^post_max_size.*/post_max_size = '${PHP_POST_MAX_SIZE}'/' $php_ini_dir
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = '${PHP_UPLOAD_MAX_FILESIZE}'/' $php_ini_dir
    sed -i 's/^expose_php.*/expose_php = Off/' $php_ini_dir
    sed -i "s/; max_input_vars = 1000/max_input_vars = $PHP_MAX_INPUT_VARS/g" $php_ini_dir
    sed -i 's/\;cgi.fix_pathinfo.*/cgi.fix_pathinfo = 0/' $php_ini_dir
    sed -i 's/^disable_functions.*/disable_functions = exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source/' $php_ini_dir

    # Generating self signed SSL certs for securing phpMyAdmin, script logins etc
    echo -e " "
    echo -e "\033[35;1m Generating self signed SSL cert and dhparam will take bit longer... \033[0m"
    mkdir /etc/nginx/ssl/

    aptitude -y install expect
    
    if [ $DHPARAM_SETUP = 2 ]; then
        openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096
    else
        cp ./config/dhparam.pem /etc/nginx/ssl/dhparam.pem
    fi

    GENERATE_CERT=$(expect -c "
        set timeout 10
        spawn openssl req -new -x509 -days 3650 -nodes -out /etc/nginx/ssl/webserver.pem -keyout /etc/nginx/ssl/webserver.key
        expect \"Country Name (2 letter code) \[AU\]:\"
        send \"\r\"
        expect \"State or Province Name (full name) \[Some-State\]:\"
        send \"\r\"
        expect \"Locality Name (eg, city) \[\]:\"
        send \"\r\"
        expect \"Organization Name (eg, company) \[Internet Widgits Pty Ltd\]:\"
        send \"\r\"
        expect \"Organizational Unit Name (eg, section) \[\]:\"
        send \"\r\"
        expect \"Common Name (eg, YOUR name) \[\]:\"
        send \"\r\"
        expect \"Email Address \[\]:\"
        send \"\r\"
        expect eof
    ")

    echo "$GENERATE_CERT"
    aptitude -y purge expect

    restart_services
    echo -e "\033[35;1m Optimize complete! \033[0m"

} # End function optimize

function install_postfix {

    # Install postfix
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
    echo "postfix postfix/mailname string $HOSTNAME_FQDN" | debconf-set-selections
    echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections
    aptitude -y install postfix

    # Allow mail delivery from localhost only
    /usr/sbin/postconf -e "inet_interfaces = loopback-only"

    sleep 1
    postfix stop
    sleep 1
    postfix start
    
    apt autoremove -y

} # End function install_postfix

function install_dbgui {

    mkdir /tmp/phpmyadmin
    PMA_VER="`wget -q -O - http://www.phpmyadmin.net/home_page/downloads.php|grep -m 1 '<h2>phpMyAdmin'|sed -r 's/^[^3-9]*([0-9.]*).*/\1/'`"
    wget -O - "https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER}/phpMyAdmin-${PMA_VER}-all-languages.tar.gz" | tar zxf - -C /tmp/phpmyadmin

    # Check exit status to see if download is successful
    if [ $? = 0  ]; then
        mkdir /usr/local/share/phpmyadmin
        rm -rf /usr/local/share/phpmyadmin/*
        cp -Rpf /tmp/phpmyadmin/*/* /usr/local/share/phpmyadmin
        cp /usr/local/share/phpmyadmin/{config.sample.inc.php,config.inc.php}
        rm -rf /tmp/phpmyadmin

        # Generate random blowfish string
        BLOWFISH=$(openssl rand -base64 40)

        # Configure phpmyadmin blowfish variable
        sed -i "s/blowfish_secret'] = ''/blowfish_secret'] = \'$BLOWFISH\'/"  /usr/local/share/phpmyadmin/config.inc.php
        echo -e "\033[35;1mphpMyAdmin installed/upgraded.\033[0m"
    else
        echo -e "\033[35;1mInstall/upgrade failed. Perhaps phpMyAdmin download link is temporarily down. Update link in options.conf and try again.\033[0m"
    fi
    
    #Fix Temp Dir for phpmyadmin
    mkdir /usr/local/share/phpmyadmin/tmp
    chmod 777 /usr/local/share/phpmyadmin/tmp
    
    apt autoremove -y
}

function restart_services {
        /etc/init.d/nginx restart
        /etc/init.d/php7.2-fpm restart
} # End function restart_services

#### Main program begins ####

# Show Menu
if [ ! -n "$1" ]; then
    echo ""
    echo -e  "\033[35;1mNOTICE: Edit options.conf before using\033[0m"
    echo -e  "\033[35;1mA standard setup would be: apt + basic + install + optimize\033[0m"
    echo ""
    echo -e  "\033[35;1mSelect from the options below to use this script:- \033[0m"

    echo -n  "$0"
    echo -ne "\033[36m basic\033[0m"
    echo     " - Disable root SSH logins, change SSH port and set hostname."

    echo -n "$0"
    echo -ne "\033[36m install\033[0m"
    echo     " - Installs LAMP stack. Also installs Postfix MTA."

    echo -n "$0"
    echo -ne "\033[36m optimize\033[0m"
    echo     " - Optimizes webserver.conf, php.ini & logrotate. Also generates self signed SSL certs."

    echo -n "$0"
    echo -ne "\033[36m dbgui\033[0m"
    echo     " - Installs or updates phpMyAdmin."

    echo -n "$0"
    echo -ne "\033[36m ftp\033[0m"
    echo     " - Installs FTP Server."

    echo ""
    exit
fi
# End Show Menu


case $1 in
basic)
    basic_server_setup
    ;;
install)
    install_extras
    install_webserver
    install_php
    install_mysql
    install_postfix
    restart_services
    echo -e "\033[35;1m Webserver + PHP-FPM + MySQL install complete! \033[0m"
    cat info_install.txt
    ;;
optimize)
    optimize_stack
    ;;
dbgui)
    install_dbgui
    ;;
ftp)
    install_ftp
    ;;
esac