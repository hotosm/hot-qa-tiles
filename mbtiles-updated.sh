#!/bin/bash
# Copyright (C) 2021 Humanitarian OpenStreetmap Team

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Humanitarian OpenStreetmap Team
# 1100 13th Street NW Suite 800 Washington, D.C. 20005
# <info@hotosm.org>

DATA_DIR=data
if [ "$1" != "" ]; then
    DESTINATION_PATH=$1
else
    DESTINATION_PATH=s3://hot-qa-tiles
fi
SOURCE_PATH=s3://hot-qa-tiles
LATEST_PLANET_SRC=https://ftp.osuosl.org/pub/openstreetmap/pbf/planet-latest.osm.pbf
LATEST=planet-latest

function setup() {

    export INDEX_TYPE=dense

    echo "Retrieve the latest planet PBF..."
    mkdir -p $DATA_DIR && cd $DATA_DIR
    wget $LATEST_PLANET_SRC
    cd ..

}

function cycleGeojson() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest.planet$EXT.geojson.gz | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        echo $DESTINATION_PATH
        aws s3 cp --no-progress $DESTINATION_PATH/latest.planet$EXT.geojson.gz $DESTINATION_PATH/previous.planet$EXT.geojson.gz
    fi

}

function cycleCountryTiles() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest.country/ | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        echo "Cycling previous latest.country/ country tiles"
        aws s3 cp --no-progress --acl public-read $DESTINATION_PATH/latest.country $DESTINATION_PATH/previous.country --recursive
    fi
}

function cycleTiles() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest$EXT.planet.mbtiles.gz | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        echo "Cycling previous latest$EXT.planet.mbtiles.gz"
        aws s3 cp --no-progress --acl public-read $DESTINATION_PATH/latest$EXT.planet.mbtiles.gz $DESTINATION_PATH/previous$EXT.planet.mbtiles.gz
        aws s3 cp --no-progress --acl public-read $DESTINATION_PATH/latest$EXT.planet.mbtiles $DESTINATION_PATH/previous$EXT.planet.mbtiles
        # aws s3 cp --no-progress --acl public-read $DESTINATION_PATH/latest $DESTINATION_PATH/previous
        echo "Done cycling"
    fi
}

#Actual script begins here:
function run() {
    set -e
    WORKER_START="$(date +%s)"
    echo "Worker started."

    setup

    # get latest planet
    # LATEST=$(aws s3 cp --quiet $SOURCE_PATH/planet/latest $DATA_DIR/; cat $DATA_DIR/latest)
    # aws s3 cp $SOURCE_PATH/planet/latest/$LATEST.osm.pbf $DATA_DIR/

    # PBF -> mbtiles
    echo "Generating the latest mbtiles. PBF -> GeoJSON -> mbtiles"
    MBTILES_START_TIME="$(date +%s)"

    # cycleGeojson
    echo "building geojson with multipolygons"
    osmium export \
        -c osm-qa-tile.osmiumconfig --overwrite \
        -f geojsonseq --verbose --progress \
        $DATA_DIR/$LATEST.osm.pbf | pee "node --max-old-space-size=32000 filter-serial.js" | pee "tippecanoe -q -l osm -n osm-latest -o $DATA_DIR/$LATEST$EXT.planet.mbtiles -Pf -Z12 -z12 -d20 -b0 -pf -pk -ps --no-tile-stats"

    T="$(($(date +%s)-$MBTILES_START_TIME))"
    echo "converted to mbtiles-extracts in $T seconds"

    # create country extracts
    echo "Creating country extracts..."
    aws s3 cp $SOURCE_PATH/countries.json $DATA_DIR/
    mbtiles-extracts "$DATA_DIR/$LATEST$EXT.planet.mbtiles" "$DATA_DIR/countries.json"  NAME_EN
    # compress country extracts
    pigz -k $DATA_DIR/$LATEST$EXT.planet/*

    # cycle old country tiles
    cycleCountryTiles

    # upload latest country tiles
    aws s3 cp --acl public-read $DATA_DIR/$LATEST$EXT.planet $DESTINATION_PATH/latest.country --recursive

    # compress planet tiles
    COMPRESS_START="$(date +%s)"
    pigz -k $DATA_DIR/$LATEST$EXT.planet.mbtiles 
    T="$(($(date +%s)-COMPRESS_START))"
    echo "compressed in $T seconds"

    # cycle old planet tiles
    cycleTiles

    # upload new planet tiles to s3
    # TODO: Adjust our services to use uncompressed tiles only, since compression doesn't save much
    
    echo "Uploading latest planet file..."
    aws s3 cp --acl public-read --no-progress $DATA_DIR/$LATEST$EXT.planet.mbtiles.gz $DESTINATION_PATH/latest$EXT.planet.mbtiles.gz

    aws s3 cp --acl public-read --no-progress $DATA_DIR/$LATEST$EXT.planet.mbtiles $DESTINATION_PATH/latest$EXT.planet.mbtiles

    echo "done"

    # put the state to s3
    # aws s3 cp --acl public-read $DATA_DIR/latest $DESTINATION_PATH/
    T="$(($(date +%s)-$WORKER_START))"
    echo "worker finished in $T seconds"

    aws s3 cp *screenlog* $DESTINATION_PATH/
    echo "Success. Updating ASG to terminate the machine"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${HotQATilesASG} --min-size 0 --max-size 0 --desired-capacity 0 --region ${region}

    echo "Success. Shutting down..."
}

# Call run() when the script is being called, but not sourced.
[ -z "$BASH_SOURCE" ] || [ "$0" = "$BASH_SOURCE" ] && run "$@"
