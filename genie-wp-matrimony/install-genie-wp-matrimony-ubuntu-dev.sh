# author: prakashm88
# description: Script for auto installation of GenieWPMatrimony plugin
# name: install-genie-wp-matrimony-ubuntu-dev.sh

#!/bin/bash -e

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

download_files() {
	#echo "====================================================================="
	echo "Downloading necessary files"
	#echo "====================================================================="
	#download wordpress
	rm -f latest.tar.gz
	wget https://wordpress.org/latest.tar.gz
	#download plugin
	rm -f genie-wp-matrimony.zip
	#wget https://downloads.wordpress.org/plugin/genie-wp-matrimony.zip
	wget https://github.com/ITechGenie/genie-wp-matrimony/archive/oauth10a.zip -O genie-wp-matrimony.zip
	#download plugin2
	rm -f rest-api-oauth1.zip
	wget https://downloads.wordpress.org/plugin/rest-api-oauth1.zip
	echo "done"
}
echo "================================="
echo "Genie WP Matrimony Install Script"
echo "================================="
echo "Downloading necessary tools: "
echo "============================="
apt-get install apache2 php libapache2-mod-php mysql-server mysql-client php-mysql perlbrew wget tar zip unzip pv composer subversion phpunit
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
php wp-cli.phar --info
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
echo "================================="
echo "Restart Apache and MySQL services (Recommended for new installations)? (y/n)"
read -e restartserv
if [ "$restartserv" == n ] ; then
	echo "Skipping restarts"
else
	echo "Restarting Apache: "
	service apache2 restart
	echo "Restarting MySQL: "
	service mysql restart
fi
echo "================================="
echo "Enter Wordpress database Name (Default: gwpmdb): "
read -e dbname
if [[ "$dbname" == "" ]] ; then
	dbname=gwpmdb
	echo "defaulting to $dbname"
fi
echo "Enter Wordpress database User (Default: gwpmuser): "
read -e dbuser
if [[ "$dbuser" == "" ]] ; then
	dbuser=gwpmuser
	echo "defaulting to $dbuser"
fi
echo "Enter Wordpress database Password (Default: gwpmpass): "
read -s dbpass
if [[ "$dbpass" == "" ]] ; then
	dbpass=gwpmpass
	echo "defaulting to $dbpass"
fi
echo "Create/Recreate above Database/User? (y/n)"
read -e needcreate
if [ "$needcreate" == n ] ; then
	echo "Skipping Database/User creation"
else
	#echo "====================================================================="
	echo "================================="
	echo "Creating MySQL Databases and User, enter Root password when promoted"
	#echo "====================================================================="
	mysql -u root -p -e "DROP DATABASE IF EXISTS $dbname; create database $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@localhost IDENTIFIED BY '$dbpass'"
	mysql -u root -p -e "DROP DATABASE IF EXISTS $dbname_tests; create database $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@localhost IDENTIFIED BY '$dbpass'"
	echo "done"
fi
echo "Download Wordpress and GenieWPMatrimony plugins (place latest.tar.gz and genie-wp-matrimony.zip for offline installation) ?  (y/n)"
read -e needdownload
if [ "$needdownload" == n ] ; then
	if [ -e latest.tar.gz ]
	then
		echo "Found latest.tar.gz"
		if [ -e genie-wp-matrimony.zip ]
		then
			echo "Found genie-wp-matrimony.zip"
			if [ -e rest-api-oauth1.zip ]
			then
				echo "Found rest-api-oauth1.zip"
			else
				echo "File not found, downloading " ;
				download_files
			fi
		else
			echo "File not found, downloading " ;
			download_files
		fi
	else
		echo "File not found, downloading " ;
		download_files
	fi 
else
	download_files
fi
echo "================================="
echo "Start installation? (y/n)"
read -e run
if [ "$run" == n ] ; then
	exit
else
	#echo "====================================================================="
	echo "================================="
	echo "Installing Wordpress"
	#echo "====================================================================="
	#unzip wordpress
	pv latest.tar.gz | tar xzf - -C .
	#change dir to wordpress
	cd wordpress
	#copy file to parent dir
	#cp -rf . ..
	#move back to parent dir
	#cd ..
	#remove files from wordpress folder
	#rm -R wordpress
	echo "================================="
	echo "Creating WP config"
	cp wp-config-sample.php wp-config.php
	#set database details with perl find and replace
	perl -pi -e "s/database_name_here/$dbname/g" wp-config.php
	perl -pi -e "s/username_here/$dbuser/g" wp-config.php
	perl -pi -e "s/password_here/$dbpass/g" wp-config.php
	#set WP salts
	perl -i -pe'
	  BEGIN {
		@chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
		push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
		sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
	  }
	  s/put your unique phrase here/salt()/ge
	' wp-config.php

	#create uploads folder and set permissions
	mkdir -p wp-content/uploads
	mkdir -p wp-content/plugins
	chmod 775 wp-content/uploads
	chmod 775 wp-content/plugins
	#echo "====================================================================="
	echo "Installing Genie WP Matrimony"
	#echo "====================================================================="
	#installing plugin
	unzip -oq ../genie-wp-matrimony.zip -d ./wp-content/plugins
	echo "================================="
	echo "Enable debug mode? (y/n)"
	read -e endebug
	if [ "$endebug" == n ] ; then
		echo "Skipping debug mode"
	else
		#echo "====================================================================="
		#echo "Enabling debug mode"
		#echo "====================================================================="
		cd wp-content/plugins/genie-wp-matrimony/config
		perl -pi -e "s/'DEVELOPMENT_ENVIRONMENT', false/'DEVELOPMENT_ENVIRONMENT', true/g" gwpm_config.php
		perl -pi -e "s/'GWPM_ENABLE_DEBUGGING', false/'GWPM_ENABLE_DEBUGGING', true/g" gwpm_config.php
		cd ../../../..
		echo "done"
	fi
	#echo "Cleaning..."
	#remove zip file
	#rm -f genie-wp-matrimony.zip
	echo "================================="
	echo "Enter location of Apache root (Default: /var/www/html): "
	read -e apachedef
	if [[ "$apachedef" == "" ]] ; then
		apachedef=/var/www/html
		echo "defaulting to $apachedef"
	fi
	echo "Copying contents to $apachedef"
	rsync -a --info=progress2 . $apachedef
	cd ..
	echo "================================="
	echo "Cleaning folder !"
	rm -rf wordpress
	#echo "====================================================================="
	echo "Installation is complete"
	echo "================================="
	#echo "====================================================================="
fi