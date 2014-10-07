#!/bin/bash

backupFiles(){
    echo Backup files www dans /backups/www
    rm -rf /backups/www
    cp -R /www /backups
}

backupDb(){
  echo Backup base dans /backups/wordpress.dmp
  MYSQL_PASSWORD=`grep DB_PASSWORD /www/wp-config.php | awk -F\' '{print $4}'`
  mysqldump --add-drop-table -uwordpress -p$MYSQL_PASSWORD wordpress > /backups/wordpress.dmp
}

backupFiles
backupDb
