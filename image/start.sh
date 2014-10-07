#!/bin/bash

startDb(){
  #mysql has to be started this way as it doesn't work to call from /etc/init.d
  /usr/bin/mysqld_safe &
  sleep 10s
}

stopDb(){
  killall mysqld
}

downLoadAndInstallWP(){
  curl -L -o /usr/share/nginx/latest.tar.gz http://wordpress.org/latest.tar.gz
  cd /usr/share/nginx/ && tar xvf latest.tar.gz && rm latest.tar.gz
  mv /usr/share/nginx/html/5* /usr/share/nginx/wordpress
  rm -rf /www
  mv /usr/share/nginx/wordpress /www
  chown -R www-data:www-data /www
}

restoreFiles(){
  echo Restore content from /restore/www
  cp -r /restore/www /
  sed -i.bak "s/'DB_NAME', '.*'/'DB_NAME', 'wordpress'/
  s/'DB_USER', '.*'/'DB_USER', 'wordpress'/" /www/wp-config.php
  mv /usr/share/nginx/html/5* /www
  chown -R www-data:www-data /www
  echo End of copy
}

createDatabase(){
  # Here we generate random passwords (thank you pwgen!). The first two are for mysql users, the last batch for random keys in wp-config.php
  WORDPRESS_DB="wordpress"
  MYSQL_PASSWORD=`pwgen -c -n -1 12`
  WORDPRESS_PASSWORD=`pwgen -c -n -1 12`
  #This is so the passwords show up in logs.
  echo mysql root password: $MYSQL_PASSWORD
  echo wordpress password: $WORDPRESS_PASSWORD
  echo $MYSQL_PASSWORD > /mysql-root-pw.txt
  echo $WORDPRESS_PASSWORD > /wordpress-db-pw.txt

  sed -e "s/database_name_here/$WORDPRESS_DB/
  s/username_here/$WORDPRESS_DB/
  s/password_here/$WORDPRESS_PASSWORD/
  /'AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'SECURE_AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'LOGGED_IN_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'NONCE_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'SECURE_AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'LOGGED_IN_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'NONCE_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/" /www/wp-config-sample.php > /www/wp-config.php

  mysqladmin -u root password $MYSQL_PASSWORD
  mysql -uroot -p$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE wordpress; GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY '$WORDPRESS_PASSWORD'; FLUSH PRIVILEGES;"
}

restoreDatabase(){
  echo Restauration de la base depuis /restore/wordpress.dmp
  MYSQL_PASSWORD=`grep DB_PASSWORD /www/wp-config.php | awk -F\' '{print $4}'`
  echo mysql root password: $MYSQL_PASSWORD
  mysqladmin -u root password $MYSQL_PASSWORD
  mysql -uroot -p$MYSQL_PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE wordpress; GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD'; FLUSH PRIVILEGES;"
  mysql -uroot -p$MYSQL_PASSWORD wordpress < /restore/wordpress.dmp
}

installNginxHelperPlugin(){
  # Download nginx helper plugin
  curl -O `curl -i -s http://wordpress.org/plugins/nginx-helper/ | egrep -o "http://downloads.wordpress.org/plugin/[^']+"`
  unzip -o nginx-helper.*.zip -d /www/wp-content/plugins
  chown -R www-data:www-data /www/wp-content/plugins/nginx-helper

  # Activate nginx plugin and set up pretty permalink structure once logged in
  cat << ENDL >> /www/wp-config.php
\$plugins = get_option( 'active_plugins' );
if ( count( \$plugins ) === 0 ) {
  require_once(ABSPATH .'/wp-admin/includes/plugin.php');
  \$wp_rewrite->set_permalink_structure( '/%postname%/' );
  \$pluginsToActivate = array( 'nginx-helper/nginx-helper.php' );
  foreach ( \$pluginsToActivate as \$plugin ) {
    if ( !in_array( \$plugin, \$plugins ) ) {
      activate_plugin( '/www/wp-content/plugins/' . \$plugin );
    }
  }
}
ENDL
}

startDb

if [ -e /restore/www/wp-config.php ]; then
  restoreFiles
  restoreDatabase
else
  downLoadAndInstallWP
  createDatabase
fi

chown www-data:www-data /www/wp-config.php

stopDb

#when receiving sigterm backup www and database
trap "source /backup.sh" SIGTERM


# start all services
/usr/local/bin/supervisord -n &

# Load the crontab
# one backup at a random minute each hour
sed -i.bak "s/MIN/`echo $[  $[ RANDOM % 59 ]]`/" /crontab.root
sleep 10; crontab /crontab.root
echo cron reloaded

wait

