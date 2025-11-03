#!/bin/sh

#mysql database user account creation
if [ ! -e "/nvram/mysql_db_account_exists" ]; then
mysql -e "CREATE USER 'bpi'@'localhost' IDENTIFIED BY 'root';"
mysql -e "ALTER USER 'bpi'@'localhost' IDENTIFIED BY 'root';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'bpi'@'localhost' IDENTIFIED BY 'root';"
mysql -e "FLUSH PRIVILEGES;"
#password is not sensitive,used to create db in mariadb
mysql -u bpi --password="root" -e "create database OneWifiMesh;"
sleep 30
touch /nvram/mysql_db_account_exists
fi
