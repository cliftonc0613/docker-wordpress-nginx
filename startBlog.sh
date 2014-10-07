#!/bin/bash


#If www/www-config.php is present, there must be a dump : wordpress.dmp
checkRepo(){
    echo Checking repo $1
    echo `ls $1`
    if [ -e $1/www/wp-config.php ] && [ ! -e $1/wordpress.dmp ]; then
       echo www/wp-config.php is present but there is no database dump :: wordpress.dmp
       exit 1
    fi

    if [ ! -e $1/www/wp-config.php ] && [ -e $1/wordpress.dmp ]; then
       echo there a database dump but no config file :: www/wp-config.php
       exit 1
    fi

}


updateRestoreIfBackupsYounger(){
    if [ -e restore/wordpress.dmp ] &&  [ -e backups/wordpress.dmp ] && [ backups/wordpress.dmp -nt restore/wordpress.dmp ]; then
        rm -rf restore/previous
        mkdir restore/previous
        mv restore/www restore/previous
        mv restore/wordpress.dmp restore/previous
        cp -r backups/www restore
        cp backups/wordpress.dmp restore
    fi
}

FROM=`pwd`
cd $1

checkRepo restore
docker stop $1
docker rm $1
checkRepo backups
updateRestoreIfBackupsYounger

DOCKER_CONTAINER=$(docker run -d \
        --name=$1 \
        -P \
	-v /etc/localtime:/etc/localtime:ro \
        -v $FROM/$1/restore:/restore \
        -v $FROM/$1/backups:/backups \
        gzoritchak/wp-nginx)

PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' $DOCKER_CONTAINER)
echo Port http :: $PORT
sed -e "s/servername/$1/
s/port/$PORT/" nginx.conf > $1

sudo ln -fs `pwd`/$1 /etc/nginx/sites-enabled/$1
sudo service nginx reload
cd $FROM
