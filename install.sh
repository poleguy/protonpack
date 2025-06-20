#!/usr/bin/env bash

# run this with curl:
# curl -sSL https://raw.githubusercontent.com/poleguy/protonpack/master/install.sh | bash

sudo apt update
sudo apt install -y git
sudo apt install -y virtualenvwrapper

echo 'export WORKON_HOME=~/.virtualenvs' >> ~/.bashrc
echo 'source /usr/share/virtualenvwrapper/virtualenvwrapper.sh' >> ~/.bashrc

git clone https://github.com/poleguy/protonpack.git

cd protonpack



# install vivado

# install cvc64

# install virtualenv stuff we might need

# install python if needed

# apt updates if needed

# run

./run_sim
