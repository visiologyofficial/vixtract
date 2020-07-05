#!/usr/bin/env bash

### Source file
source .env

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

### Groups && Dirs
sudo groupadd -f etl
sudo mkdir /var/etl
sudo mkdir /media/etl
sudo chgrp -R etl /var/etl
sudo chgrp -R etl /media/etl

### NodeJS
sudo curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
sudo apt update && sudo apt install -y nodejs

### JupyterHub && JuperLab
sudo /opt/conda/bin/conda create -y --prefix=/opt/jupyterhub/ wheel jupyterhub jupyterlab ipywidgets sqlalchemy psycopg2
sudo mkdir -p /opt/jupyterhub/etc/jupyterhub/
sudo cp jupyterhub/jupyterhub_config.py /opt/jupyterhub/etc/jupyterhub/
sudo cp systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
sudo systemctl daemon-reload
sudo systemctl enable jupyterhub.service
sudo systemctl start jupyterhub.service

### Papermill
sudo pip3 install papermill

### Conda ENV Dev
sudo /opt/conda/bin/conda create -y --prefix=/opt/conda/envs/dev python=3.6 petl ipykernel wheel requests pandas sqlalchemy psycopg2 openpyxl
sudo ${CONDA_DIR}/envs/dev/bin/python -m ipykernel install --prefix=/usr/local --name 'dev' --display-name "Python (Dev Env)"

### Conda ENV Prod
sudo /opt/conda/bin/conda create -y --prefix=/opt/conda/envs/prod python=3.6 petl ipykernel wheel requests pandas sqlalchemy psycopg2 openpyxl
sudo ${CONDA_DIR}/envs/prod/bin/python -m ipykernel install --prefix=/usr/local --name 'prod' --display-name "Python (Prod Env)"

### Cronicle
sudo curl -s https://raw.githubusercontent.com/jhuckaby/Cronicle/master/bin/install.js | node
sudo /opt/cronicle/bin/control.sh setup
sudo cp systemd/cronicle.service /etc/systemd/system/cronicle.service
sudo systemctl daemon-reload
sudo systemctl enable cronicle.service
sudo systemctl start cronicle.service

### Nginx && CertBot
sudo add-apt-repository -y universe && sudo add-apt-repository -y ppa:certbot/certbot
sudo apt update && sudo apt install -y nginx certbot python3-certbot-nginx

sudo rm /etc/nginx/sites-enabled/default
sudo cp nginx/default.conf /etc/nginx/conf.d/default.conf
sudo service nginx restart

### SSL
if [ ${DOMAIN} != "" ];
	then
	certbot --nginx -w /var/www/html \
		--no-eff-email \
		--redirect \
		--email ${EMAIL} \
		-d ${DOMAIN} \
		--agree-tos \
		--force-renewal
fi

### S3FS && Rsync
sudo apt install -y s3fs rsync
sudo cp s3fs.sh /etc/cron.daily/s3fs
sudo chmod 700 /etc/cron.daily/s3fs
sudo echo ${ACCESS_KEY_ID}:${SECRET_ACCESS_KEY} > /etc/passwd-s3fs
sudo chmod 600 /etc/passwd-s3fs
sudo ./s3fs.sh

### PostgreSQL
sudo apt install -y postgresql postgresql-contrib
sudo cp postgresql/postgresql.conf /etc/postgresql/10/main/
sudo cp postgresql/pg_hba.conf /etc/postgresql/10/main/
sudo service postgresql restart
sudo -u postgres bash -c "psql -c \"CREATE USER ${PSQL_USER} WITH PASSWORD '${PSQL_PASS}';\""
sudo -u postgres bash -c "psql -c \"CREATE DATABASE ${PSQL_DB};\""
sudo -u postgres bash -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${PSQL_DB} TO ${PSQL_USER};\""