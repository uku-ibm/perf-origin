#!/bin/bash
pull_edge_runtime_image(){
    docker pull iregistry.eur.ad.sag/aim/msr-edge-runtime:int
    IMAGE=iregistry.eur.ad.sag/aim/msr-edge-runtime:int
    date=`date +"%d-%m-%Y"`
    docker save -o $1/msr-edge-runtime-$date.tar $IMAGE
    echo "Saved $IMAGE to $1/msr-edge-runtime-$date.tar"
}

load_edge_runtime_image(){
    docker load -i $1/msr-edge-runtime-$date.tar
    docker image tag 5f3c58976aec iregistry.eur.ad.sag/aim/msr-edge-runtime:int

}

echo " Check the docker version "
docker --version
if [[ $1 == *"pull_edge_runtime_image"* ]]; then
        pull_edge_runtime_image
fi
if [[ $1 == *"load_edge_runtime_image"* ]]; then
        load_edge_runtime_image
fi

