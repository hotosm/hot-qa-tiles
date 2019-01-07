sudo mkswap /dev/xvdc
sudo swapon /dev/xvdc
sudo mkdir -p hot-qa-tiles
sudo mkfs -t ext3 /dev/xvdb
sudo mount /dev/xvdb hot-qa-tiles/

sudo yum install -y lvm2 wget vim tmux htop traceroute   git gcc gcc-c++ make openssl-devel kernel-devel   mesa-libGL mesa-libGL-devel xorg-x11-server-Xorg.x86_64 libpcap

git clone https://github.com/mapbox/mason.git ~/.mason
sudo ln -s ~/.mason/mason /usr/local/bin/mason
~/.mason/mason install libosmium 2.13.1
~/.mason/mason link libosmium 2.13.1
~/.mason/mason install minjur ~/.mason/mason install minjur
~/.mason/mason install minjur a2c9dc871369432c7978718834dac487c0591bd6
~/.mason/mason link minjur a2c9dc871369432c7978718834dac487c0591bd6
~/.mason/mason install tippecanoe 1.31.0
~/.mason/mason link tippecanoe 1.31.0
echo $PATH
export PATH=$PATH:~/mason_packages/.link/bin/

sudo chmod 777 hot-qa-tiles/

cd hot-qa-tiles/
