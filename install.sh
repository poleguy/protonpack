#!/usr/bin/env bash

# run this with curl:
# wget -q -O - https://raw.githubusercontent.com/poleguy/protonpack/master/install.sh | bash

sudo apt update
sudo apt install -y git
sudo apt install -y virtualenvwrapper
sudo apt install -y plocate
sudo apt install software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt install -y python3.11
sudo apt install -y plocate

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
