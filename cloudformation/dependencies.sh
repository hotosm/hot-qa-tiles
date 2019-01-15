#!/bin/bash
sudo yum install -y lvm2 wget vim tmux htop traceroute git gcc gcc-c++ make openssl-devel kernel-devel mesa-libGL mesa-libGL-devel xorg-x11-server-Xorg.x86_64 libpcap pigz
sudo yum --enablerepo epel install -y moreutils
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
nvm install v9
npm install mbtiles-extracts -g --unsafe
git clone https://github.com/mapbox/mason.git ~/.mason
sudo ln -s ~/.mason/mason /usr/local/bin/mason
~/.mason/mason install libosmium 2.13.1
~/.mason/mason link libosmium 2.13.1
~/.mason/mason install minjur a2c9dc871369432c7978718834dac487c0591bd6
~/.mason/mason link minjur a2c9dc871369432c7978718834dac487c0591bd6
~/.mason/mason install tippecanoe 1.31.0
~/.mason/mason link tippecanoe 1.31.0
echo $PATH
export PATH="${PATH}:/hot-qa-tiles-generator/mason_packages/.link/bin/"
echo $PATH
