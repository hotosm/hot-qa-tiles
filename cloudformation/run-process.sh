#!/bin/bash
screen -dLmS "tippecanoe" bash -c "sudo chmod 777 mbtiles-updated.sh;HotQATilesASG=${STACK_NAME} region=${REGION} ./mbtiles-updated.sh"