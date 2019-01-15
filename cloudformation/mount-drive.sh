#!/bin/bash
while [ ! -e /dev/xvdc ]; do echo waiting for /dev/xvdc to attach; sleep 10; done
while [ ! -e /dev/xvdb ]; do echo waiting for /dev/xvdb to attach; sleep 10; done
sudo mkdir -p hot-qa-tiles-generator
sudo mkfs -t ext3 /dev/xvdc
sudo mount /dev/xvdc hot-qa-tiles-generator/
sudo mkfs -t ext3 /dev/xvdb
sudo mount /dev/xvdb /tmp