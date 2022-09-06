#!/bin/bash
#DATE-TIME=date +%F_%R

OF=/home/recompiler/backups/vflared/backup-$(%Y%m%d_%F_%R)
DOCKER=/home/recompiler/docker
HTTPD=/home/recompiler/docker/httpd
HOME1=/home/recompiler/scripts

echo "ENTERING DOCKER DIR"
cd $DOCKER

echo "SHUTTTING DOWN DOCKER"
docker-compose down

echo "MAKING BACKUP DIR"
mkdir -p $OF

echo "BACKING UP"
cp -R $HTTPD $OF/

echo "STARING DOCKER"
docker-compose up -d

echo "RETURNING HOME"
cd $HOME1

echo "SETTING OWNERSHIP FOR BACKUP DIR"
chown recompiler:recompiler -R $OF

echo "DONE!"
