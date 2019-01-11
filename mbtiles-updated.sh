#!/bin/bash
DATA_DIR=data
DESTINATION_PATH=s3://hot-qa-tiles
SOURCE_PATH=s3://hot-qa-tiles
LATEST=planet-latest

function setup() {

    if [ $MULTI_POLYGON ]; then
        EXT=".mp"
    fi

    export INDEX_TYPE=dense

    mkdir -p $DATA_DIR

}

function cycleGeojson() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest.planet$EXT.geojson.gz | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        echo $DESTINATION_PATH
        aws s3 cp  $DESTINATION_PATH/latest.planet$EXT.geojson.gz $DESTINATION_PATH/previous.planet$EXT.geojson.gz
    fi

}

function cycleCountryTiles() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest.country/ | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        aws s3 cp --quiet --acl public-read $DESTINATION_PATH/latest.country $DESTINATION_PATH/previous.country --recursive
    fi
}

function cycleTiles() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest.planet$EXT.mbtiles.gz | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        aws s3 cp --quiet --acl public-read $DESTINATION_PATH/latest.planet$EXT.mbtiles.gz $DESTINATION_PATH/previous.planet$EXT.mbtiles.gz
        aws s3 cp --quiet --acl public-read $DESTINATION_PATH/latest $DESTINATION_PATH/previous
    fi
}

#Actual script begins here:
function run() {
    set -e
    WORKER_START="$(date +%s)"
    echo "Worker started."

    setup

    # get latest planet
    echo "Retrieve the latest planet PBF..."
    # LATEST=$(aws s3 cp --quiet $SOURCE_PATH/planet/latest $DATA_DIR/; cat $DATA_DIR/latest)
    aws s3 cp  $SOURCE_PATH/planet/latest/$LATEST.osm.pbf $DATA_DIR/

    # PBF -> mbtiles
    echo "Generating the latest mbtiles. PBF -> GeoJSON -> mbtiles"
    MBTILES_START_TIME="$(date +%s)"

    # cycleGeojson
    if [ $MULTI_POLYGON ]; then
      echo "building geojson with multipolygons"
       minjur-mp \
           -n ${INDEX_TYPE} \
           $DATA_DIR/$LATEST.osm.pbf | pee "tippecanoe -q -l osm -n osm-latest -o $DATA_DIR/$LATEST$EXT.planet.mbtiles -f -z12 -Z12 -ps -pf -pk -P -b0 -d20"
    else
      echo "building geojson"
        minjur \
           -n ${INDEX_TYPE} \
           -z 12 \
           -p \
           $DATA_DIR/$LATEST.osm.pbf | pee "tippecanoe -q -l osm -n osm-latest -o $DATA_DIR/$LATEST$EXT.planet.mbtiles -f -z12 -Z12 -ps -pf -pk -P -b0 -d20"
    fi

    T="$(($(date +%s)-$MBTILES_START_TIME))"
    echo "converted to mbtiles-extracts in $T seconds"


    # create country extracts
    echo "Creating country extracts..."
    aws s3 cp $SOURCE_PATH/countries.json $DATA_DIR/
    mbtiles-extracts "$DATA_DIR/$LATEST$EXT.planet.mbtiles" "$DATA_DIR/countries.json"  NAME_EN
    # compress country extracts
    pigz $DATA_DIR/$LATEST$EXT.planet/*

    # cycle old country tiles
    cycleCountryTiles

    # upload latest country tiles
    aws s3 cp --acl public-read $DATA_DIR/$LATEST$EXT.planet $DESTINATION_PATH/latest.country --recursive

    # compress planet tiles
    COMPRESS_START="$(date +%s)"
    pigz $DATA_DIR/$LATEST$EXT.planet.mbtiles
    T="$(($(date +%s)-COMPRESS_START))"
    echo "compressed in $T seconds"

    # cycle old planet tiles
    cycleTiles

    # upload new planet tiles to s3
    aws s3 cp  --acl public-read $DATA_DIR/$LATEST$EXT.planet.mbtiles.gz $DESTINATION_PATH/latest$EXT.planet.mbtiles.gz

    # put the state to s3
    aws s3 cp --acl public-read $DATA_DIR/latest $DESTINATION_PATH/
    T="$(($(date +%s)-$WORKER_START))"
    echo "worker finished in $T seconds"

    echo "Success. Updating ASG to terminate the machine"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${HotQATilesASG} --min-size 0 --max-size 0 --desired-capacity 0 --region $Region

    echo "Success. Shutting down..."
}

# Call run() when the script is being called, but not sourced.
[ -z "$BASH_SOURCE" ] || [ "$0" = "$BASH_SOURCE" ] && run "$@"
