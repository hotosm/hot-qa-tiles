#!/bin/bash
screen -dLmS "tippecanoe" bash -c "sudo chmod 775 ./hot-qa-tiles/mbtiles-updated.sh;HotQATilesASG=${STACK_NAME} region=${REGION} ./hot-qa-tiles/mbtiles-updated.sh"