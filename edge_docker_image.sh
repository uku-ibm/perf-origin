#!/bin/bash
echo " Check the docker version "
docker --version
docker pull iregistry.eur.ad.sag/aim/msr-edge-runtime:int
IMAGE=iregistry.eur.ad.sag/aim/msr-edge-runtime:int
date=`date +"%d-%m-%Y"`
docker save -o msr-edge-runtime-$date.tar $IMAGE
echo "Saved $IMAGE to $1/msr-edge-runtime-$date.tar"