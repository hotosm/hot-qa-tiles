#!/bin/bash

function setup() {

    if $MULTI_POLYGON; then
        EXT=".mp"
    else
        DESTINATION_PATH="s3://$DESTINATION_PATH"
    fi

    export INDEX_TYPE=dense

    mkdir -p $DATA_DIR

}

function cycleGeojson() {
    LATEST_EXISTS=$(aws s3 ls $DESTINATION_PATH/latest.planet$EXT.geojson.gz | wc -l | xargs)
    if [ $LATEST_EXISTS != 0 ]; then
        aws s3 cp --quiet $DESTINATION_PATH/latest.planet$EXT.geojson.gz $DESTINATION_PATH/previous.planet$EXT.geojson.gz
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
    fastlog info "Worker started."

    setup

    # get latest planet
    fastlog info "Retrieve the latest planet PBF..."
    LATEST=$(aws s3 cp --quiet $SOURCE_PATH/planet/latest $DATA_DIR/; cat $DATA_DIR/latest)

    aws s3 cp --quiet $SOURCE_PATH/planet/$LATEST.osm.pbf $DATA_DIR/

    # PBF -> mbtiles
    fastlog info "Generating the latest mbtiles. PBF -> GeoJSON -> mbtiles"
    MBTILES_START_TIME="$(date +%s)"

    cycleGeojson
    if $MULTI_POLYGON; then
        minjur-mp \
            -n ${INDEX_TYPE} \
            $DATA_DIR/$LATEST.osm.pbf | pee "tippecanoe -q -l osm -n osm-latest -o $DATA_DIR/$LATEST$EXT.planet.mbtiles -f -z12 -Z12 -ps -pf -pk -P -b0 -d20" "pigz | aws s3 cp - $DESTINATION_PATH/latest$EXT.planet.geojson.gz"
    else
        minjur \
            -n ${INDEX_TYPE} \
            -z 12 \
            -p \
            $DATA_DIR/$LATEST.osm.pbf | pee "tippecanoe -q -l osm -n osm-latest -o $DATA_DIR/$LATEST$EXT.planet.mbtiles -f -z12 -Z12 -ps -pf -pk -P -b0 -d20" "pigz | aws s3 cp - $DESTINATION_PATH/latest$EXT.planet.geojson.gz"
    fi

    T="$(($(date +%s)-$MBTILES_START_TIME))"
    fastlog info "converted to mbtiles-extracts in $T seconds"


    # create country extracts
    fastlog info "Creating country extracts..."
    aws s3 cp --quiet $SOURCE_PATH/countries.json $DATA_DIR/
    node ./scripts/countries.js
    rm $DATA_DIR/countries.json

    for country in $(ls ${DATA_DIR}/*.geojson); do
        mbtiles-extracts "$DATA_DIR/$LATEST$EXT.planet.mbtiles" "$country" ADMIN
    done

    # compress country extracts
    pigz $DATA_DIR/$LATEST$EXT.planet/*

    #cycle old country tiles
    cycleCountryTiles

    #upload latest country tiles
    aws s3 cp --quiet --acl public-read $DATA_DIR/$LATEST$EXT.planet $DESTINATION_PATH/latest.country --recursive

    rm -rf $DATA_DIR/$LATEST$EXT.planet

    #compress planet tiles
    COMPRESS_START="$(date +%s)"
    pigz $DATA_DIR/$LATEST$EXT.planet.mbtiles
    T="$(($(date +%s)-COMPRESS_START))"
    fastlog info "compressed in $T seconds"

    # cycle old planet tiles
    cycleTiles

    # upload new planet tiles to s3
    aws s3 cp --quiet --acl public-read $DATA_DIR/$LATEST$EXT.planet.mbtiles.gz $DESTINATION_PATH/latest$EXT.planet.mbtiles.gz

    rm $DATA_DIR/$LATEST$EXT.planet.mbtiles.gz

    # put the state to s3
    aws s3 cp --quiet --acl public-read $DATA_DIR/latest $DESTINATION_PATH/

    T="$(($(date +%s)-$WORKER_START))"
    fastlog info "worker finished in $T seconds"

    # shutdown machine after updating CloudWatch metrics
    fastlog info "Success. Update CloudWatch metric"
    node ./scripts/updateCloudwatch.js
    fastlog info "Success. Shutting down..."
}

# Call run() when the script is being called, but not sourced.
[ -z "$BASH_SOURCE" ] || [ "$0" = "$BASH_SOURCE" ] && run "$@"
