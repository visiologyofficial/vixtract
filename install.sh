#!/usr/bin/env bash

source .env

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

apt update && apt install -y wget curl software-properties-common python3.6 python3-pip bzip2 ca-certificates git libgl1-mesa-glx libegl1-mesa libxrandr2 libxrandr2 libxss1 libxcursor1 libxcomposite1 libasound2 libxi6 libxtst6

### Conda
wget -nc https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ~/anaconda.sh
bash ~/anaconda.sh -b -p ${CONDA_DIR}
ln -s ${CONDA_DIR}/etc/profile.d/conda.sh /etc/profile.d/conda.sh
/opt/conda/bin/conda init bash
source ~/.bashrc
source /etc/profile.d/conda.sh

### Groups && Dirs
groupadd -f etl
mkdir /var/etl
mkdir /media/etl
chgrp -R etl /var/etl
chgrp -R etl /media/etl

### NodeJS
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
apt update && apt install -y nodejs

### JupyterHub && JupyterLab
/opt/conda/bin/conda create -y --prefix=/opt/jupyterhub/ wheel jupyterhub jupyterlab ipywidgets sqlalchemy psycopg2
mkdir -p /opt/jupyterhub/etc/jupyterhub/
cp jupyterhub/jupyterhub_config.py /opt/jupyterhub/etc/jupyterhub/
cp systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
systemctl daemon-reload
systemctl enable jupyterhub.service
systemctl start jupyterhub.service

### Papermill
pip3 install papermill

### Conda ENV Dev
/opt/conda/bin/conda create -y --prefix=/opt/conda/envs/dev python=3.6 petl ipykernel wheel requests pandas sqlalchemy psycopg2 openpyxl
${CONDA_DIR}/envs/dev/bin/python -m ipykernel install --prefix=/usr/local --name 'dev' --display-name "Python (Dev Env)"

### Conda ENV Prod
/opt/conda/bin/conda create -y --prefix=/opt/conda/envs/prod python=3.6 petl ipykernel wheel requests pandas sqlalchemy psycopg2 openpyxl
${CONDA_DIR}/envs/prod/bin/python -m ipykernel install --prefix=/usr/local --name 'prod' --display-name "Python (Prod Env)"

### Cronicle
curl -s https://raw.githubusercontent.com/jhuckaby/Cronicle/master/bin/install.js | node
/opt/cronicle/bin/control.sh setup
cp systemd/cronicle.service /etc/systemd/system/cronicle.service
systemctl daemon-reload
systemctl enable cronicle.service
systemctl start cronicle.service
cp cronicle_useradd.js /opt/cronicle/bin/

### Nginx && CertBot
add-apt-repository -y universe && add-apt-repository -y ppa:certbot/certbot
apt update && apt install -y nginx certbot python3-certbot-nginx

rm /etc/nginx/sites-enabled/default
cp nginx/default.conf /etc/nginx/conf.d/default.conf
service nginx restart

### S3FS && Rsync
apt install -y s3fs rsync
cp s3fs.sh /etc/cron.daily/s3fs
chmod 700 /etc/cron.daily/s3fs
echo ${ACCESS_KEY_ID}:${SECRET_ACCESS_KEY} > /etc/passwd-s3fs
chmod 600 /etc/passwd-s3fs
./s3fs.sh

### PostgreSQL
apt install -y postgresql postgresql-contrib
cp postgresql/postgresql.conf /etc/postgresql/10/main/
cp postgresql/pg_hba.conf /etc/postgresql/10/main/
service postgresql restart
sudo -u postgres bash -c "psql -c \"CREATE USER ${PSQL_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';\""
sudo -u postgres bash -c "psql -c \"CREATE DATABASE ${PSQL_DB};\""
sudo -u postgres bash -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${PSQL_DB} TO ${PSQL_USER};\""

sudo -u postgres bash -c "psql -c \"CREATE USER demo WITH PASSWORD 'demo';\""
sudo -u postgres bash -c "psql -f tutorials/datasets/DEMO.SQL"
sudo -u postgres bash -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE demo TO demo;\""

echo "Configuring hostname/domain..."
bash ./conf.sh -h

if [ ${DOMAIN} != "" ];
	then
  echo "Configuring HTTPS..."
	bash ./conf.sh -ssl
fi

echo "Adding first user account..."
bash ./conf.sh -u

echo "Configuring Cronicle access..."
bash ./conf.sh -a

echo "Configuring PostgresSQL access..."
bash ./conf.sh -p

echo "Installation finished. Please restart the server, otherwise hostname change might not be in effect and Cronicle might not start properly."
