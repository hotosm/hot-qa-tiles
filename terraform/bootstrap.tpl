#!/bin/bash
## Copyright (C) 2021 Humanitarian OpenStreetmap Team
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.
##
## Humanitarian OpenStreetmap Team
## 1100 13th Street NW Suite 800 Washington, D.C. 20005
## <info@hotosm.org>

while [ ! -e /dev/nvme1n1 ]; do echo waiting for /dev/nvme1n1 to attach; sleep 10; done
while [ ! -e /dev/nvme2n1 ]; do echo waiting for /dev/nvme2n1 to attach; sleep 10; done
mkdir -p hot-qa-tiles-generator
mkfs -t ext3 /dev/nvme1n1
mount /dev/nvme1n1 hot-qa-tiles-generator/
mkfs -t ext4 /dev/nvme2n1
mount /dev/nvme2n1 /tmp
yum install -y lvm2 wget vim tmux htop traceroute git gcc gcc-c++ make openssl-devel kernel-devel, mesa-libGL mesa-libGL-devel xorg-x11-server-Xorg.x86_64 libpcap pigz
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum-config-manager --enable epel
yum install -y moreutils
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
nvm install v12
npm install mbtiles-extracts -g --unsafe
npm install json-stream-reduce
npm install @turf/area
git clone --depth=1 https://github.com/mapbox/mason.git ~/.mason
sudo ln -s ~/.mason/mason /usr/local/bin/mason
~/.mason/mason install osmium-tool 1.11.0
~/.mason/mason link  osmium-tool 1.11.0
~/.mason/mason install tippecanoe 1.32.10
~/.mason/mason link tippecanoe 1.32.10
echo $PATH
export PATH=$PATH:/mason_packages/.link/bin/
export LC_ALL=en_US.UTF-8
sudo chmod 777 /hot-qa-tiles-generator/
cd /hot-qa-tiles-generator/

git clone https://${oauth_token}@github.com/hotosm/hot-qa-tiles.git && cd hot-qa-tiles && git checkout ${git_commit_sha}
screen -dLmS "tippecanoe" bash -c "sudo chmod 777 mbtiles-updated.sh;HotQATilesASG=${asg_name} region=${aws_region} ./mbtiles-updated.sh ${s3_destination_path}"
