#!/usr/bin/env bash

set -e
# run this with curl:
# wget -q -O - https://raw.githubusercontent.com/poleguy/protonpack/master/install.sh | bash 

# mount vivado from host

# todo: how do we know host ip? pass in via command line?

HOST_IP=192.168.1.162

sudo mkdir /opt/Xilinx
sudo chmod ugo+wx /opt/Xilinx
sudo mkdir /data
sudo mkdir /data/Xilinx
sudo chmod ugo+wx /data/Xilinx
sudo chmod ugo+wx /data/
sshfs poleguy@$HOST_IP:/opt/Xilinx /opt/Xilinx
sshfs poleguy@$HOST_IP:/data/Xilinx /data/Xilinx

# cvc from host as well
rsync poleguy@$HOST_IP:/usr/local/bin/cvc64 cvc64
sudo cp cvc64 /usr/local/bin/

sudo apt update
sudo apt install -y git
sudo apt install -y virtualenvwrapper
sudo apt install -y plocate
sudo apt install software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt install -y python3.11
sudo apt install -y python3.11-dev


# https://askubuntu.com/questions/251378/where-is-virtualenvwrapper-sh
echo 'export WORKON_HOME=~/.virtualenvs' >> ~/.bashrc
echo 'source /usr/share/virtualenvwrapper/virtualenvwrapper.sh' >> ~/.bashrc
source ~/.bashrc

git clone https://github.com/poleguy/protonpack.git

cd protonpack



# install vivado

# install cvc64

# install virtualenv stuff we might need

# install python if needed

# apt updates if needed

# run

./run_sim
