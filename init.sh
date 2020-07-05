#!/usr/bin/env bash

source .env

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

reinit(){
  reset
  exec sudo --login --user "$USER" /bin/sh -c "cd '$PWD'; exec '$SHELL' -l sudo bash install.sh;"
}

sudo apt update && sudo apt install -y wget curl software-properties-common python3.6 python3-pip bzip2 ca-certificates git libgl1-mesa-glx libegl1-mesa libxrandr2 libxrandr2 libxss1 libxcursor1 libxcomposite1 libasound2 libxi6 libxtst6

### Conda
sudo wget -nc https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh -O ~/anaconda.sh
sudo bash ~/anaconda.sh -b -p ${CONDA_DIR}
sudo ln -s ${CONDA_DIR}/etc/profile.d/conda.sh /etc/profile.d/conda.sh
sudo /opt/conda/bin/conda init bash
source ~/.bashrc
source /etc/profile.d/conda.sh
bash --rcfile <(echo '. ~/.bashrc; ./install.sh')